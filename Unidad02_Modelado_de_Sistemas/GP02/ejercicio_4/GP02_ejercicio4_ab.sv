module ejercicio4_ab #(
    parameter P_NB_IN = 16,
    parameter P_NBF_IN = 15,
    parameter P_NB_COEFF = P_NB_IN,
    parameter P_NBF_COEFF = P_NBF_IN,
    parameter P_NUM_COEFF = 4,
    parameter P_NB_OUT = 18 + $clog2(P_NUM_COEFF), // 18 + 2
    parameter P_MODE = 0
) (
    //OUTPUTS
    output wire signed [P_NB_OUT - 1 : 0]y, //S(20.16)
    //INPUTS
    input  wire signed [P_NB_IN - 1 : 0]x, //S(16.15)
    input  wire signed [P_NB_IN - 1 : 0]h[P_NUM_COEFF - 1 : 0], //S(16.15)
        //ctrl ports
    input wire clk
);
    //LOCALPARAM DECLARATIONS
localparam P_NB_MULT  = P_NB_IN  + P_NB_COEFF  ;//16 + 16 = 32
localparam P_NBF_MULT = P_NBF_IN + P_NBF_COEFF ;//15 + 15 = 30
localparam P_NB_MULT_CLIPPED   = 18; //REQUESTED IN THE EXCERCISE
localparam P_NBF_MULT_CLIPPED  = P_NB_MULT_CLIPPED - 2; //EXCERCISE STATES TRUNCATION BUT NO SATURATION, HENCE S(18.16)
    //SIGNAL DECLARATIONS
logic signed [P_NB_IN - 1 : 0] x_q [P_NUM_COEFF - 2 : 0]; //input register
logic signed [P_NB_MULT - 1 : 0] mult_result [P_NUM_COEFF - 1 : 0]; //S(32.30). Results of x[n]*h[n]
logic signed [P_NB_MULT_CLIPPED - 1 : 0] mult_result_clipped [P_NUM_COEFF - 1 : 0]; //S(18.16). multiplication Clipped version
logic signed [P_NB_OUT - 1 : 0] add_tree; // S(20.16)
logic signed [P_NB_OUT - 1 : 0] add_result; // S(20.16). Adder tree result

//"x" IS REGISTERED P_NUM_COEFF-2 TIMES
always_ff @(posedge clk) begin
    for (int i=P_NUM_COEFF-2; i>0; i--) begin
        x_q[i] <= x_q[i-1];
    end
    x_q[0] <= x;
end

//MULTIPLICATION x . h (DATA . COEFF)
assign mult_result[0] = x * h[0];
always_comb begin
    for (int i=1; i<P_NUM_COEFF; ++i) begin
        mult_result[i] = x_q[i-1] * h[i]; 
    end
end

//TRUNCATE RESULT OF MULTIPLICATION
genvar j;
generate
    for (j = 0; j<P_NUM_COEFF; ++j) begin : g_rnd
        rnd #(
            .P_NB_IN(P_NB_MULT), // 32
            .P_MODE(P_MODE),  //0: floor (plain truncation)
            .P_NB_TO_RND(P_NBF_MULT - P_NBF_MULT_CLIPPED), //DROP 30 - 16 = 14 LSB
            .P_NB_OUT(P_NB_MULT_CLIPPED), //18
            .P_PRE_FF(0),
            .P_PST_FF(0)
        )u_rnd(
            .o_dout(mult_result_clipped[j]),
            .i_din(mult_result[j]),
            .clk(clk)
        );   
    end
endgenerate

//ADDER TREE
always_comb begin
    add_tree = '0;
    for (int i=0; i<P_NUM_COEFF; ++i) begin
        add_tree += mult_result_clipped[i];
    end
    add_result = add_tree;
end

//OUTPUT DECLARATION
assign y = add_result;
endmodule