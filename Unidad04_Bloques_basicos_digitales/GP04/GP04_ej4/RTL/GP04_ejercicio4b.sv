// =============================================================================
// ejercicio4b.sv
// Considerar los siguientes coeficientes de un filtro FIR:
// h[n] = [−0,0456 −0,1703 0,0696 0,3094 0,4521 0,3094 0,0696 −0,1703 −0,0456] (1)
// Convertir los coeficientes a formato S(16.15). Considerar x[n] como un n ́umero de S(8.7).
// Dise ̃nar e implementar la arquitectura del filtro basado en aritm ́etica distribuida en verilog
// considerando:
//2) Reducir el tama ̃no de la ROM utilizando la simetr ́ıa de los coeficientes
// =============================================================================

module ejercicio4b #(
    parameter NB_IN   = 8,       // x[n] S(8.7) formato
    parameter NBF_IN  = 7,       // x[n] S(8.7) formato
    parameter NB_OUT  = NB_IN,   // y[n] S(8.7) formato
    parameter NBF_OUT = NBF_IN   // y[n] S(8.7) formato
) (
    // OUTPUT PORTS
    output logic signed [NB_OUT - 1 : 0] o_data,
    // INPUT PORTS
    input  logic signed [NB_IN  - 1 : 0] i_data,
    // CTRL PORTS
    input  logic                         i_rst_n,
    input  logic                         i_clk
);

    // LOCALPARAMETERS
    localparam N_COEFF    = 9;                   // taps de la cadena
    localparam N_PAIRS    = 5;                    // C0..C4 -> direccion de rom_fir_reduced
    localparam NB_SUM     = NB_IN + 1;             // 9: ancho de cada tap ensanchado
    localparam NB_COEFF   = 16;
    localparam NBF_COEFF  = 15;
    localparam NB_PP      = NB_COEFF + 1;          // 17, S(17,15) (igual que rom_fir_reduced)
    localparam DELTA_FRAC = NBF_COEFF - NBF_OUT;   // 15 - 7 = 8 bits a descartar al reescalar
    localparam RND_MODE   = 2;                     // 2: round half away from zero

    // SIGNALS
    logic signed [NB_SUM - 1 : 0]         x_buf;                                  // muestra actual, sign-extendida a 9 bits
    logic signed [NB_SUM - 1 : 0]         sr_q [N_COEFF - 1 : 0];                  // cadena daisy de 9 shift registers, 9 bits c/u
    logic        [$clog2(NB_SUM) - 1 : 0] bit_counter;                            // 0 .. NB_SUM-1 = 0..8 (9 ciclos)
    logic                                 carry_c0, carry_c1, carry_c2, carry_c3; // acarreos de los 4 sumadores serie
    logic                                 addr_c0, addr_c1, addr_c2, addr_c3;     // bits de suma (direccion) de cada par
    logic        [N_PAIRS        - 1 : 0] address;
    logic signed [NB_PP          - 1 : 0] partial_product;
    logic signed [NB_PP          - 1 : 0] accumulator;
    logic signed [NB_OUT         - 1 : 0] rounded_out;
    logic signed [NB_OUT         - 1 : 0] rounded_out_q;

    // Buffer estable, sign-extendido a 9 bits: se carga cuando el ciclo
    // actual es el ultimo del grupo (bit_counter == NB_SUM-1).
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            x_buf <= '0;
        end else if (bit_counter == NB_SUM - 1) begin
            x_buf <= {i_data[NB_IN-1], i_data};   // extension de signo explicita
        end
    end

    // Contador de bit (0 .. NB_SUM-1 = 0..8)
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            bit_counter <= '0;
        end else begin
            bit_counter <= (bit_counter == NB_SUM - 1) ? '0 : bit_counter + 1'b1;
        end
    end

    // Cadena daisy de 9 sr_qs de NB_SUM=9 bits cada uno (identico patron que
    // ejercicio4a, solo que cada sr_q es 1 bit mas ancho, para poder correr
    // 9 ciclos en vez de 8).
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (int i = 0; i < N_COEFF; i++) begin
                sr_q[i] <= '0;
            end
        end else begin
            sr_q[0] <= {x_buf[bit_counter], sr_q[0][NB_SUM-1:1]};
            for (int i = 1; i < N_COEFF; i++) begin
                sr_q[i] <= {sr_q[i-1][0], sr_q[i][NB_SUM-1:1]};
            end
        end
    end

    // Sumadores serie con acarreo (full adder), uno por par simetrico.
    // El acarreo se resetea al arrancar cada grupo nuevo (bit_counter==0).
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n || bit_counter == NB_SUM - 1) begin
            carry_c0 <= 1'b0;
            carry_c1 <= 1'b0;
            carry_c2 <= 1'b0;
            carry_c3 <= 1'b0;
        end else begin
            carry_c0 <= (sr_q[0][0] & sr_q[8][0]) | (carry_c0 & (sr_q[0][0] ^ sr_q[8][0]));
            carry_c1 <= (sr_q[1][0] & sr_q[7][0]) | (carry_c1 & (sr_q[1][0] ^ sr_q[7][0]));
            carry_c2 <= (sr_q[2][0] & sr_q[6][0]) | (carry_c2 & (sr_q[2][0] ^ sr_q[6][0]));
            carry_c3 <= (sr_q[3][0] & sr_q[5][0]) | (carry_c3 & (sr_q[3][0] ^ sr_q[5][0]));
        end
    end

    // Direccion: bit de suma de cada par (mas el sr_q central sin sumador),
    // en el mismo orden que espera rom_fir_reduced (address[i] -> Ci).
    always_comb begin
        addr_c0 = sr_q[0][0] ^ sr_q[8][0] ^ carry_c0;   // C0: x[0]+x[-8]
        addr_c1 = sr_q[1][0] ^ sr_q[7][0] ^ carry_c1;   // C1: x[-1]+x[-7]
        addr_c2 = sr_q[2][0] ^ sr_q[6][0] ^ carry_c2;   // C2: x[-2]+x[-6]
        addr_c3 = sr_q[3][0] ^ sr_q[5][0] ^ carry_c3;   // C3: x[-3]+x[-5]
        address = {sr_q[4][0], addr_c3, addr_c2, addr_c1, addr_c0}; // C4,C3,C2,C1,C0
    end

    rom_fir_reduced u_rom_fir_reduced (
        .addr (address),
        .data (partial_product)
    );

    // Reescala S(17,15) -> S(8,7): identico a ejercicio4_reducida.sv.
    rnd #(
        .P_NB_IN     (NB_PP),
        .P_MODE      (RND_MODE),
        .P_NB_TO_RND (DELTA_FRAC),
        .P_NB_OUT    (NB_OUT),
        .P_PRE_FF    (0),
        .P_PST_FF    (0)
    ) u_rnd (
        .o_dout (rounded_out),
        .i_din  (accumulator),
        .clk    (i_clk)
    );

    // Acumulador bit-serie.:
    // el  ultimo paso (bit de signo) NO lleva shift, y la ROM se multiplica x2
    // antes de restar (porque ahora hay 2 bits enteros, no 1 -- ver notas
    // en ejercicio4_reducida.sv).
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            accumulator <= '0;
            rounded_out_q      <= '0;
        end else begin
            case (bit_counter)
                '0 : begin
                    rounded_out_q      <= rounded_out;
                    accumulator <= partial_product;
                end
                NB_SUM - 1 : begin
                    accumulator <= accumulator - (partial_product <<< 1);
                end
                default : begin
                    accumulator <= (accumulator >>> 1) + partial_product;
                end
            endcase
        end
    end
    assign o_data = rounded_out_q;
endmodule