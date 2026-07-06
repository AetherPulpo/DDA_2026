`timescale 1ns/1ps
 
module tb_ejercicio4;
 
    // ---- filter parameters -------------------------------------------
    localparam int P_NB_IN     = 16;
    localparam int P_NBF_IN    = 15;
    localparam int P_NB_COEFF  = 16;
    localparam int P_NBF_COEFF = 15;
    localparam int P_NUM_COEFF = 4;
    localparam int N_MODES     = 4;    // rnd.sv modes 0..3
 
    // Output widths (must match each module's default P_NB_OUT).
    localparam int P_NB_OUT_AB = 18 + $clog2(P_NUM_COEFF);     // 20 -> S(20,16)
    localparam int P_NB_OUT_CD = 18 + $clog2(P_NUM_COEFF/2);   // 19 -> S(19,16)
    localparam int P_NBF_OUT   = 16;   // both outputs keep 16 fractional bits
 
    // ---- helpers -----------------------------------------------------
    function automatic real to_real(input longint signed v, input int frac);
        return real'(v) / (2.0 ** frac);
    endfunction
 
    function automatic longint signed to_fix(input real v, input int frac);
        return longint'($rtoi(v * (2.0 ** frac)));
    endfunction
 
    // ---- clock -------------------------------------------------------
    logic clk = 1'b0;
    always #5 clk = ~clk;   // 100 MHz
 
    // ---- stimulus signals --------------------------------------------
    logic signed [P_NB_IN-1:0] x;
    logic signed [P_NB_IN-1:0] h [P_NUM_COEFF-1:0];
 
    // ---- DUT outputs (one per mode) ----------------------------------
    wire signed [P_NB_OUT_AB-1:0] y_ab [N_MODES-1:0];
    wire signed [P_NB_OUT_CD-1:0] y_cd [N_MODES-1:0];
 
    // ---- instantiate both architectures for every rounding mode ------
    genvar m;
    generate
        for (m = 0; m < N_MODES; m++) begin : g_dut
            ejercicio4_ab #(
                .P_NB_IN     (P_NB_IN),
                .P_NBF_IN    (P_NBF_IN),
                .P_NB_COEFF  (P_NB_COEFF),
                .P_NBF_COEFF (P_NBF_COEFF),
                .P_NUM_COEFF (P_NUM_COEFF),
                .P_MODE      (m)
            ) u_ab (
                .y   (y_ab[m]),
                .x   (x),
                .h   (h),
                .clk (clk)
            );
 
            ejercicio4_cd #(
                .P_NB_IN     (P_NB_IN),
                .P_NBF_IN    (P_NBF_IN),
                .P_NB_COEFF  (P_NB_COEFF),
                .P_NBF_COEFF (P_NBF_COEFF),
                .P_NUM_COEFF (P_NUM_COEFF),
                .P_MODE      (m)
            ) u_cd (
                .y   (y_cd[m]),
                .x   (x),
                .h   (h),
                .clk (clk)
            );
        end
    endgenerate
 
    // ---- test vectors ------------------------------------------------
    localparam int NSAMP = 12;
    // Input samples in S(16,15) range [-1, 1), mixing signs and
    // non-round values so the dropped LSBs are rich.
    real stim_r [0:NSAMP-1] = '{
         0.500,  -0.300,   0.800,  -0.900,   0.100,   0.250,
        -0.700,   0.600,  -0.150,   0.333,  -0.050,   0.999
    };
    // Symmetric coefficients (h0=h3, h1=h2), sum = 1.0 -> unity DC gain.
    real h_r [0:P_NUM_COEFF-1] = '{0.15, 0.35, 0.35, 0.15};
 
    logic signed [P_NB_IN-1:0] x_fix [0:NSAMP-1];
 
    string mode_name [0:3] = '{"floor(-inf)", "ceil (+inf)", "half-away ", "half-up   "};
 
    // ---- full-precision reference for sample k -----------------------
    function automatic real ideal_at(input int k);
        real acc;
        acc = 0.0;
        for (int i = 0; i < P_NUM_COEFF; i++) begin
            real xi;
            xi  = (k - i >= 0) ? to_real(x_fix[k-i], P_NBF_IN) : 0.0;
            acc += to_real(h[i], P_NBF_COEFF) * xi;
        end
        return acc;
    endfunction
 
    // ---- stimulus + logging ------------------------------------------
    initial begin
        $dumpfile("tb_ejercicio4.vcd");
        $dumpvars(0, tb_ejercicio4);
 
        // load coefficients (symmetric) and quantize the stimulus
        for (int i = 0; i < P_NUM_COEFF; i++) h[i]     = to_fix(h_r[i],  P_NBF_COEFF);
        for (int k = 0; k < NSAMP;       k++) x_fix[k] = to_fix(stim_r[k], P_NBF_IN);
 
        $display("");
        $display("Coefficients S(16,15): h0=%f  h1=%f  h2=%f  h3=%f",
                 to_real(h[0],15), to_real(h[1],15), to_real(h[2],15), to_real(h[3],15));
        $display("Direct form  -> y[n] = S(%0d,16)", P_NB_OUT_AB);
        $display("Folded form  -> y[n] = S(%0d,16)", P_NB_OUT_CD);
        $display("");
 
        // flush the delay line with zeros (no reset in the DUTs)
        x <= '0;
        repeat (P_NUM_COEFF) @(posedge clk);
 
        // drive one sample per cycle; after the edge x holds x_fix[k] and
        // x_q holds the previous samples, so taps = x_fix[k..k-3]
        for (int k = 0; k < NSAMP; k++) begin
            @(posedge clk);
            x <= x_fix[k];
            #1;   // let the combinational path settle
 
            $display("--------------------------------------------------------------------");
            $display(" sample %0d | x[n] = %f | ideal (full precision) = %f",
                     k, to_real(x_fix[k],15), ideal_at(k));
            $display("   direct  |  %s = %f   %s = %f   %s = %f   %s = %f",
                     mode_name[0], to_real(y_ab[0], P_NBF_OUT),
                     mode_name[1], to_real(y_ab[1], P_NBF_OUT),
                     mode_name[2], to_real(y_ab[2], P_NBF_OUT),
                     mode_name[3], to_real(y_ab[3], P_NBF_OUT));
            $display("   folded  |  %s = %f   %s = %f   %s = %f   %s = %f",
                     mode_name[0], to_real(y_cd[0], P_NBF_OUT),
                     mode_name[1], to_real(y_cd[1], P_NBF_OUT),
                     mode_name[2], to_real(y_cd[2], P_NBF_OUT),
                     mode_name[3], to_real(y_cd[3], P_NBF_OUT));
        end
 
        $display("--------------------------------------------------------------------");
        $display(" Note: floor vs ceil differ on almost every sample (any dropped");
        $display("       remainder). half-away and half-up only differ on negative");
        $display("       exact-half ties, so they usually match round-to-nearest.");
        $display("");
        $finish;
    end
 
endmodule