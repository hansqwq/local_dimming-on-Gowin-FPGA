# 基于高云FPGA的分区背光控制系统 (Zonal Backlight Control System on Gowin FPGA)

## 项目简介 (Project Overview)

本项目是一个基于高云FPGA（Gowin FPGA）开发的Mini-LED显示分区背光控制系统。  其主要目标是通过精细化控制显示屏背光的多个分区亮度，根据实时图像内容动态调整，以显著提升显示设备的对比度、降低功耗，并改善整体视觉体验。 

系统接收外部LVDS视频信号，一方面将视频信号直接输出到显示屏；另一方面，对视频信号进行实时分析，计算出各个Mini-LED背光分区的最佳亮度值，并通过SPI接口驱动背光灯板，实现分区背光控制。 

## 主要技术特点 (Key Features)

* **分区背光控制 (Zonal Backlight Control)**: 将Mini-LED背光板划分为360个独立控制的背光分区，根据图像内容动态调整各区域亮度。 
* **FPGA实时处理 (FPGA Real-time Processing)**: 利用高云FPGA的并行处理能力实现实时的图像分析和动态调光算法。 
* **高清LVDS接口 (HD LVDS Interface)**: 支持1280x800分辨率的高清LVDS信号输入与输出。 
* **Mini-LED驱动 (Mini-LED Driving)**: 通过SPI接口控制LED驱动芯片（如SPI7001），实现对360颗LED灯珠的精确亮度调节。
* **灵活可配置 (Flexible Configuration)**: 系统设计支持通过Verilog `define`进行参数配置，以适应不同的LVDS标准和显示需求。

## 硬件与软件环境 (Hardware & Software Environment)

* **FPGA**: 高云半导体FPGA 
* **语言 (Language)**: Verilog HDL
* **显示 (Display)**: Mini-LED背光液晶显示屏 (1280x800分辨率, 360个背光分区)

## 模块概览 (Modules Overview)

本项目主要由以下Verilog模块组成：

* `local_dimming_top.v`: 顶层模块，集成系统所有子模块，处理LVDS输入/输出，并连接背光控制逻辑与LED驱动接口。
* `lvds_7to1_rx_top.v`: LVDS 7:1接收器顶层模块。负责接收外部输入的LVDS差分信号，通过内嵌的`bit_align_ctl.v`和`word_align_ctl.v`进行位同步和字同步，并利用`LVDS71RX_1CLK8DATA`原语（推测）进行解串，最终输出并行的RGB视频数据及同步信号。
    * `bit_align_ctl.v`: LVDS位对齐控制模块，用于动态调整采样时钟相位以正确接收串行数据。
    * `word_align_ctl.v`: LVDS字对齐控制模块，确保正确地将串行比特流组合成有效的数据字。
* `led_backlight.v` (实际文件名为 `led_blacklight_top.v`): 分区背光亮度计算核心模块。接收并行RGB视频数据和同步信号，将屏幕划分为24x15个区域，计算每个区域的平均灰度值作为该区域LED的亮度值，并将结果输出。
* `fifo_top.v` (代码未提供，但在 `local_dimming_top.v` 中实例化): FIFO缓冲模块，用于在`led_backlight.v`计算得到的亮度数据和后续的SRAM写入/LED驱动模块之间进行数据缓冲和时钟域转换。
* `ramflag_1.v`: SRAM及LED驱动控制时序模块。从FIFO读取亮度数据，并产生相应的地址 (`wtaddr`)、数据 (`wtdina`) 和控制信号 (`sdbpflag`)，用于将亮度数据写入SRAM或直接供给LED驱动芯片的时序控制。包含多种测试模式（如流水灯、全亮等）的逻辑。
* `sram_top_gowin_top.v` (代码未提供，但在 `local_dimming_top.v` 中实例化): SRAM顶层控制模块，用于存储各个分区的亮度数据。
* `SPI7001_gowin_top.v` (代码未提供，但在 `local_dimming_top.v` 中实例化): 针对特定LED驱动芯片（如SPI7001）的SPI接口驱动模块，将SRAM中存储的亮度数据通过SPI协议发送给LED背光板。
* `lvds_7to1_tx_top.v`: LVDS 7:1发送器顶层模块。接收并行的RGB视频数据及同步信号，根据配置（VESA/JEIDA标准）进行数据映射，并通过内嵌的`ip_gddr71tx.v`核心模块进行串行化，最终输出LVDS差分信号至显示面板。
    * `ip_gddr71tx.v`: LVDS 7:1发送器核心原语封装。主要实例化FPGA厂商提供的`OVIDEO ODDR71B`等硬件原语，完成并行数据到高速串行数据的转换，并驱动LVDS输出缓冲器。
* `lvds_7to1_rx_defines.v` / `lvds_7to1_tx_defines.v` (代码未提供，但被其他模块`include`): Verilog定义文件，用于配置LVDS收发器的各种参数，如接口标准、颜色深度、通道数等。

