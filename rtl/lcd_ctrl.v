module lcd_ctrl(
    input  wire        clk_in     ,
    input  wire        sys_rst_n  ,
    input  wire [23:0] data_in    ,

    output wire        data_req   ,
    output wire [10:0] pix_x      ,
    output wire [10:0] pix_y      ,
    output wire [23:0] rgb_lcd_24b,
    output wire        hsync      ,
    output wire        vsync      ,
    output wire        lcd_clk    ,
    output wire        lcd_de     ,
    output wire        lcd_bl
);

//parameter define
parameter H_BLANK = 46  , // Horizontal Blanking
          H_DISP  = 800 , // Horizontal display area
          H_FRONT = 210 , // Horizontal front porch
          H_PT    = 1056; // Horizontal period time

parameter V_BLANK = 23  , // Vertical Blanking
          V_DISP  = 480 , // Vertical display area
          V_FRONT = 22  , // Vertical front porch
          V_PT    = 525 ; // Vertical period time

parameter H_PIXEL = 11'd800 ,
          V_PIXEL = 11'd480 ;

//wire define
wire        data_valid ; //
wire [23:0] data_out   ; //

//reg define
reg [11:0] cnt_h ;
reg [ 9:0] cnt_v ;

//*****************************************************//
//******************** Main Code **********************//
//*****************************************************//

assign lcd_clk = clk_in ;
assign lcd_de  = data_valid;
assign lcd_bl  = 1'b0 ;

//cnt_h
always@(posedge clk_in or negedge sys_rst_n)begin
    if(sys_rst_n == 1'b0)
        cnt_h <= 'd0;
    else if(cnt_h == H_PT - 1'b1)
        cnt_h <= 'd0;
    else
        cnt_h <= cnt_h + 1'b1;
end

//cnt_v
always@(posedge clk_in or negedge sys_rst_n)begin
    if(sys_rst_n == 1'b0)
        cnt_v <= 'd0;
    else if(cnt_h == H_PT - 1'b1)begin
        if(cnt_v == V_PT - 1'b1)
            cnt_v <= 'd0;
        else
            cnt_v <= cnt_v + 1'b1;
    end
    else
        cnt_v <= cnt_v;
end

//data_valid
assign data_valid = ((cnt_h >= H_BLANK)
                  && (cnt_h < (H_BLANK + H_DISP))
                  && (cnt_v >= V_BLANK)
                  && (cnt_v < (V_BLANK + V_DISP)) );

//data_req
assign data_req = ((cnt_h >= H_BLANK - 1'b1)
                && (cnt_h < (H_BLANK + H_DISP - 1'b1))
                && (cnt_v >= V_BLANK)
                && (cnt_v < (V_BLANK + V_DISP)) );

assign pix_x = (data_req == 1'b1)
             ? (cnt_h - (H_BLANK - 1'b1)) : 11'h3ff;
assign pix_y = (data_req == 1'b1)
             ? (cnt_v - (V_BLANK)) : 10'h3ff;

//rgb_tft_24b
assign rgb_lcd_24b = (data_req == 1'b1) ? data_in : 24'h000000;

//hsync, vsync
assign hsync = (cnt_h <= H_BLANK - 1'd1) ? 1'b1 : 1'b0 ;
assign vsync = (cnt_v <= V_BLANK - 1'd1) ? 1'b1 : 1'b0 ;

endmodule