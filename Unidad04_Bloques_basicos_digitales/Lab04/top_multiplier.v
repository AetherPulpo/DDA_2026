//`define MULT
module top_multiplier (
    output wire [10:0] o_mult, 
    input  wire [5:0]  i_sampleA,
    input  wire [5:0]  i_sampleB,
    input  wire        clock
);

`ifdef MULT
    mult u_mult
    (.a     (i_sampleA),
     .b     (i_sampleB),
     .prod  (o_mult),
     .clock (clock)
    );
`else
    boothMult u_boothMult
    (.i_multiplier   (i_sampleA),
     .i_multiplicand (i_sampleB),
     .o_product      (o_mult),
     .clock          (clock)
    );
`endif

endmodule