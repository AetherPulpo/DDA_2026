`timescale 1ns/1ps
 
module tb_ejercicio1;
 
    logic [12:0] a, b;
    logic [12:0] y;
    int errors = 0;
 
    // Reference encodings
    localparam logic [12:0] VAL_2_0   = 13'b0_1000_00000000; // 2.0 (normal operand for pairing)
    localparam logic [12:0] ZERO      = 13'b0_0000_00000000; // 0
    localparam logic [12:0] POS_INF   = 13'b0_1111_00000000; // +inf
    localparam logic [12:0] NEG_INF   = 13'b1_1111_00000000; // -inf
    localparam logic [12:0] NAN_VAL   = 13'b1_1111_10000000; // NaN (sign 1, exp 1111, mant MSB=1)
 
    // DUT
    ejercicio1 dut_ejercicio1 (
        .o_data     (y),
        .i_operand_a(a),
        .i_operand_b(b)
    );
 
    // Apply stimulus and compare against the expected value
    task automatic check(input logic [12:0] va,
                         input logic [12:0] vb,
                         input logic [12:0] exp,
                         input string       name);
        a = va; b = vb;
        #1; // let the combinational logic settle
        if (y === exp) begin
            $display("[OK]   %-22s a=%b b=%b -> y=%b", name, a, b, y);
        end else begin
            errors++;
            $display("[FAIL] %-22s a=%b b=%b -> y=%b (expected %b)",
                     name, a, b, y, exp);
        end
    endtask
 
    initial begin
        $display("=== Simulation start ===");
 
        //----------------------------------------------------------------------
        // Normal operation
        //----------------------------------------------------------------------
        check(13'b0_0111_00000000, 13'b0_0111_00000000,
              13'b0_0111_00000000, "1.0 * 1.0");     // = 1.0
        check(13'b0_1000_00000000, 13'b0_1000_00000000,
              13'b0_1001_00000000, "2.0 * 2.0");     // = 4.0
        check(13'b0_0111_10000000, 13'b0_0111_10000000,
              13'b0_1000_00100000, "1.5 * 1.5");     // = 2.25
        check(13'b1_0111_10000000, 13'b0_1000_00000000,
              13'b1_1000_10000000, "-1.5 * 2.0");    // = -3.0
        check(13'b0_0111_00000000, 13'b1_0111_00000000,
              13'b1_0111_00000000, "1.0 * -1.0");    // = -1.0
 
        //----------------------------------------------------------------------
        // Corner cases on operand_a  (paired with normal B = 2.0)
        // The DUT returns operand A unchanged.
        //----------------------------------------------------------------------
        check(ZERO,    VAL_2_0, ZERO,    "A = 0");
        check(POS_INF, VAL_2_0, POS_INF, "A = +inf");
        check(NEG_INF, VAL_2_0, NEG_INF, "A = -inf");
        check(NAN_VAL, VAL_2_0, NAN_VAL, "A = NaN");
 
        //----------------------------------------------------------------------
        // Corner cases on operand_b  (paired with normal A = 2.0)
        // A is not special, so the DUT returns operand B unchanged.
        //----------------------------------------------------------------------
        check(VAL_2_0, ZERO,    ZERO,    "B = 0");
        check(VAL_2_0, POS_INF, POS_INF, "B = +inf");
        check(VAL_2_0, NEG_INF, NEG_INF, "B = -inf");
        check(VAL_2_0, NAN_VAL, NAN_VAL, "B = NaN");
 
        $display("=== Done: %0d errors ===", errors);
        if (errors == 0) $display(">>> ALL TESTS PASSED <<<");
        $finish;
    end
 
endmodule