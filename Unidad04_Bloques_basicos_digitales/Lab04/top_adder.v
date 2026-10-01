//`define ADDER_BCLA
`define ADDER_HCSA
module top_adder (
    output wire [16:0] o_sum, 
    input  wire [15:0] i_sampleA,
    input  wire [15:0] i_sampleB,
    input  wire        i_carry,
    input  wire        clock
);

`ifdef ADDER_BCLA
    bcla u_bcla
    (.a       (i_sampleA),
     .b       (i_sampleB),
     .c_in    (i_carry),
     .clk     (clock),
     .sum_r   (o_sum[15:0]),
     .c_out_r (o_sum[16]  )
    );

`elsif ADDER_HCSA
    hierarchicalcsa u_hierarchicalcsa
    (.a      (i_sampleA), 
     .b      (i_sampleB), 
     .cin    (i_carry), 
     .sum_r  (o_sum[15:0]), 
     .c_out_r(o_sum[16]  ), 
     .clk    (clock)
    );

`else
    rca u_rca 
    (.clk    (clock),
     .a      (i_sampleA),
     .b      (i_sampleB),
     .cin    (i_carry),
     .s_r    (o_sum[15:0]),
     .cout_r (o_sum[16]  )
    );
`endif

endmodule