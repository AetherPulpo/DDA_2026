module ejercicio1 #(
    parameter                             P_NB_INPUT   = 16,
    parameter                             P_NBF_INPUT  = 15,
    parameter                             P_NB_OUTPUT  = P_NB_INPUT, // S(16,15)
    parameter                             P_NBF_OUTPUT = P_NBF_INPUT,// S(16,15)
    parameter signed [P_NB_INPUT - 1 : 0] P_A1         = 16'sd0, // iir coeffs s(16,15)
    parameter signed [P_NB_INPUT - 1 : 0] P_A2         = 16'sd0, // iir coeffs s(16,15)
    parameter signed [P_NB_INPUT - 1 : 0] P_B0         = 16'sd0, // iir coeffs s(16,15)
    parameter signed [P_NB_INPUT - 1 : 0] P_B1         = 16'sd0, // iir coeffs s(16,15)
    parameter signed [P_NB_INPUT - 1 : 0] P_B2         = 16'sd0, // iir coeffs s(16,15)
    parameter signed [P_NB_INPUT - 1 : 0] P_KP         = 16'sd0, // kp constant s(16,15)
    parameter signed [P_NB_INPUT - 1 : 0] P_KI         = 16'sd0, // ki constant s(16,15)
    parameter signed [P_NB_INPUT - 1 : 0] P_SEED       = 16'sd0  // phase seed s(16,15)
) (
    //OUTPUT PORTS
    output logic signed [P_NB_OUTPUT - 1 : 0] o_phase,
    //INPUT PORTS
    input logic signed [P_NB_INPUT - 1 : 0] i_input_sample_re,
    input logic signed [P_NB_INPUT - 1 : 0] i_input_sample_im,
        //CTRL PORTS
    input logic i_rst_n,
    input logic i_clk
);
//LOCAL PARAMETERS
    //MIXER
localparam P_NB_MIXER  = P_NB_INPUT + P_NB_OUTPUT; //S(32,30) 16 + 16 = 32
localparam P_NBF_MIXER = P_NBF_INPUT + P_NBF_OUTPUT; // 15 + 15 = 30
localparam P_NB_MIXER_COEFF = (P_NB_MIXER + P_NB_INPUT) + $clog2(3); //S(50,45) 32 + 16 + 2 = 50
localparam P_NBF_MIXER_COEFF = P_NBF_MIXER + P_NBF_INPUT; // 30 + 15 = 45
    //IIR
localparam P_NB_DL = P_NB_MIXER_COEFF + P_NB_INPUT + $clog2(3); // S(68,60) 50 + 16 + 2 = 68
localparam P_NBF_DL = P_NBF_MIXER_COEFF + P_NBF_INPUT; // 45 + 15 = 60
    //OFFSET
localparam P_NB_OFFSET = 2*P_NB_DL + 1; // S(137, 120) 2*68 + 1 = 137
localparam P_NBF_OFFSET = 2*P_NBF_DL; // 2*60 = 120
    //Phase correction
localparam P_NB_PHASE_CORR = (P_NB_OFFSET + P_NB_INPUT) + $clog2(4);// S(155, 135) 137 + 16 + 2 = 155
localparam P_NBF_PHASE_CORR = P_NBF_OFFSET + P_NBF_INPUT; // 120 + 15 = 135
    //Phase
localparam P_NB_PHASE = P_NB_PHASE_CORR + 1; // S(156, 135) 155 + 1 = 156
localparam P_NBF_PHASE = P_NBF_PHASE_CORR; //135
    //Clipping
