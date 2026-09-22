`timescale 1ns/1ps
//=====================================================================
// corner_turn : 2D FFT ??? ?? ?? [batch ??, ping-pong ??]
//---------------------------------------------------------------------
//  Range FFT ?? ???? N x N BRAM? ??(chirp) ???? ??,
//  ??(range bin) ???? ??? Doppler FFT ??????? ????.
//=====================================================================
module corner_turn #(
    parameter integer N  = 128,     // Range/Doppler ? ? ??
    parameter integer DW = 32       // ??? ?? ? (16 I + 16 Q)
)(
    input  wire          clk,
    input  wire          rstn,
    // ---- ??: Range FFT ?? ??? ----
    input  wire [DW-1:0] s_tdata,
    input  wire          s_tvalid,
    output wire          s_tready,
    input  wire          s_tlast,   
    // ---- ??: ?? ??? (Doppler FFT ??) ----
    output wire [DW-1:0] m_tdata,
    output wire          m_tvalid,
    input  wire          m_tready,
    output wire          m_tlast
);
    localparam integer DEPTH = N*N;
    localparam integer AW    = $clog2(DEPTH);
    localparam integer CW    = $clog2(N);

    (* ram_style = "block" *)
    reg [DW-1:0] mem [0:DEPTH-1];

    reg [AW-1:0] wr_addr;
    reg [CW-1:0] out_bin, out_chirp;   // out_bin: ?? ?, out_chirp: ?? ?
    reg          state;
    localparam S_WRITE = 1'b0, S_READ = 1'b1;

    // ?? ???: ??/?? ?? ??
    wire [AW-1:0] rd_addr = out_chirp*N + out_bin;

    reg [DW-1:0] rd_data;
    reg          rd_valid_d;
    reg          rd_last_d;

    wire rd_en = (state == S_READ) && m_tready;

    assign s_tready = (state == S_WRITE);
    assign m_tvalid = rd_valid_d;
    assign m_tdata  = rd_data;
    assign m_tlast  = rd_valid_d && rd_last_d;

    //--- 1. ??? ?? ?? ?? (?? ?? -> BRAM ?? ??) ---
    always @(posedge clk) begin
        if (state == S_WRITE && s_tvalid) begin
            mem[wr_addr] <= s_tdata;
        end
    end

    //--- 2. ?? ?? ? ?? ?? ?? (?? ??) ---
    always @(posedge clk) begin
        if (!rstn) begin
            state      <= S_WRITE;
            wr_addr    <= 0;
            out_bin    <= 0;
            out_chirp  <= 0;
            rd_valid_d <= 1'b0;
            rd_last_d  <= 1'b0;
        end else begin
            if (m_tready)
                rd_valid_d <= 1'b0;

            case (state)
                S_WRITE: if (s_tvalid) begin
                    if (wr_addr == DEPTH-1) begin
                        wr_addr   <= 0;
                        out_bin   <= 0;
                        out_chirp <= 0;
                        state     <= S_READ;
                    end else begin
                        wr_addr <= wr_addr + 1'b1;
                    end
                end

                S_READ: if (rd_en) begin
                    rd_data    <= mem[rd_addr];
                    rd_valid_d <= 1'b1;
                    rd_last_d  <= (out_chirp == N-1);

                    if (out_chirp == N-1) begin
                        out_chirp <= 0;
                        if (out_bin == N-1) begin
                            out_bin <= 0;
                            state   <= S_WRITE;   // ?? ??? ??
                        end else begin
                            out_bin <= out_bin + 1'b1;
                        end
                    end else begin
                        out_chirp <= out_chirp + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule