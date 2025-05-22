module local_dimming_top
(
    input          I_clk       ,  //50MHz      
    input          I_rst_n     ,
    output [3:0]   O_led       , 
    input          I_clkin_p   ,  //LVDS Input
    input          I_clkin_n   ,  //LVDS Input
    input  [3:0]   I_din_p     ,  //LVDS Input
    input  [3:0]   I_din_n     ,  //LVDS Input    
    output         O_clkout_p  ,
    output         O_clkout_n  ,
    output [3:0]   O_dout_p    ,
    output [3:0]   O_dout_n    , 
    //led
    output         LE          ,
    output         DCLK        , //12.5M
    output         SDI         ,
    output         GCLK         ,
    output         scan1       ,
    output         scan2       ,
    output         scan3       , 
    output         scan4       
);

//======================================================
reg  [31:0] run_cnt;
wire        running;

//--------------------------
wire [7:0]  r_R_0;  // Red,   8-bit data depth
wire [7:0]  r_G_0;  // Green, 8-bit data depth
wire [7:0]  r_B_0;  // Blue,  8-bit data depth
wire        r_Vsync_0;
wire        r_Hsync_0;
wire        r_DE_0   ;
wire 		rx_sclk;

//===================================================
//LED test
always @(posedge I_clk or negedge I_rst_n)//I_clk
begin
    if(!I_rst_n)
        run_cnt <= 32'd0;
    else if(run_cnt >= 32'd50_000_000)
        run_cnt <= 32'd0;
    else
        run_cnt <= run_cnt + 1'b1;
end

assign  running = (run_cnt < 32'd25_000_000) ? 1'b1 : 1'b0;

assign  O_led[0] = 1'b1;
assign  O_led[1] = 1'b1;
assign  O_led[2] = 1'b0;
assign  O_led[3] = running;

//==============================================================
//LVDS Reciver
LVDS_7to1_RX_Top LVDS_7to1_RX_Top_inst
(
    .I_rst_n        (I_rst_n    ),
    .I_clkin_p      (I_clkin_p  ),    // LVDS clock input pair
    .I_clkin_n      (I_clkin_n  ),    // LVDS clock input pair
    .I_din_p        (I_din_p    ),    // LVDS data input pair 0
    .I_din_n        (I_din_n    ),    // LVDS data input pair 0
    .O_pllphase     (           ),
    .O_pllphase_lock(           ),
    .O_clkpat_lock  (           ),
    .O_pix_clk      (rx_sclk    ),  
    .O_vs           (r_Vsync_0  ),
    .O_hs           (r_Hsync_0  ),
    .O_de           (r_DE_0     ),
    .O_data_r       (r_R_0      ),
    .O_data_g       (r_G_0      ),
    .O_data_b       (r_B_0      )
);



//===================================================================================
//LVDS TX
LVDS_7to1_TX_Top LVDS_7to1_TX_Top_inst
(
    .I_rst_n       (I_rst_n     ),
    .I_pix_clk     (rx_sclk     ), //x1                       
    .I_vs          (r_Vsync_0   ), 
    .I_hs          (r_Hsync_0   ),
    .I_de          (r_DE_0      ),
    .I_data_r      (r_R_0       ),
    .I_data_g      (r_G_0       ),
    .I_data_b      (r_B_0       ), 
    .O_clkout_p    (O_clkout_p  ), 
    .O_clkout_n    (O_clkout_n  ),
    .O_dout_p      (O_dout_p    ),    
    .O_dout_n      (O_dout_n    ) 
);

//===================================================================================
wire clk25M;
wire clk1M;
wire sdbpflag;
wire [9:0]wtaddr;
wire [6:0]cntlatch;
wire frame_flag;
wire latch_flag;
wire [95:0]datain;
wire [15:0]wtdina;
wire [15:0]wr_led_brightness;
wire wren;
wire rden;
wire [15:0] rd_led_brightness;
wire Empty;
wire Full;
wire Almost_Empty;
wire Almost_Full;
wire [9:0] Wnum;
wire [9:0] Rnum;
wire fifo_rst;


led_backlight led_backlight_inst
(
    .I_rst_n           (I_rst_n   ),
    .I_pix_clk         (rx_sclk   ),
    .I_vs              (r_Vsync_0 ),
    .I_hs              (r_Hsync_0 ),
    .I_de              (r_DE_0    ), 
    .I_data_r          (r_R_0     ),
    .I_data_g          (r_G_0     ), 
    .I_data_b          (r_B_0     ),
    .O_led_brightness_wire  (wr_led_brightness),
    .O_wren_wire              (wren)
);

fifo_top  fifo_inst 
(
    .Reset(fifo_rst),
    .WrClk(rx_sclk),
    .RdClk(clk25M),
    .WrEn(wren),
    .RdEn(rden),
    .Data(wr_led_brightness),
    .Empty(Empty),
    .Full(Full),
    .Almost_Empty(Almost_Empty),
    .Almost_Full(Almost_Full),
    .Wnum(Wnum[9:0]),
    .Rnum(Rnum[9:0]),
    .Q(rd_led_brightness)
);

//PLL分频
SPI7001_25M_1M_rPLL SPI7001_25M_1M_rPLL_inst(
         .clkout(clk25M), //output clkout
         .clkoutd(clk1M), //output clkoutd
         .clkin(I_clk) //input clkin
);


//ramflag_1是模拟分区背光算法后控制灯板点亮的模块（通过信号sdbpflag、wtaddr、wtdina传入LED驱动芯片接口模块进行后续输出）

ramflag_1 u1(
    .clk(clk25M),
    .rst_n(I_rst_n),
    .sdbpflag_wire(sdbpflag),//写入一帧起始信号
    .wtdina_wire(wtdina),//写入的灰度值
    .wtaddr_wire(wtaddr),//灯板上灯珠位置对应的地址
    .rden_wire(rden),
    .I_led_brightness(rd_led_brightness),
    .fifo_rst_wire(fifo_rst)

);
//以下代码不建议做修改
sram_top_gowin_top u2(
    .clka(clk25M),
    .clkb(clk1M),
    .sdbpflag(sdbpflag),
    .wtaddr(wtaddr),
    .wtdina(wtdina),
    .rst_n(I_rst_n),
    .latch_flag(latch_flag),
    .frame_flag(frame_flag),
    .datain(datain),
    .cntlatch(cntlatch)
);

SPI7001_gowin_top u3(
    .clock(clk25M),
    .clk_1M(clk1M),
    .rst_n(I_rst_n),
    .frame_f(frame_flag),
    .rgb_f(latch_flag),
    .rgb_data(datain),
    .cntlatch(cntlatch),
    .LE(LE),
    .DCLK(DCLK),
    .SDI(SDI),
    .GCLK(GCLK),
    .scan1(scan1),
    .scan2(scan2),
    .scan3(scan3),
    .scan4(scan4),
    .scan1_wire(scan1_wire)
);

endmodule

