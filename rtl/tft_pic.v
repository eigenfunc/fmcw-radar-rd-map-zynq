`timescale 1ns/1ps
//=====================================================================
// tft_pic : R-D 전력맵 렌�?�러 (�?수 lcd_pic �?리�? �?체)
//   �?수 �?�터페�?�스(clk_in/sys_rst_n/pix_x/pix_y/pix_data)�? 맞추고,
//   프레임버�?� 연결(rd_addr 출력, rd_power 입력)�?� 추가했다.
//   R-D 맵(N x N)�?� 화면 중앙�? 2배 확대해서 heat 컬러맵으로 그린다.
//=====================================================================
module tft_pic #(
    parameter integer N     = 128,
    parameter integer HRES  = 800,
    parameter integer VRES  = 480
)(
    input  wire        clk_in,
    input  wire        sys_rst_n,
    input  wire [10:0] pix_x,
    input  wire [10:0] pix_y,
    output wire [$clog2(N*N)-1:0] rd_addr,   // range*N + doppler
    input  wire [31:0]            rd_power,
    output reg  [23:0] pix_data               // {R,G,B}  -> lcd_ctrl.data_in
);
    localparam integer MAPSZ = N*2;               // 2배 확대
    localparam integer X0    = (HRES-MAPSZ)/2;    // 가로 중앙
    localparam integer Y0    = (VRES-MAPSZ)/2;    // 세로 중앙

    wire in_map = (pix_x >= X0) && (pix_x < X0+MAPSZ)
               && (pix_y >= Y0) && (pix_y < Y0+MAPSZ);

    wire [6:0] bin_doppler   = (pix_x - X0) >> 1;
    wire [6:0] bin_range   = (N - 1) - ((pix_y - Y0) >> 1);
    assign rd_addr = bin_range * N + bin_doppler;

    // 전력 -> 레벨 (최�?위 비트 위치 ≈ log2)
    reg [4:0] level;
    integer k;
    always @* begin
        level = 5'd0;
        for (k = 0; k < 32; k = k + 1)
            if (rd_power[k]) level = k[4:0];
    end

    // heat 컬러맵
    reg [7:0] cr, cg, cb;
    always @* begin
        if (!in_map) begin
            cr=8'h00; cg=8'h00; cb=8'h00;
        end else if (level < 10) begin
            cr=8'h00; cg=8'h00; cb=level*24;
        end else if (level < 16) begin
            cr=8'h00; cg=(level-10)*40; cb=8'hFF;
        end else if (level < 22) begin
            cr=(level-16)*40; cg=8'hFF; cb=8'hFF-(level-16)*40;
        end else begin
            cr=8'hFF; cg=(31-level)*28; cb=8'h00;
        end
    end
    always @* pix_data = {cr, cg, cb};
endmodule
