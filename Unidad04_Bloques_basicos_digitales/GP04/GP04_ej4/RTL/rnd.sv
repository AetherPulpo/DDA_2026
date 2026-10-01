//======================================================================
//  rnd.sv
//
//  Generic truncation + rounding block with saturation to the output
//  width. Meant to be instantiated as a common datapath module.
//
//  Processing chain:
//     1) Optional input register    (P_PRE_FF)
//     2) Rounding / truncation      (P_MODE, P_NB_TO_RND)
//     3) Saturation to output width (P_NB_OUT)
//     4) Optional output register   (P_PST_FF)
//
//  Rounding modes (P_MODE) -- k = P_NB_TO_RND dropped LSBs:
//
//     0 - Floor / round toward -inf
//         Plain truncation of the low bits. The result is always <=
//         the exact value.        2.7 -> 2 ,  -2.3 -> -3
//
//     1 - Ceil / round toward +inf
//         Rounds up whenever any dropped bit is non-zero. The result
//         is always >= the exact value.   2.1 -> 3 ,  -2.7 -> -2
//
//     2 - Round half away from zero
//         Round to nearest; exact halves go to the larger magnitude.
//         2.5 -> 3 ,  -2.5 -> -3
//
//     3 - Round half up (ties toward +inf)
//         Round to nearest; exact halves always go toward +inf.
//         2.5 -> 3 ,  -2.5 -> -2
//
//     (Modes 2 and 3 behave identically for positive inputs; they only
//      differ on negative exact-half values.)
//
//  Note: P_NB_TO_RND < P_NB_IN is assumed (the sign bit is always kept).
//  Under that condition a single guard bit is enough to absorb the
//  rounding carry without overflow.
//======================================================================
module rnd #(
    parameter int P_NB_IN     = 9,   // input width
    parameter int P_MODE      = 0,   // 0:-inf  1:+inf  2:half away  3:half up
    parameter int P_NB_TO_RND = 0,   // number of LSBs to drop
    parameter int P_NB_OUT    = 9,   // output width
    parameter int P_PRE_FF    = 0,   // 1: add an input flop stage
    parameter int P_PST_FF    = 0    // 1: add an output flop stage
)(
    output logic signed [P_NB_OUT-1:0] o_dout,
    input  logic signed [P_NB_IN-1:0]  i_din,
    input  logic                       clk
);
 
    // Width of the value after rounding. When bits are dropped the
    // rounding step may propagate a carry upward, so one guard bit is
    // reserved.
    localparam int NB_RND = (P_NB_TO_RND == 0) ? P_NB_IN
                                               : P_NB_IN - P_NB_TO_RND + 1;
 
    logic signed [P_NB_IN-1:0]  din_r;    // input (registered or combinational)
    logic signed [NB_RND-1:0]   rnd_val;  // rounded value
    logic signed [P_NB_OUT-1:0] sat_val;  // saturated value
    logic signed [P_NB_OUT-1:0] dout_r;   // output (registered or combinational)
 
    //------------------------------------------------------------------
    // 1) Input stage
    //------------------------------------------------------------------
    generate
        if (P_PRE_FF == 1) begin : g_pre_ff
            always_ff @(posedge clk)
                din_r <= i_din;
        end else begin : g_pre_comb
            assign din_r = i_din;
        end
    endgenerate
 
    //------------------------------------------------------------------
    // 2) Rounding stage
    //
    //  Every mode is handled with the same trick: add an "offset" to the
    //  input and then truncate the P_NB_TO_RND low bits. In two's
    //  complement, truncation is a floor, hence:
    //
    //     -inf (floor)   -> offset = 0
    //     +inf (ceil)    -> offset = 2^k - 1        (bumps up on any resto)
    //     half away      -> offset = 2^(k-1)    if x >= 0
    //                             = 2^(k-1) - 1 if x <  0
    //     half up        -> offset = 2^(k-1)    (always)
    //------------------------------------------------------------------
    generate
        if (P_NB_TO_RND == 0) begin : g_no_rnd
            // Nothing to drop: straight pass-through.
            assign rnd_val = din_r;
        end else begin : g_rnd
            localparam int K = P_NB_TO_RND;
 
            logic signed [P_NB_IN:0] din_ext;  // input extended by 1 guard bit
            logic signed [P_NB_IN:0] offset;   // rounding offset (always >= 0)
            logic signed [P_NB_IN:0] sum;      // din_ext + offset
 
            assign din_ext = din_r;            // automatic sign extension
 
            always_comb begin
                offset = '0;
                unique case (P_MODE)
                    // round toward +inf
                    1: offset[K-1:0] = '1;                  // 2^k - 1
                    // round half away from zero
                    2: if (din_r[P_NB_IN-1]) begin           // negative
                           if (K >= 2) offset[K-2:0] = '1;   //   2^(k-1) - 1
                       end else begin                        // non-negative
                           offset[K-1] = 1'b1;               //   2^(k-1)
                       end
                    // round half up (ties toward +inf)
                    3: offset[K-1] = 1'b1;                   // 2^(k-1)
                    // round toward -inf (floor)
                    default: offset = '0;
                endcase
            end
 
            assign sum     = din_ext + offset;
            assign rnd_val = sum[P_NB_IN:K];   // truncation = floor
        end
    endgenerate
 
    //------------------------------------------------------------------
    // 3) Saturation stage
    //
    //  If the rounded value does not fit in P_NB_OUT bits it is clamped
    //  to the max/min representable value. If the output is as wide as
    //  or wider than the rounded value, no clipping is possible (only
    //  sign extension).
    //------------------------------------------------------------------
    generate
        if (P_NB_OUT >= NB_RND) begin : g_sext
            assign sat_val = rnd_val;   // sign extension, no saturation
        end else begin : g_sat
            logic in_range;
 
            // In range if every bit above the output MSB matches the sign
            // (all 0s or all 1s).
            assign in_range = (&rnd_val[NB_RND-1:P_NB_OUT-1]) |
                              (~|rnd_val[NB_RND-1:P_NB_OUT-1]);
 
            assign sat_val = in_range
                           ? rnd_val[P_NB_OUT-1:0]
                           : {rnd_val[NB_RND-1], {(P_NB_OUT-1){~rnd_val[NB_RND-1]}}};
        end
    endgenerate
 
    //------------------------------------------------------------------
    // 4) Output stage
    //------------------------------------------------------------------
    generate
        if (P_PST_FF == 1) begin : g_pst_ff
            always_ff @(posedge clk)
                dout_r <= sat_val;
        end else begin : g_pst_comb
            assign dout_r = sat_val;
        end
    endgenerate
 
    assign o_dout = dout_r;
 
endmodule