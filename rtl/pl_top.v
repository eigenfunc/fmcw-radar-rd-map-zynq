`timescale 1ns/1ps
//=====================================================================
// pl_top : PL 전체 통합
//   [DMA] -AXI-Stream(IQ)-> fft2d_pipeline -> rd_framebuffer
//                        -> tft_pic -> lcd_ctrl -> LCD
//   clk_wiz_0(교수/Vivado) : sys_clk(100M) -> lcd_clk_33m
//   lcd_ctrl(교수 제공)    : pix_x/y 생성, data_in(색) -> rgb_lcd_24b
//
//   * clk_wiz_0, lcd_ctrl 은 우리가 짜지 않는다(교수 코드 / Vivado IP).
//     시뮬레이션 검증용 stub는 tb에서 제공한다.
//=====================================================================
module pl_top #(
    parameter integer N    = 128,
    parameter integer IQ_W = 16,
    parameter integer HRES = 800,
    parameter integer VRES = 480
)(
    input  wire        sys_clk,      // 100 MHz
    input  wire        sys_rst_n,
    // ---- DMA에서 오는 IQ 스트림 ----
    input  wire [2*IQ_W-1:0] s_axis_tdata,   // {Q, I}
    input  wire              s_axis_tvalid,
    output wire              s_axis_tready,
    input  wire              s_axis_tlast,
    // ---- LCD 출력 ----
    output wire [23:0] rgb_lcd,
    output wire        hsync,
    output wire        vsync,
    output wire        lcd_clk,
    output wire        lcd_de,
    output wire        lcd_ud,
    output wire        lcd_bl
);
    wire        lcd_clk_33m, locked;
    wire [10:0] pix_x;
    wire [10:0] pix_y;

    assign lcd_ud = 1'b0;
    wire [23:0] pix_data;
    wire [31:0] fft_power;  wire fft_valid, fft_ready;
    wire [$clog2(N*N)-1:0] rd_addr;  wire [31:0] rd_power;

    // ---- Clock IP (교수 PPT: 100MHz -> 33MHz) ----
    clk_wiz_0 u_clk (
        .reset   (~sys_rst_n),
        .clk_in1 (sys_clk),
        .clk_out1(lcd_clk_33m),
        .locked  (locked)
    );

    // ---- 2D FFT (sys_clk) ----
    fft2d_pipeline #(.IQ_W(IQ_W), .N(N)) u_fft2d (
        .clk(sys_clk), .rstn(sys_rst_n),
        .s_tdata(s_axis_tdata), .s_tvalid(s_axis_tvalid),
        .s_tready(s_axis_tready), .s_tlast(s_axis_tlast),
        .m_tdata(fft_power), .m_tvalid(fft_valid),
        .m_tready(fft_ready), .m_tlast()
    );

    // ---- R-D 프레임버퍼 (wr: sys_clk / rd: lcd_clk) ----
    rd_framebuffer #(.N(N)) u_fb (
        .wr_clk(sys_clk), .wr_rstn(sys_rst_n),
        .wr_data(fft_power), .wr_valid(fft_valid), .wr_ready(fft_ready), .wr_last(),
        .rd_clk(lcd_clk_33m), .rd_addr(rd_addr), .rd_data(rd_power)
    );

    // ---- R-D 렌더러 (교수 lcd_pic 자리) ----
    tft_pic #(.N(N), .HRES(HRES), .VRES(VRES)) u_pic (
        .clk_in(lcd_clk_33m), .sys_rst_n(sys_rst_n),
        .pix_x(pix_x), .pix_y(pix_y),
        .rd_addr(rd_addr), .rd_power(rd_power),
        .pix_data(pix_data)
    );

    // ---- LCD 컨트롤러 (교수 제공) ----
    lcd_ctrl u_ctrl (
        .clk_in(lcd_clk_33m), .sys_rst_n(sys_rst_n),
        .data_in(pix_data), .data_req(),
        .pix_x(pix_x), .pix_y(pix_y),
        .rgb_lcd_24b(rgb_lcd),
        .hsync(hsync), .vsync(vsync),
        .lcd_clk(lcd_clk), .lcd_de(lcd_de), .lcd_bl(lcd_bl)
    );
endmodule
