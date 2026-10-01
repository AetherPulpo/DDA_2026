module tb_adder();
`define ADDER_BCLA_
//`define ADDER_HCSA_
   parameter NB_BITS = 16;

   reg [15:0] i_sampleA, i_sampleB;
   reg        i_carry;
   reg        clock;

   wire [16:0] o_sum_rca;
   wire [16:0] o_sum_bcla;
   wire [16:0] o_sum_hcsa;
   wire [16:0] o_sum_top;
   wire        compare;
   wire        compare_top;

   // Inicializacion
   initial begin
      i_sampleA = 0;
      i_sampleB = 0;
      i_carry   = 0;
      clock     = 0;
      #1000 $finish;
   end

   // Estimulos
   always@(posedge clock) begin
      i_sampleA <= $random;
      i_sampleB <= $random;
      i_carry   <= $random;
   end

   // Clock
   always
     #20 clock = ~clock;

   // Comparación de resutados
   assign compare = (o_sum_rca==o_sum_bcla && o_sum_rca==o_sum_hcsa) ? 0 : 1;

   // Instancias
   rca
     #(.W (NB_BITS))
   u_rca
     (.a      (i_sampleA),
      .b      (i_sampleB),
      .cin    (i_carry),
      .s_r    (o_sum_rca[15:0]),
      .cout_r (o_sum_rca[16]),
      .clk    (clock)
      );

   bcla
     #(.N (NB_BITS))
   u_bcla
     (.a         (i_sampleA),
      .b         (i_sampleB),
      .c_in      (i_carry),
      .sum_r     (o_sum_bcla[15:0]),
      .c_out_r   (o_sum_bcla[16]),
      .clk       (clock)
      );

   hierarchicalcsa
     u_hierarchicalcsa
       (.a      (i_sampleA),
        .b      (i_sampleB),
        .cin    (i_carry),
        .sum_r  (o_sum_hcsa[15:0]),
        .c_out_r(o_sum_hcsa[16]),
        .clk    (clock)
        );
        
    top_adder u_top_adder
    (.o_sum    (o_sum_top),
     .i_sampleA(i_sampleA),
     .i_sampleB(i_sampleB),
     .i_carry  (i_carry),
     .clock    (clock)
    );
    
    `ifdef ADDER_BCLA_
      assign compare_top = (o_sum_top == o_sum_bcla);
    `elsif ADDER_HCSA_
      assign compare_top = (o_sum_top == o_sum_hcsa);
    `else
      assign compare_top = (o_sum_top == o_sum_rca);
    `endif
endmodule
