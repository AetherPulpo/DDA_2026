`timescale 1ns/1ps
//==============================================================================
// GP04_ejercico4_tb.sv
//
// Testbench para comparar dos arquitecturas del filtro FIR por Aritmetica
// Distribuida (mismo filtro, mismos coeficientes):
//   ejercicio4a -> ROM completa  (rom_fir_full,    512 entradas, 8 ciclos/muestra)
//   ejercicio4b -> ROM reducida  (rom_fir_reduced,  32 entradas, 9 ciclos/muestra)
//
// Estrategia de verificacion:
//   1) Cada DUT tiene su PROPIA senial de entrada (x_in_a, x_in_b), cambiada
//      exactamente al ritmo NATIVO de ese DUT: 8 ciclos para ejercicio4a,
//      9 para ejercicio4b. Compartir una sola x_in con un tiempo de espera
//      fijo (version anterior de este testbench) hacia que cada DUT viera
//      la MISMA muestra repetida 2 o 3 veces (25 no es multiplo de 8 ni 9),
//      lo que arruinaba la comparacion contra el golden.
//   2) Se captura o_data una vez por grupo (siempre en el mismo punto,
//      justo al terminar cada GROUP_A/GROUP_B ciclos), no por deteccion de
//      cambio de valor -- eso se probo antes y se comia repeticiones
//      legitimas (misma salida dos ciclos de muestra seguidos).
//   3) Al terminar, se busca el corrimiento que mejor alinea esa cola contra
//      los valores golden[] (precalculados en Python con un modelo bit-exacto
//      del mismo algoritmo: mismos coeficientes S(16,15) redondeados, mismo
//      shift-and-add, mismo reescalado S(17,15)->S(8,7)).
//   4) Se compara tambien la cola de A contra la de B directamente entre si
//      (deben coincidir, sea cual sea el resultado contra golden).
//==============================================================================

module GP04_ejercico4_tb;

    localparam int NB_IN      = 8;
    localparam int NBF_IN     = 7;
    localparam int NB_OUT     = NB_IN;
    localparam int NBF_OUT    = NBF_IN;
    localparam int CLK_PERIOD = 10;   // ns
    localparam int GROUP_A    = NB_IN;      // 8 ciclos/muestra en ejercicio4a
    localparam int GROUP_B    = NB_IN + 1;  // 9 ciclos/muestra en ejercicio4b
    localparam int DRAIN_CYCLES = 40; // ciclos extra al final para que drenen ambos DUT
    localparam int N_VEC = 20;

    logic clk;
    logic rst_n;
    logic signed [NB_IN-1:0] x_in_a;
    logic signed [NB_IN-1:0] x_in_b;

    logic signed [NB_OUT-1:0] y_a;
    logic signed [NB_OUT-1:0] y_b;

    //--------------------------------------------------------------------
    // DUTs: mismo reloj/reset, pero cada uno con su propia entrada, para
    // poder alimentarlos al ritmo que cada uno necesita.
    //--------------------------------------------------------------------
    ejercicio4a #(
        .NB_IN   (NB_IN),
        .NBF_IN  (NBF_IN),
        .NB_OUT  (NB_OUT),
        .NBF_OUT (NBF_OUT)
    ) u_dut_a (
        .o_data  (y_a),
        .i_data  (x_in_a),
        .i_rst_n (rst_n),
        .i_clk   (clk)
    );

    ejercicio4b #(
        .NB_IN   (NB_IN),
        .NBF_IN  (NBF_IN),
        .NB_OUT  (NB_OUT),
        .NBF_OUT (NBF_OUT)
    ) u_dut_b (
        .o_data  (y_b),
        .i_data  (x_in_b),
        .i_rst_n (rst_n),
        .i_clk   (clk)
    );

    //--------------------------------------------------------------------
    // Reloj
    //--------------------------------------------------------------------
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    //--------------------------------------------------------------------
    // Vector de estimulo: casos borde (0, maximo positivo/negativo,
    // impulso) mas algunos valores "normales", todo en S(8,7).
    //--------------------------------------------------------------------
    int x_test[N_VEC] = '{
        0, 127, -128, 1, -1, 64, -64, 0, 0, 0,
        100, -100, 50, -50, 32, -32, 10, -10, 20, -20
    };

    // Valores esperados (golden), en S(8,7), calculados con un modelo
    // bit-exacto en Python que replica exactamente el algoritmo de ambos
    // modulos (deberian coincidir entre si, sean cuales sean).
    int golden[$] = '{
        0, 0, -6, -16, 31, 30, 15, -26, -15, -15,
        25, -8, -28, 6, 26, 28, -6, -10, -25, 7
    };

    //--------------------------------------------------------------------
    // Funcion auxiliar: busca el corrimiento (offset) dentro de 'got' que
    // mejor matchea contra 'exp', y devuelve la cantidad de mismatches en
    // el mejor caso encontrado (0 = coincide exacto).
    //--------------------------------------------------------------------
    function automatic int best_match_mismatches(input int got[$], input int exp[$], output int best_offset);
        int max_offset;
        int mism, best_mism;
        best_mism = exp.size() + 1;
        best_offset = -1;
        if (got.size() < exp.size()) begin
            best_offset = -1;
            return exp.size(); // ni siquiera hay suficientes muestras
        end
        max_offset = got.size() - exp.size();
        for (int off = 0; off <= max_offset; off++) begin
            mism = 0;
            for (int n = 0; n < exp.size(); n++) begin
                if (got[off+n] !== exp[n]) mism++;
            end
            if (mism < best_mism) begin
                best_mism = mism;
                best_offset = off;
            end
        end
        return best_mism;
    endfunction

    //--------------------------------------------------------------------
    // Generacion de estimulo: un proceso de reset, y uno por cada DUT
    // corriendo en paralelo, cada uno a su propio ritmo nativo.
    //--------------------------------------------------------------------
    initial begin  // reset
        rst_n   = 1'b0;
        x_in_a  = '0;
        x_in_b  = '0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
    end

    //--------------------------------------------------------------------
    // Generacion de estimulo Y captura de resultados, todo en el mismo
    // proceso por DUT: se captura o_data una vez por grupo, SIEMPRE en el
    // mismo punto (justo al terminar de sostener cada muestra).
    //
    // Se agregan EXTRA_FLUSH capturas de mas al final (sosteniendo la
    // ultima muestra), para darle margen a la busqueda de offset contra
    // golden ante la latencia de 1 muestra que tiene esta arquitectura
    // (igual que se hizo en el modelo de referencia en Python).
    //--------------------------------------------------------------------
    localparam int EXTRA_FLUSH = 3;

    int queue_a[$];
    int queue_b[$];

    initial begin  // estimulo + captura para ejercicio4a (grupos de GROUP_A=8 ciclos)
        @(posedge rst_n);
        for (int k = 0; k < N_VEC; k++) begin
            x_in_a = x_test[k][NB_IN-1:0];
            repeat (GROUP_A) @(posedge clk);
            queue_a.push_back(int'(y_a));
        end
        for (int k = 0; k < EXTRA_FLUSH; k++) begin
            repeat (GROUP_A) @(posedge clk);
            queue_a.push_back(int'(y_a));
        end
    end

    initial begin  // estimulo + captura para ejercicio4b (grupos de GROUP_B=9 ciclos)
        @(posedge rst_n);
        for (int k = 0; k < N_VEC; k++) begin
            x_in_b = x_test[k][NB_IN-1:0];
            repeat (GROUP_B) @(posedge clk);
            queue_b.push_back(int'(y_b));
        end
        for (int k = 0; k < EXTRA_FLUSH; k++) begin
            repeat (GROUP_B) @(posedge clk);
            queue_b.push_back(int'(y_b));
        end
    end

    //--------------------------------------------------------------------
    // Control principal: espera tiempo de sobra (el mas largo de los dos
    // estimulos, mas drenaje) y despues compara.
    //--------------------------------------------------------------------
    int mism_a, mism_b, mism_ab;
    int off_a, off_b, off_ab;
    bit pass_a, pass_b, pass_ab;

    initial begin
        @(posedge rst_n);
        repeat (N_VEC * GROUP_B + DRAIN_CYCLES) @(posedge clk);

        $display("--------------------------------------------------------");
        $display("queue_a.size() = %0d   queue_b.size() = %0d   golden.size() = %0d",
                  queue_a.size(), queue_b.size(), golden.size());

        $write("golden  = [");
        foreach (golden[i]) $write("%0d ", golden[i]);
        $display("]");

        $write("queue_a = [");
        foreach (queue_a[i]) $write("%0d ", queue_a[i]);
        $display("]");

        $write("queue_b = [");
        foreach (queue_b[i]) $write("%0d ", queue_b[i]);
        $display("]");
        $display("--------------------------------------------------------");

        // ejercicio4a (ROM completa) vs golden
        mism_a = best_match_mismatches(queue_a, golden, off_a);
        pass_a = (mism_a == 0);
        $display("[ejercicio4a vs golden] offset=%0d  mismatches=%0d  %s",
                  off_a, mism_a, pass_a ? "PASS" : "FAIL");

        // ejercicio4b (ROM reducida) vs golden
        mism_b = best_match_mismatches(queue_b, golden, off_b);
        pass_b = (mism_b == 0);
        $display("[ejercicio4b vs golden] offset=%0d  mismatches=%0d  %s",
                  off_b, mism_b, pass_b ? "PASS" : "FAIL");

        // ejercicio4a vs ejercicio4b directamente (deben coincidir entre si)
        if (queue_a.size() <= queue_b.size())
            mism_ab = best_match_mismatches(queue_b, queue_a, off_ab);
        else
            mism_ab = best_match_mismatches(queue_a, queue_b, off_ab);
        pass_ab = (mism_ab == 0);
        $display("[ejercicio4a vs ejercicio4b] offset=%0d  mismatches=%0d  %s",
                  off_ab, mism_ab, pass_ab ? "PASS" : "FAIL");

        $display("--------------------------------------------------------");
        if (pass_a && pass_b && pass_ab)
            $display(">>> RESULTADO GENERAL: PASS (las dos arquitecturas coinciden entre si y con el golden)");
        else
            $display(">>> RESULTADO GENERAL: FAIL -- revisar detalle arriba");
        $display("--------------------------------------------------------");

        $finish;
    end

endmodule