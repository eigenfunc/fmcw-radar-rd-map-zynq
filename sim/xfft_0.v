`timescale 1ns/1ps
//=====================================================================
// xfft_0 : *** 시뮬레이션 전용 *** Xilinx FFT IP의 behavioral 대역 모델
//---------------------------------------------------------------------
//  실제 Vivado 프로젝트에서는 이 파일을 빌드에서 제외하고
//  Fast Fourier Transform IP(이름 xfft_0)를 사용한다.
//
//  목적: Vivado/IP 없이 iverilog만으로 range_fft 래퍼와 testbench의
//        흐름(AXI handshake, 버퍼링, 결과 순서)을 검증하기 위함.
//  동작: 256-point forward DFT, 1/N 스케일링, natural-order 출력.
//        (진짜 IP의 비트 단위 결과와는 다르지만 피크 위치는 동일)
//=====================================================================
module xfft_0 #(
    parameter integer N = 128
) (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire [15:0] s_axis_config_tdata,
    input  wire        s_axis_config_tvalid,
    output reg         s_axis_config_tready,
    input  wire [31:0] s_axis_data_tdata,    // {Q[15:0], I[15:0]}
    input  wire        s_axis_data_tvalid,
    output reg         s_axis_data_tready,
    input  wire        s_axis_data_tlast,
    output reg  [31:0] m_axis_data_tdata,
    output reg         m_axis_data_tvalid,
    input  wire        m_axis_data_tready,
    output reg         m_axis_data_tlast,
    output reg  [7:0]  m_axis_data_tuser
);
    localparam real    PI = 3.14159265358979323846;

    real    re_in [0:N-1];
    real    im_in [0:N-1];
    real    re_out[0:N-1];
    real    im_out[0:N-1];
    integer in_cnt;
    integer out_cnt;

    localparam S_IDLE=0, S_COLLECT=1, S_COMPUTE=2, S_OUT=3;
    integer state;

    // 16-bit signed -> real
    function real s16_to_real(input [15:0] v);
        s16_to_real = $itor($signed(v));
    endfunction

    // 결과 real -> 16-bit signed (포화)
    function [15:0] real_to_s16(input real x);
        real r;
        begin
            r = x;
            if (r >  32767.0) r =  32767.0;
            if (r < -32768.0) r = -32768.0;
            real_to_s16 = $signed($rtoi(r >= 0.0 ? r + 0.5 : r - 0.5));
        end
    endfunction

    integer k, n;
    real ang, sumr, sumi;

    always @(posedge aclk) begin
        if (!aresetn) begin
            s_axis_config_tready <= 1'b1;
            s_axis_data_tready   <= 1'b0;
            m_axis_data_tvalid   <= 1'b0;
            m_axis_data_tlast    <= 1'b0;
            m_axis_data_tuser    <= 8'd0;
            in_cnt  <= 0;
            out_cnt <= 0;
            state   <= S_IDLE;
        end else begin
            s_axis_config_tready <= 1'b1;   // config는 항상 수락
            case (state)
                //--------------------------------------------------
                S_IDLE: begin
                    s_axis_data_tready <= 1'b1;
                    in_cnt <= 0;
                    state  <= S_COLLECT;
                end
                //--------------------------------------------------
                S_COLLECT: begin
                    s_axis_data_tready <= 1'b1;
                    if (s_axis_data_tvalid && s_axis_data_tready) begin
                        re_in[in_cnt] = s16_to_real(s_axis_data_tdata[15:0]);
                        im_in[in_cnt] = s16_to_real(s_axis_data_tdata[31:16]);
                        in_cnt <= in_cnt + 1;
                        if (s_axis_data_tlast || in_cnt == N-1) begin
                            s_axis_data_tready <= 1'b0;
                            state <= S_COMPUTE;
                        end
                    end
                end
                //--------------------------------------------------
                S_COMPUTE: begin
                    // 한 클럭에 전체 DFT 계산 (behavioral)
                    for (k = 0; k < N; k = k + 1) begin
                        sumr = 0.0; sumi = 0.0;
                        for (n = 0; n < N; n = n + 1) begin
                            ang  = -2.0 * PI * k * n / N;
                            sumr = sumr + re_in[n]*$cos(ang) - im_in[n]*$sin(ang);
                            sumi = sumi + re_in[n]*$sin(ang) + im_in[n]*$cos(ang);
                        end
                        re_out[k] = sumr / N;   // 1/N 스케일링
                        im_out[k] = sumi / N;
                    end
                    out_cnt <= 0;
                    state   <= S_OUT;
                end
                //--------------------------------------------------
                S_OUT: begin
                    if (!m_axis_data_tvalid || m_axis_data_tready) begin
                        m_axis_data_tdata  <= {real_to_s16(im_out[out_cnt]),
                                               real_to_s16(re_out[out_cnt])};
                        m_axis_data_tuser  <= out_cnt[7:0];
                        m_axis_data_tvalid <= 1'b1;
                        m_axis_data_tlast  <= (out_cnt == N-1);
                        if (out_cnt == N-1) begin
                            out_cnt <= 0;
                            state   <= S_IDLE;
                        end else begin
                            out_cnt <= out_cnt + 1;
                        end
                    end
                end
            endcase
            // 출력 핸드셰이크 완료 시 valid 내림
            if (m_axis_data_tvalid && m_axis_data_tready && state != S_OUT)
                m_axis_data_tvalid <= 1'b0;
        end
    end
endmodule
