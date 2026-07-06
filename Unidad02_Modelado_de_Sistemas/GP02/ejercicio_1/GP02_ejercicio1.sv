//13 bits: 1 sign bit ; 4 exponent bits ; 8 mantissa bits; bias value = 7

module ejercicio1(
    //OUTPUTS
    output wire signed [12:0] o_data,
    //INPUTS
    input wire signed  [12:0] i_operand_a,
    input wire signed  [12:0] i_operand_b
);

//SIGNAL DECLARATIONS
logic        [8-1:0] mant_a; //mantissa
logic        [8-1:0] mant_b; //mantissa 
logic        [4-1:0] exp_a; //exponent
logic        [4-1:0] exp_b; //exponent
logic                sign_a; //sign
logic                sign_b; //sign
logic                implied_mantissa_a; //implied mantissa
logic                implied_mantissa_b; //implied mantissa
logic        [18-1:0] mult_result; //result of the multiplication of the mantissas
logic        [4-1:0] exp_result; //result of the sum of the ex minus the bias value
logic        [4-1:0] exp_result_normalized; //result of the exponent normalization
logic                sign_result; //result of the sign operation
logic                corner_case_flag_a;
logic                corner_case_flag_b;
logic signed [12:0]  result; //final result

always_comb begin : g_signal_declaration
    //mantissa
    mant_a = i_operand_a[7:0];
    mant_b = i_operand_b[7:0];
    //exponent
    exp_a  = i_operand_a[11:8];
    exp_b  = i_operand_b[11:8];
    //sign
    sign_a = i_operand_a[12];
    sign_b = i_operand_b[12];
end

//Corner cases
always_comb begin : g_corner_cases
    corner_case_flag_a = ~(|i_operand_a) || ((exp_a == 4'b1111) && ((mant_a == 8'b0) || (mant_a == 8'b1000_0000)));
    corner_case_flag_b = ~(|i_operand_b) || ((exp_b == 4'b1111) && ((mant_b == 8'b0) || (mant_b == 8'b1000_0000)));
end

always_comb begin
    if(corner_case_flag_a == 1'b1) begin
        result = i_operand_a;
        $display("Operand A is a corner case: %b", i_operand_a);
    end else if(corner_case_flag_b == 1'b1 ) begin
        result = i_operand_b;
        $display("Operand B is a corner case: %b", i_operand_b);
    end else begin
        //sign result
        sign_result = sign_a ^ sign_b;
        //exponent result (addition of the exponents minus the bias value)
        exp_result = exp_a + exp_b - 4'd7; //bias value = 7
        //implied mantissa (0 if exponent is 0, 1 otherwise)
        implied_mantissa_a = (exp_a == 4'b0) ? 1'b0 : 1'b1;
        implied_mantissa_b = (exp_b == 4'b0) ? 1'b0 : 1'b1;
        //multiply mantissas
        mult_result = {implied_mantissa_a, mant_a} * {implied_mantissa_b, mant_b};
        //normalize the result of the multiplication
        if (mult_result[17] == 1'b1) begin
            // if mult_result[17] is 1, the exponent needs to be incremented by 1 and the mantissa needs to be shifted right by 1
            mult_result = mult_result >> 1;
            exp_result_normalized = exp_result + 4'd1;
        end else begin
            // if mult_result[17] is 0, both exponent and mantissa remains the same
            exp_result_normalized = exp_result;
        end
        //final result
        result = $signed({sign_result, exp_result_normalized, mult_result[15:8]});
        $display("Operand A: %b, Operand B: %b, Result: %b", i_operand_a, i_operand_b, result);
    end
end

//output assignments
assign o_data = result;


    
endmodule