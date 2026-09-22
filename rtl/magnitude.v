`timescale 1ns/1ps
//=====================================================================
// magnitude : 복소 스트림 -> 전력(|X|^2 = I^2 + Q^2)
//---------------------------------------------------------------------
//  Doppler FFT 출력 {Q[15:0], I[15:0]}을 받아 32비트 전력값을 낸다.
//  R-D Map 색칠에는 sqrt가 필요 없다(단조증가라 피크/상대크기 보존).
//  필요하면 나중에 Xilinx CORDIC IP로 진짜 magnitude(sqrt)로 교체 가능.
//
//  조합 pass-through (latency 0). I,Q 각 16비트 signed.
//  power 최대 = 2*(2^15)^2 = 2^31 < 2^32 이므로 32비트 unsigned로 안전.
//=====================================================================
module magnitude #(
    parameter integer IQ_W = 16
)(
    input  wire               clk,
    input  wire               rstn,
    input  wire [2*IQ_W-1:0]  s_tdata,    // {Q, I}
    input  wire               s_tvalid,
    output wire               s_tready,
    input  wire               s_tlast,
    output wire [31:0]        m_tdata,    // I^2 + Q^2 (전력)
    output wire               m_tvalid,
    input  wire               m_tready,
    output wire               m_tlast
);
    wire signed [IQ_W-1:0] i_s = s_tdata[IQ_W-1:0];
    wire signed [IQ_W-1:0] q_s = s_tdata[2*IQ_W-1:IQ_W];

    wire [31:0] ii = i_s * i_s;          // 양수, 최대 2^30
    wire [31:0] qq = q_s * q_s;
    wire [31:0] power = ii + qq;         // 최대 2^31, 32비트 안전

    assign m_tdata  = power;
    assign m_tvalid = s_tvalid;
    assign s_tready = m_tready;
    assign m_tlast  = s_tlast;
endmodule
