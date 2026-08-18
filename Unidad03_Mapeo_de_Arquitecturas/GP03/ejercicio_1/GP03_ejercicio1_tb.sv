// =====================================================================
//  tb_ejercicio1.sv  -- punto (d): estimulos para verificar el modulo
//
//  Verificacion = equivalencia RTL vs golden (golden_model.py), NO convergencia
//  (la convergencia depende de los coeficientes reales, que no se dan).
//
//  Requisitos en el DUT: los 3 fixes (mixer branchless, producto a*dl en 84 bits,
//  phase_clipped derivado de phase_q) y el parametro P_SEED.
//
//  Flujo:
//    1) python3 golden_model.py                 -> trayectoria esperada
//    2) tb_ejercicio1.sv ejercicio1.sv          -> o_phase.txt
//    3) python3 golden_model.py o_phase.txt     -> PASS/FAIL vs golden
// =====================================================================
`timescale 1ns/1ps
module tb_ejercicio1;

    localparam int  NB  = 16;
    localparam real ONE = 32768.0;

    logic                 clk = 0, rst_n = 0;
    logic signed [NB-1:0] in_re, in_im;
    logic signed [NB-1:0] o_phase;

    function automatic signed [NB-1:0] to_q15(input real x);
        real q;
        begin
            if      (x >=  1.0 - 1.0/ONE) to_q15 =  16'sh7FFF;
            else if (x <= -1.0)           to_q15 = -16'sh8000;
            else begin q = x*ONE; to_q15 = $rtoi(q >= 0.0 ? q+0.5 : q-0.5); end
        end
    endfunction

    // Estimulo: debe coincidir con golden_model.py
    localparam int  N_SAMPLES = 400;
    localparam real THETA     = 0.30;
    localparam real AMP       = 0.70;
    localparam real SEED      = 0.20;   // == SEED_PHASE del golden

    // coeficientes de ejemplo en S(16,15); reemplazar por los reales
    ejercicio1 #(
        .P_B0(to_q15(0.10)), .P_B1(to_q15(0.20)), .P_B2(to_q15(0.10)),
        .P_A1(to_q15(-0.30)), .P_A2(to_q15(0.10)),
        .P_KP(to_q15(0.05)),  .P_KI(to_q15(0.005)),
        .P_SEED(to_q15(SEED))          // <-- siembra la fase
    ) dut (
        .o_phase           (o_phase),
        .i_input_sample_re (in_re),
        .i_input_sample_im (in_im),
        .i_rst_n           (rst_n),
        .i_clk             (clk)
    );

    always #5 clk = ~clk;

    int fd, k;
    initial begin
        $dumpfile("ejercicio1.vcd");
        $dumpvars(0, tb_ejercicio1);
        fd = $fopen("o_phase.txt", "w");

        in_re = 0; in_im = 0; rst_n = 0;
        repeat (4) @(negedge clk);
        rst_n = 1;                                // aqui phase_q sale = SEED

        for (k = 0; k < N_SAMPLES; k++) begin
            in_re = to_q15(AMP*$cos(THETA));
            in_im = to_q15(AMP*$sin(THETA));
            @(negedge clk);
            $fdisplay(fd, "%0d", o_phase);
            if (k % 20 == 0)
                $display("n=%0d  o_phase=%0d  (%.5f)", k, o_phase, $itor(o_phase)/ONE);
        end
        $fclose(fd);
        $display("--- listo: corre  python3 golden_model.py o_phase.txt  para el PASS/FAIL ---");
        $finish;
    end
endmodule