localparam int P_SHIFT = P_NBF_PHASE - P_NBF_OUTPUT;   // 135 - 15 = 120 (bits to be discarded)
// bias = 2^(P_SHIFT-1)
localparam signed [P_NB_PHASE-1:0] ROUND_BIAS =
        {{(P_NB_PHASE-P_SHIFT){1'b0}}, 1'b1, {(P_SHIFT-1){1'b0}}};

//SIGNAL DECLARATIONS
logic signed [P_NB_MIXER - 1 : 0] mixer_out_re;
logic signed [P_NB_MIXER - 1 : 0] mixer_out_im;
logic signed [P_NB_MIXER - 1 : 0] mixer_out_re_q [1:0];
logic signed [P_NB_MIXER - 1 : 0] mixer_out_im_q [1:0];
    //IIR FILTER SIGNALS
logic signed [P_NB_MIXER_COEFF - 1 : 0] mixer_times_coeff_re;
logic signed [P_NB_MIXER_COEFF - 1 : 0] mixer_times_coeff_im;
logic signed [P_NB_DL - 1 : 0] delay_line_re;
logic signed [P_NB_DL - 1 : 0] delay_line_im;
logic signed [P_NB_DL - 1 : 0] delay_line_re_q[2-1:0];
logic signed [P_NB_DL - 1 : 0] delay_line_im_q[2-1:0];
logic signed [P_NB_DL + P_NB_INPUT - 1 : 0] a1_dl_re, a2_dl_re, a1_dl_im, a2_dl_im; // 84 bits
    //OFFSET SIGNALS
logic signed [P_NB_OFFSET - 1 : 0] offset;
logic signed [P_NB_OFFSET - 1 : 0] offset_delay_line_q;
    //Phase correction signals
logic signed [P_NB_PHASE_CORR - 1 : 0] phase_corr;
logic signed [P_NB_PHASE_CORR - 1 : 0] phase_corr_q;
    //Phase
logic signed [P_NB_PHASE - 1 : 0]  phase;
logic signed [P_NB_PHASE - 1 : 0]  phase_q;
logic signed [P_NB_PHASE-1:0] phase_rnd;
logic signed [P_NB_OUTPUT - 1 : 0] phase_clipped;
logic signed [P_NB_INPUT - 1 : 0] minus_phase_clipped;

//complex mul = (a+bj) * (c+dj) = (ac-bd) + (ad+bc)j
//Since c=0 Then the equation becomes:
//(a+bj)*(0+dj) = (a*0-b*d) + (a*d+b*0)j = -bd + adj

assign mixer_out_re = -(i_input_sample_im * minus_phase_clipped);
assign mixer_out_im =  (i_input_sample_re * minus_phase_clipped);


//Flops for the mixer output
always_ff @(posedge i_clk or negedge i_rst_n) begin : mixer_re_ff
    if (!i_rst_n) begin
        mixer_out_re_q[0] <= '0;
        mixer_out_re_q[1] <= '0;
    end else begin
        mixer_out_re_q[0] <= mixer_out_re;
        mixer_out_re_q[1] <= mixer_out_re_q[0];
    end 
end

always_ff @(posedge i_clk or negedge i_rst_n) begin : mixer_im_ff
    if (!i_rst_n) begin
        mixer_out_im_q[0] <= '0;
        mixer_out_im_q[1] <= '0;
    end else begin
        mixer_out_im_q[0] <= mixer_out_im;
        mixer_out_im_q[1] <= mixer_out_im_q[0];
    end 
end

//IIR filter implementation
assign mixer_times_coeff_re = (mixer_out_re * P_B0)
                            + (mixer_out_re_q[0] * P_B1)
                            + (mixer_out_re_q[1] * P_B2);
assign mixer_times_coeff_im = (mixer_out_im * P_B0) 
                            + (mixer_out_im_q[0] * P_B1)
                            + (mixer_out_im_q[1] * P_B2);
//S(84,75)
assign a1_dl_re = delay_line_re_q[0] * P_A1;
assign a2_dl_re = delay_line_re_q[1] * P_A2;
assign a1_dl_im = delay_line_im_q[0] * P_A1;
assign a2_dl_im = delay_line_im_q[1] * P_A2;

assign delay_line_re = (mixer_times_coeff_re <<< 15)
                     - (a1_dl_re >>> 15) - (a2_dl_re >>> 15);
assign delay_line_im = (mixer_times_coeff_im <<< 15)
                     - (a1_dl_im >>> 15) - (a2_dl_im >>> 15);

//Flops for the delay line output
always_ff @(posedge i_clk or negedge i_rst_n) begin : delay_line_re_ff
    if (!i_rst_n) begin
        delay_line_re_q[0] <= '0;
        delay_line_re_q[1] <= '0;
    end else begin
        delay_line_re_q[0] <= delay_line_re;
        delay_line_re_q[1] <= delay_line_re_q[0];
    end 
end

always_ff @(posedge i_clk or negedge i_rst_n) begin : delay_line_im_ff
    if (!i_rst_n) begin
        delay_line_im_q[0] <= '0;
        delay_line_im_q[1] <= '0;
    end else begin
        delay_line_im_q[0] <= delay_line_im;
        delay_line_im_q[1] <= delay_line_im_q[0];
    end 
end

//Offset implementation
    //Real((a+bj)*(c+dj)) = ac-bd
assign offset = (delay_line_re_q[1] * delay_line_re)
              - (delay_line_im_q[1] * delay_line_im);

//Flop for the offset output
always_ff @(posedge i_clk or negedge i_rst_n) begin : offset_ff
    if (!i_rst_n) offset_delay_line_q <= '0;
    else          offset_delay_line_q <= offset; 
end

//Phase correction implementation
assign phase_corr = (P_KP * offset_delay_line_q)
                  + (P_KI * offset)
                  + phase_corr_q
                  - (P_KP * offset);

//Flop for the phase correction output
always_ff @(posedge i_clk or negedge i_rst_n) begin : phase_corr_ff
    if (!i_rst_n) phase_corr_q <= '0;
    else          phase_corr_q <= phase_corr;
end

//Phase accumulation
assign phase = phase_corr + phase_q;

//Flop for the phase output
always_ff @(posedge i_clk or negedge i_rst_n) begin : phase_ff
    if (!i_rst_n) phase_q <= $signed(P_SEED) <<< (P_NBF_PHASE - P_NBF_OUTPUT);
    else          phase_q <= phase;
end

//NOTE: exercise states Overflow and rounding.
//Rounding and Clipping the phase output to S(16,15) from S(156,135)
always_comb begin
    phase_rnd = phase_q[P_NB_PHASE-1] ? (phase_q + ROUND_BIAS - 1)   // negative
                                      : (phase_q + ROUND_BIAS);      // positive
    // overflow
    phase_clipped = $signed(phase_rnd[P_NBF_PHASE - P_NBF_OUTPUT +: P_NB_OUTPUT]);// bits [135 +: 16] -> S(16,15)
end

assign minus_phase_clipped = -phase_clipped;

//OUTPUT ASSIGNMENTS
assign o_phase = phase_clipped;

endmodule