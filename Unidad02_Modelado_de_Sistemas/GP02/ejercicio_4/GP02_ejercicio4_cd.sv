//THIS IS A FOLDED FILTER, ASSUMING SYMMETRIC EVEN COEFFICIENTS
module ejercicio4_cd #(
    parameter P_NB_IN = 16,
    parameter P_NBF_IN = 15,
    parameter P_NB_COEFF = P_NB_IN,
    parameter P_NBF_COEFF = P_NBF_IN,
    parameter P_NUM_COEFF = 4,
    parameter P_NB_OUT = 18 + $clog2(P_NUM_COEFF/2), // 18 + 1
    parameter P_MODE = 0
) (
    //OUTPUTS
    output wire signed [P_NB_OUT - 1 : 0]y, //S(19.16)
    //INPUTS
    input  wire signed [P_NB_IN - 1 : 0]x, //S(16.15)
    input  wire signed [P_NB_IN - 1 : 0]h[P_NUM_COEFF - 1 : 0], //S(16.15)
        //ctrl ports
    input wire clk
);

//THIS MODULE WON'T SYNTHESIZE IF THE P_NUM_COEFF IS AN ODD VALUE (1, 3 ,7, ...)
//SINCE, THIS FOLDED FILTER REQUIRES AN EVEN NUMBER OF COEFFICIENTS
generate
    if (P_NUM_COEFF % 2 != 0) begin : g_param_check
        initial $fatal(1, "P_NUM_COEFF (%0d) needs to have an even value (2, 4, 6,...)", P_NUM_COEFF);
    end
endgenerate

    //LOCALPARAM DECLARATIONS
localparam P_NB_ADD_FOLDED = P_NB_IN + $clog2(2); // 16 + 1 = 17
localparam P_FOLDED_FACTOR = P_NUM_COEFF/2; // 4/2 = 2
localparam P_NB_MULT  = P_NB_ADD_FOLDED + P_NB_COEFF  ;//17 + 16 = 33
localparam P_NBF_MULT = P_NBF_IN + P_NBF_COEFF ;//15 + 15 = 30
localparam P_NB_MULT_CLIPPED   = 18; //REQUESTED IN THE EXCERCISE
localparam P_NBF_MULT_CLIPPED  = P_NB_MULT_CLIPPED - 2; //FOR THE OPTIMIZATION, I WILL SATURATE 1 BIT. HENCE S(18.16)
//NOTE: the MULT CLIPPED result of S(18.16) instead of S(18.15): it's because 16 as NBF is the same bit width as both DATA and COEFF
//      Moreover, I don't consider S(19.16) as a proper result since with the optimization the data will be [-2, ~2] and coefficients will be [-1, ~1].
//      therefore, the result does not need to be S(19.16).
//      The second reason is that the exercise states an 18 bit adder.
    //SIGNAL DECLARATIONS
logic signed [P_NB_IN - 1 : 0] x_q [P_NUM_COEFF - 2 : 0]; //input register
logic signed [P_NB_ADD_FOLDED - 1 : 0] folded_add [P_FOLDED_FACTOR - 1 : 0]; //S(17.15). Folded sum
logic signed [P_NB_MULT - 1 : 0] mult_result [P_FOLDED_FACTOR - 1 : 0]; //S(33.30). Results of x[n]*h[n]
logic signed [P_NB_MULT_CLIPPED - 1 : 0] mult_result_clipped [P_FOLDED_FACTOR - 1 : 0]; //S(18.16). multiplication Clipped version
logic signed [P_NB_OUT - 1 : 0] add_tree; // S(19.16)
logic signed [P_NB_OUT - 1 : 0] add_result; // S(19.16). Adder tree result

//"x" IS REGISTERED P_NUM_COEFF-2 TIMES
always_ff @(posedge clk) begin
    for (int i=P_NUM_COEFF-2; i>0; i--) begin
        x_q[i] <= x_q[i-1];
    end
    x_q[0] <= x;
end

//SUM AND MULTIPLICATION FOR FOLDED FILTER (e.g h_0(x[n]+x[n-3]))
always_comb begin
    //SUM
    folded_add[0] = x + x_q[P_NUM_COEFF-2];
    for (int i=1; i<P_FOLDED_FACTOR; ++i) begin
        folded_add[i] = x_q[i-1] + x_q[(P_NUM_COEFF-2)-i]; 
    end
    //MULTIPLICATION (FOLDED DATA . COEFF)
    for (int i=0; i<P_FOLDED_FACTOR; ++i) begin
        mult_result[i] = folded_add[i] * h[i]; 
    end
end

//TRUNCATE RESULT OF MULTIPLICATION
genvar j;
generate
    for (j = 0; j<P_FOLDED_FACTOR; ++j) begin : g_rnd
        rnd #(
            .P_NB_IN(P_NB_MULT), // 33
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
    for (int i=0; i<P_FOLDED_FACTOR; ++i) begin
        add_tree += mult_result_clipped[i];
    end
    add_result = add_tree;
end

//OUTPUT DECLARATION
assign y = add_result;
endmodule