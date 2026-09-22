`timescale 1ns/1ps
//=====================================================================
// fft2d_pipeline : PL 2D FFT 코어
//   입력(프레임 IQ 스트림) -> Range FFT -> corner-turn
//                          -> Doppler FFT -> magnitude -> 출력(R-D power)
//
//  - Range FFT와 Doppler FFT는 동일한 range_fft(128-pt FFT IP 래퍼)를
//    두 번 인스턴스화한 것이다. Vivado에선 같은 xfft_0 IP를 두 곳에서 쓴다.
//  - 입력 순서 : 처프0[샘플0..N-1], ... (처프마다 tlast)
//  - 출력 순서 : range bin 바깥, doppler bin 안쪽 (range*N + doppler)
//=====================================================================
module fft2d_pipeline #(
    parameter integer IQ_W = 16,
    parameter integer N    = 128
)(
    input  wire               clk,
    input  wire               rstn,
    // ---- 입력: 프레임 IQ 스트림 ----
    input  wire [2*IQ_W-1:0]  s_tdata,    // {Q, I}
    input  wire               s_tvalid,
    output wire               s_tready,
    input  wire               s_tlast,    // 처프(샘플 N개)마다 1
    // ---- 출력: R-D 전력 ----
    output wire [31:0]        m_tdata,
    output wire               m_tvalid,
    input  wire               m_tready,
    output wire               m_tlast
);
    // 단계 간 스트림
    wire [2*IQ_W-1:0] r_tdata;  wire r_tvalid, r_tready, r_tlast;   // Range FFT 출력
    wire [2*IQ_W-1:0] c_tdata;  wire c_tvalid, c_tready, c_tlast;   // corner-turn 출력
    wire [2*IQ_W-1:0] d_tdata;  wire d_tvalid, d_tready, d_tlast;   // Doppler FFT 출력

    // ---- ① Range FFT ----
    range_fft #(.IQ_W(IQ_W), .N(N)) u_range (
        .aclk(clk), .aresetn(rstn),
        .s_data_tdata(s_tdata), .s_data_tvalid(s_tvalid),
        .s_data_tready(s_tready), .s_data_tlast(s_tlast),
        .m_data_tdata(r_tdata), .m_data_tvalid(r_tvalid),
        .m_data_tready(r_tready), .m_data_tlast(r_tlast),
        .m_data_tuser()
    );

    // ---- ② corner-turn (전치) ----
    corner_turn #(.N(N), .DW(2*IQ_W)) u_ct (
        .clk(clk), .rstn(rstn),
        .s_tdata(r_tdata), .s_tvalid(r_tvalid), .s_tready(r_tready), .s_tlast(r_tlast),
        .m_tdata(c_tdata), .m_tvalid(c_tvalid), .m_tready(c_tready), .m_tlast(c_tlast)
    );

    // ---- ③ Doppler FFT (같은 FFT IP 재사용) ----
    range_fft #(.IQ_W(IQ_W), .N(N)) u_doppler (
        .aclk(clk), .aresetn(rstn),
        .s_data_tdata(c_tdata), .s_data_tvalid(c_tvalid),
        .s_data_tready(c_tready), .s_data_tlast(c_tlast),
        .m_data_tdata(d_tdata), .m_data_tvalid(d_tvalid),
        .m_data_tready(d_tready), .m_data_tlast(d_tlast),
        .m_data_tuser()
    );

    // ---- ④ magnitude (전력) ----
    magnitude #(.IQ_W(IQ_W)) u_mag (
        .clk(clk), .rstn(rstn),
        .s_tdata(d_tdata), .s_tvalid(d_tvalid), .s_tready(d_tready), .s_tlast(d_tlast),
        .m_tdata(m_tdata), .m_tvalid(m_tvalid), .m_tready(m_tready), .m_tlast(m_tlast)
    );
endmodule
