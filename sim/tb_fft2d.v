`timescale 1ns/1ps
//=====================================================================
// tb_fft2d : 2D FFT integration testbench
//   MODE=0 : internal synthetic single target (small N, quick structure check)
//   MODE=1 : frame_synth.mem (N=128, Vivado)
//   MODE=2 : frame_real.mem  (N=128, Vivado, ColoRadar)
//
//   Output order: range bin outer, doppler bin inner (idx = range*N + doppler).
//   RTL does NOT fftshift, so doppler bin is natural order (0 = stationary).
//
//   On finish, dumps all N*N power values to fft_out.txt (hex, one per line).
//=====================================================================
module tb_fft2d;
    parameter integer N    = 128;    // iverilog:16 / Vivado:128
    parameter integer MODE = 1;      // 0=internal / 1=synth.mem / 2=real.mem
    parameter integer IQ_W = 16;
    localparam integer DEPTH = N*N;

    reg clk = 0, rstn = 0;
    always #5 clk = ~clk;

    reg  [2*IQ_W-1:0] s_tdata;  reg s_tvalid, s_tlast;  wire s_tready;
    wire [31:0]       m_tdata;  wire m_tvalid, m_tlast; reg m_tready;

    fft2d_pipeline #(.IQ_W(IQ_W), .N(N)) dut (
        .clk(clk), .rstn(rstn),
        .s_tdata(s_tdata), .s_tvalid(s_tvalid), .s_tready(s_tready), .s_tlast(s_tlast),
        .m_tdata(m_tdata), .m_tvalid(m_tvalid), .m_tready(m_tready), .m_tlast(m_tlast)
    );

    reg [2*IQ_W-1:0] in_mem  [0:DEPTH-1];
    reg [31:0]       out_pow [0:DEPTH-1];
    integer recv;

    always @(posedge clk)
        if (m_tvalid && m_tready) begin
            out_pow[recv] <= m_tdata;
            recv <= recv + 1;
        end

    integer i, c, s, r0, d0, ival, qval, pk, fd;
    real    A, ph, mx;

    initial begin
        s_tvalid = 0; s_tlast = 0; m_tready = 1; recv = 0;

        // ---- prepare input ----
        if (MODE == 0) begin
            r0 = 5; d0 = 3; A = 10000.0;      // range bin 5, doppler bin 3
            for (c = 0; c < N; c = c + 1)
                for (s = 0; s < N; s = s + 1) begin
                    ph   = 2.0*3.14159265358979*(r0*s + d0*c)/N;
                    ival = $rtoi(A*$cos(ph));
                    qval = $rtoi(A*$sin(ph));
                    in_mem[c*N+s] = {qval[15:0], ival[15:0]};
                end
        end else if (MODE == 1) begin
            $readmemh("frame_synth.mem", in_mem);
        end else begin
            $readmemh("frame_synth.mem", in_mem);
        end

        rstn = 0; repeat (4) @(posedge clk); rstn = 1; @(posedge clk);

        // ---- feed: tlast every chirp (N samples) ----
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(posedge clk);
            while (!s_tready) @(posedge clk);
            s_tdata  <= in_mem[i];
            s_tvalid <= 1'b1;
            s_tlast  <= ((i % N) == N-1);
        end
        @(posedge clk);
        s_tvalid <= 1'b0;
        s_tlast  <= 1'b0;

        // ---- receive output ----
        wait (recv == DEPTH);
        repeat (2) @(posedge clk);

        // ---- dump full R-D power map to file (hex, idx = range*N + doppler) ----
        fd = $fopen("fft_out.txt", "w");
        for (i = 0; i < DEPTH; i = i + 1)
            $fdisplay(fd, "%08h", out_pow[i]);
        $fclose(fd);
        $display("[dump] fft_out.txt written (%0d values)", DEPTH);

        // ---- peak location ----
        mx = 0; pk = 0;
        for (i = 0; i < DEPTH; i = i + 1)
            if (out_pow[i] > mx) begin mx = out_pow[i]; pk = i; end
        $display("\n[RESULT] max peak idx=%0d -> range bin=%0d, doppler bin=%0d",
                 pk, pk/N, pk%N);
        if (MODE == 0)
            $display("  expected range=%0d doppler=%0d  %s",
                     r0, d0, (pk/N==r0 && pk%N==d0) ? "[PASS]" : "[FAIL]");
        $finish;
    end

    initial begin
        #50000000;
        $display("TIMEOUT (recv=%0d)", recv);
        $finish;
    end
endmodule