//`define FIR_FILTER
//`define FIR_FILTER_CSD
//`define FIR_FILTER_CV
//`define FIR_FILTER_DA
module top_fir (
    output wire [31:0] o_sample,
    input  wire [15:0] i_sample,
    input  wire        i_reset_n,
    input  wire        clock
);
`ifdef FIR_FILTER
    FIRfilter u_FIRfilter(
        .x     (i_sample),
        .clk   (clock),
        .rst_n (i_reset_n),
        .yn    (o_sample)
    );
`elsif FIR_FILTER_CSD
    FIRfilterCSD u_FIRfilterCSD(
        .x     (i_sample),
        .clk   (clock),
        .rst_n (i_reset_n),
        .yncsd (o_sample)
    );
`elsif FIR_FILTER_CV
    FIRfilterCV u_FIRfilterCV(
        .x     (i_sample),
        .rst_n (i_reset_n),
        .clk   (clock),
        .yn    (o_sample)
    );
`elsif FIR_FILTER_DA
    FIRfilterDA u_FIRfilterDA(
        .x     (i_sample),
        .clk_g (clock),
        .rst_n (i_reset_n),
        .yn    (o_sample)
    );
`else
    FIRfilterTDFComp u_FIRfilterTDFComp(
        .x     (i_sample),
        .rst_n (i_reset_n),
        .clk   (clock),
        .yn    (o_sample)
    );
`endif

endmodule