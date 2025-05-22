module led_backlight(
    input        I_rst_n,       
    input        I_pix_clk,     
    input        I_vs,           
    input        I_hs,          
    input        I_de,           
    input  [7:0] I_data_r,      
    input  [7:0] I_data_g,       
    input  [7:0] I_data_b,     
    output  [15:0] O_led_brightness_wire,
    output O_wren_wire
);

//reg [15:0] max_value[24*15-1:0];  
reg [27:0] temp_value[24*15-1:0]; 
reg wren;
reg [15:0] O_led_brightness;
reg [15:0] temp_div_result;


// LVDS RX 计数
reg [13:0] cnt_hs;
reg [13:0] cnt_de;
reg [13:0] cnt_vs;                                                                                                       
reg [13:0] cnt_vs_all;

wire hs_pos;
wire hs_neg;
wire de_pos;
wire de_neg;
wire vs_pos;
wire vs_neg;

reg vs_r;
reg vs_rr;
reg hs_r;
reg hs_rr;
reg de_r;
reg de_rr;

always@(posedge I_pix_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        vs_r <= 0;
        vs_rr <= 0;
        hs_r <= 0;
        hs_rr <= 0;
        de_r <= 0;
        de_rr <= 0;
    end
    else begin
        vs_r <= I_vs;
        vs_rr <= vs_r;
        hs_r <= I_hs;
        hs_rr <= hs_r;
        de_r <= I_de;
        de_rr <= de_r;
    end
end

// LVDS RX 计数
assign hs_pos = I_hs & !hs_r;
assign hs_neg = !I_hs & hs_r;
assign vs_pos = I_vs & !vs_r;
assign vs_neg = !I_vs & vs_r;
assign de_pos = I_de & !de_r;
assign de_neg = !I_de & de_r;
assign O_wren_wire = wren;
assign O_led_brightness_wire = O_led_brightness;


reg hs_flag;
always@(posedge I_pix_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        hs_flag <= 0;
    end
    else if(hs_neg) begin
        hs_flag <= 1;
    end
    else if(hs_pos) begin
        hs_flag <= 0;
    end
end

reg de_flag;
always@(posedge I_pix_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        de_flag <= 0;
    end
    else if(de_pos) begin
        de_flag <= 1;
    end
    else if(de_neg) begin
        de_flag <= 0;
    end
end

always@(posedge I_pix_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        cnt_hs <= 0;
    end
    else if(hs_pos)begin
        cnt_hs <= 0;
    end
    else if(hs_neg)begin
        cnt_hs <= 1;
    end
    else if(hs_flag)begin
        cnt_hs <= cnt_hs + 1;
    end
end

always@(posedge I_pix_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        cnt_de <= 0;
    end
    else if(de_pos) begin
        cnt_de <= 1;
    end
    else if(de_neg) begin
        cnt_de <= 0;
    end
    else if(de_flag) begin
        cnt_de <= cnt_de + 1;
    end
end

always@(posedge I_pix_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        cnt_vs <= 1;
    end
    else if(vs_pos || vs_neg) begin
        cnt_vs <= 0;
    end
    else if(de_pos) begin
        cnt_vs <= cnt_vs + 1;
    end
end

always@(posedge I_pix_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        cnt_vs_all <= 1;
    end
    else if(vs_pos || vs_neg) begin
        cnt_vs_all <= 0;
    end
    else if(hs_pos) begin
        cnt_vs_all <= cnt_vs_all + 1;
    end
end

reg [8:0] i;       
reg [8:0] partition_id;  
reg [15:0] gray_value;


always @(posedge I_pix_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        partition_id <= 9'd0;
        gray_value <= 16'd0;
        for (i = 0; i < 24*15; i = i + 1) begin
            temp_value[i] <= 16'd0;
        end
    end
    else if(vs_pos) begin
        partition_id <= 9'd0;
        gray_value <= 16'd0;
        for(i = 0; i < 24*15; i = i + 1) begin
            temp_value[i] <= 16'd0;
        end
    end
    else if(de_neg) begin
        partition_id <= 9'd0;
        gray_value <= 16'd0;
    end
    else if(de_pos || de_flag) begin
        partition_id <= (cnt_vs / (800 / 15)) * 24 + (cnt_de / (1280 / 24));
        gray_value <= (I_data_r * 16'd77 + I_data_g * 16'd150 + I_data_b * 16'd29) ;
//        if (gray_value > max_value[partition_id]) begin
//            max_value[partition_id] <= gray_value;
//        end
        temp_value[partition_id]<=temp_value[partition_id]+gray_value;
    end
end


reg [8:0] tmp;
always@(posedge I_pix_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        tmp <= 0;
        wren <= 0;
    end
    else if(vs_pos) begin
        tmp <= 0;
        wren <= 0;
    end
    else if(cnt_vs_all > 829 && cnt_vs_all <= 830 && tmp < 360) begin
        temp_div_result = (temp_value[partition_id] >> 12) + (temp_value[partition_id] >> 14); 
        O_led_brightness <= temp_div_result;
        wren <= 1;
        tmp <= tmp + 1;
    end
    else if (tmp >= 360) begin
        wren <= 0;
    end
end
endmodule
