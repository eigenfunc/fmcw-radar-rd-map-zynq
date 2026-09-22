`timescale 1ns/1ps
//=====================================================================
// range_fft : Xilinx FFT IP(xfft_0)? ?? 128-point Range FFT ??
//---------------------------------------------------------------------
//  - ??  : ? ?? 128? IQ ??? AXI-Stream?? ???.
//            tdata = {Q[15:0], I[15:0]}  (Xilinx FFT IP ??: ??=??)
//  - ??  : 256? FFT ??? AXI-Stream?? ????.
//  - config: ?? ?? ? forward/scaling ??? 1? ?? ??.
//
//  Vivado?? Fast Fourier Transform IP? 'xfft_0' ???? ????
//  ? ??? ??? ???????. (?? ??? RANGE_FFT_GUIDE.md ??)
//=====================================================================
module range_fft #(
    parameter integer IQ_W     = 16,        // I/Q ??? ???
    parameter integer N        = 128,       // FFT ?? (?? ???? ??; ?? IP? ?? ? ??)
    parameter [15:0]  CFG_TDATA = 16'h00D5  // {scaling_schedule, fwd=1}. ??? ??.
)(
    input  wire              aclk,
    input  wire              aresetn,
    // ---- ?? ??? (? ?? = 256 ??) ----
    input  wire [2*IQ_W-1:0] s_data_tdata,   // {Q, I}
    input  wire              s_data_tvalid,
    output wire              s_data_tready,
    input  wire              s_data_tlast,    // 256?? ??? 1
    // ---- ?? ??? (FFT ?? 256?) ----
    output wire [2*IQ_W-1:0] m_data_tdata,    // {Q, I}
    output wire              m_data_tvalid,
    input  wire              m_data_tready,
    output wire              m_data_tlast,
    output wire [7:0]        m_data_tuser     // xk_index (0~255)
);
    //----------------------------------------------------------------
    // config ??: ??? ??? CFG_TDATA? ? ?? ????.
    //----------------------------------------------------------------
    reg  cfg_tvalid;
    reg  cfg_done;
    wire cfg_tready;

    always @(posedge aclk) begin
        if (!aresetn) begin
            cfg_tvalid <= 1'b0;
            cfg_done   <= 1'b0;
        end else if (!cfg_done) begin
            cfg_tvalid <= 1'b1;
            if (cfg_tvalid && cfg_tready) begin
                cfg_tvalid <= 1'b0;
                cfg_done   <= 1'b1;
            end
        end
    end

    //----------------------------------------------------------------
    // FFT IP ????
    //  - ??(`SIM` ?? ?): behavioral xfft_0? N ???? ??
    //  - ?? Vivado: ??? FFT IP(xfft_0)? N ????? ???? ?? ?????
    //----------------------------------------------------------------
`ifdef SIM
    xfft_0 #(.N(N)) u_xfft (
`else
    xfft_0 u_xfft (
`endif
        .aclk                 (aclk),
        .aresetn              (aresetn),
        .s_axis_config_tdata  (CFG_TDATA),
        .s_axis_config_tvalid (cfg_tvalid),
        .s_axis_config_tready (cfg_tready),
        .s_axis_data_tdata    (s_data_tdata),
        .s_axis_data_tvalid   (s_data_tvalid),
        .s_axis_data_tready   (s_data_tready),
        .s_axis_data_tlast    (s_data_tlast),
        .m_axis_data_tdata    (m_data_tdata),
        .m_axis_data_tvalid   (m_data_tvalid),
        .m_axis_data_tready   (m_data_tready),
        .m_axis_data_tlast    (m_data_tlast)
`ifdef SIM
        ,.m_axis_data_tuser   (m_data_tuser)   // behavioral ??? tuser ??
`endif
        // ?? xfft_0 IP(Natural Order)? tuser ??? ??.
        // event_* ?? 6?? ???(??? ? ???, ??).
    );

`ifndef SIM
    // ?? IP?? xk_index(tuser)? ???? 0?? ?? ??(???).
    assign m_data_tuser = 8'd0;
`endif
endmodule