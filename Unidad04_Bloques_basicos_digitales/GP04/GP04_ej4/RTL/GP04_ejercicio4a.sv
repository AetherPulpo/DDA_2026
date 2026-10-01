// =============================================================================
// Ejercicio 4 - Entregar / Desarrollar.
// Considerar los siguientes coeficientes de un filtro FIR:
// h[n] = [−0,0456 −0,1703 0,0696 0,3094 0,4521 0,3094 0,0696 −0,1703 −0,0456] (1)
// Convertir los coeficientes a formato S(16.15). Considerar x[n] como un n ́umero de S(8.7).
// Dise ̃nar e implementar la arquitectura del filtro basado en aritm ́etica distribuida en verilog
// considerando:
// 1) Un dise ̃no utilizando una ROM.
// =============================================================================


module ejercicio4a #(
    parameter NB_IN         = 8,        //x[n] S(8.7) format
    parameter NBF_IN        = 7,        //x[n] S(8.7) format
    parameter NB_OUT        = NB_IN,    // y[n] S(8.7) format
    parameter NBF_OUT       = NBF_IN    // y[n] S(8.7) format  
) (
    //OUTPUT PORTS
    output logic signed [NB_OUT - 1 : 0] o_data,
    //INPUT PORTS
    input  logic signed [NB_IN  - 1 : 0] i_data,
    //CTRL PORTS
    input  logic                         i_rst_n,
    input  logic                         i_clk
);

    // h[0] = -0.0456000  ->  bin = 1111101000101010   hex = 0xFA2A   quantized = -0.0455933   (rep S(16,15))
    // h[1] = -0.1703000  ->  bin = 1110101000110100   hex = 0xEA34   quantized = -0.1702881   (rep S(16,15))
    // h[2] =  0.0696000  ->  bin = 0000100011101001   hex = 0x08E9   quantized = 0.0696106   (rep S(16,15))
    // h[3] =  0.3094000  ->  bin = 0010011110011010   hex = 0x279A   quantized = 0.3093872   (rep S(16,15))
    // h[4] =  0.4521000  ->  bin = 0011100111011110   hex = 0x39DE   quantized = 0.4520874   (rep S(16,15))
    // h[5] =  0.3094000  ->  bin = 0010011110011010   hex = 0x279A   quantized = 0.3093872   (rep S(16,15))
    // h[6] =  0.0696000  ->  bin = 0000100011101001   hex = 0x08E9   quantized = 0.0696106   (rep S(16,15))
    // h[7] = -0.1703000  ->  bin = 1110101000110100   hex = 0xEA34   quantized = -0.1702881   (rep S(16,15))
    // h[8] = -0.0456000  ->  bin = 1111101000101010   hex = 0xFA2A   quantized = -0.0455933   (rep S(16,15))

    // LOCALPARAMETERS
    localparam N_COEFF    = 9;
    localparam NB_COEFF   = 16;
    localparam NBF_COEFF  = 15;
    localparam NB_PP      = NB_COEFF + 1;              // 17, S(17,15) (igual que rom_fir_full)
    localparam DELTA_FRAC = NBF_COEFF - NBF_OUT;        // 15 - 7 = 8 bits a descartar al reescalar
    localparam RND_MODE   = 2;                          // 2: round half away from zero
 
    // SIGNALS
    logic signed [NB_IN - 1 : 0] x_buf;                 // buffer estable de la muestra actual
    logic signed [NB_IN - 1 : 0] sr_q [N_COEFF - 1 : 0]; // cadena de shift registers (posta continua)
    logic        [$clog2(NB_IN) - 1 : 0] bit_counter;   //Contador de bit
    logic        [N_COEFF - 1 : 0] address;
    logic signed [NB_PP  - 1 : 0] partial_product;
    logic signed [NB_PP  - 1 : 0] accumulator;
    logic signed [NB_OUT - 1 : 0] rounded_out;   // salida de rnd: S(17,15) -> S(8,7) redondeado y saturado
    logic signed [NB_OUT -1  : 0] rounded_out_q;

    // Buffer estable: se carga cuando el ciclo actual es el ultimo del grupo
    // (bit_counter == NB_IN-1), asi la muestra nueva ya esta lista para el
    // proximo ciclo (bit_counter == 0, que lee el bit 0 via indice directo).
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            x_buf <= '0;
        end else if (bit_counter == NB_IN - 1) begin
            x_buf <= i_data;
        end
    end
 
    // Contador de bit (0 .. NB_IN-1, LSB -> MSB)
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            bit_counter <= '0;
        end else begin
            bit_counter <= (bit_counter == NB_IN - 1) ? '0 : bit_counter + 1'b1;
        end
    end
 
    // Cadena de shift registers: sr_q[0] se alimenta por indice directo desde
    // x_buf (nunca se gasta); sr_q[i>=1] recibe el bit que sale de sr_q[i-1]
    // en el MISMO flanco (continuo, no copia al final del grupo).
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (int i = 0; i < N_COEFF; i++) begin
                sr_q[i] <= '0;
            end
        end else begin
            sr_q[0] <= {x_buf[bit_counter], sr_q[0][NB_IN-1:1]};
            for (int i = 1; i < N_COEFF; i++) begin
                sr_q[i] <= {sr_q[i-1][0], sr_q[i][NB_IN-1:1]};
            end
        end
    end
 
    // Direccion: LSB de cada sr_q. address[i] corresponde al sr_q k=i (mismo
    // orden que espera rom_fir_full).
    always_comb begin
        for (int i = 0; i < N_COEFF; i++) begin
            address[i] = sr_q[i][0];
        end
    end
 
    rom_fir_full u_rom_fir_full (
        .addr (address),
        .data (partial_product)
    );
 
    // Reescala S(17,15) -> S(8,7): descarta DELTA_FRAC=8 bits con redondeo
    // real y satura si el acumulador se pasa del rango de salida.
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
 
    // Acumulador bit-serie: mapeo bit_counter <-> posicion de bit, sin desfasaje.
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            accumulator   <= '0;
            rounded_out_q <= '0;
        end else begin
            case (bit_counter)
                '0 : begin
                    rounded_out_q      <= rounded_out;          // resultado redondeado/saturado del grupo anterior
                    accumulator <= partial_product;      // primer termino (bit 0), sin shift
                end
                NB_IN - 1 : begin
                    accumulator <= (accumulator >>> 1) - partial_product; // bit de signo: resta
                end
                default : begin
                    accumulator <= (accumulator >>> 1) + partial_product; // bits de magnitud
                end
            endcase
        end
    end
    
    assign o_data = rounded_out_q;
endmodule