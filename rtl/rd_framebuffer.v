// rd_framebuffer  [v2: ??? mux - buf0/buf1 ?? ?? ??? ??, latency 1]
`timescale 1ns/1ps
module rd_framebuffer #(
    parameter integer N  = 128,
    parameter integer DW = 32
)(
    input  wire              wr_clk,
    input  wire              wr_rstn,
    input  wire [DW-1:0]     wr_data,
    input  wire              wr_valid,
    output wire              wr_ready,
    input  wire              wr_last,
    input  wire              rd_clk,
    input  wire [$clog2(N*N)-1:0] rd_addr,
    output wire [DW-1:0]     rd_data
);
    localparam integer DEPTH = N*N;
    localparam integer AW    = $clog2(DEPTH);

    (* ram_style = "block" *) reg [DW-1:0] buf0 [0:DEPTH-1];
    (* ram_style = "block" *) reg [DW-1:0] buf1 [0:DEPTH-1];

    reg [AW-1:0] wr_addr;
    reg          wr_buf;
    assign wr_ready = 1'b1;

    always @(posedge wr_clk) begin
        if (!wr_rstn) begin
            wr_addr <= 0;
            wr_buf  <= 1'b0;
        end else if (wr_valid) begin
            if (wr_buf == 1'b0) buf0[wr_addr] <= wr_data;
            else                buf1[wr_addr] <= wr_data;
            if (wr_addr == DEPTH-1) begin
                wr_addr <= 0;
                wr_buf  <= ~wr_buf;
            end else begin
                wr_addr <= wr_addr + 1'b1;
            end
        end
    end

    reg sel_meta, sel_rd;
    always @(posedge rd_clk) begin
        sel_meta <= wr_buf;
        sel_rd   <= sel_meta;
    end
    wire rd_buf = ~sel_rd;

    //--- ??: buf0/buf1 ? ? ?? ????? mux (1?? ??) ---
    reg [DW-1:0] rd_data0, rd_data1;
    reg          rd_buf_d;
    always @(posedge rd_clk) begin
        rd_data0 <= buf0[rd_addr];
        rd_data1 <= buf1[rd_addr];
        rd_buf_d <= rd_buf;
    end
    assign rd_data = (rd_buf_d == 1'b0) ? rd_data0 : rd_data1;
endmodule