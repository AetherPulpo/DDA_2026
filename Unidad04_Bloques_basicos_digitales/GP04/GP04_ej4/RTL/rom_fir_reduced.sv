// =============================================================================
// rom_fir_reduced.sv
// ROM combinacional para DA de un filtro FIR de 9 taps, APROVECHANDO LA
// SIMETRIA de los coeficientes (h[n] = h[8-n]).
//
// Cada par de muestras que comparte coeficiente se pre-suma AFUERA de esta
// ROM con un semisumador (bit suma = XOR, acarreo = AND). El acarreo de cada
// semisumador NO entra aca: se guarda en un registro de 1 bit y se suma en
// el ciclo siguiente (bit mas significativo) mediante un sumador serie
// dentro del acumulador shift-and-add del filtro. Sin ese sumador serie
// afuera, esta ROM por si sola NO es equivalente a rom_fir_full.
//
// Coeficientes cuantizados a S(16,15) con roundMode='round', unidades de 2^-15:
// C0=-1494  C1=-5580  C2=2281  C3=10138  C4=14814
//
// Direccion addr[4:0] = { s4, s3, s2, s1, s0 }
//   s4 = x[-4]
//   s3 = x[-3] XOR x[-5]     (pesa C3 = h[3] = h[5])
//   s2 = x[-2] XOR x[-6]     (pesa C2 = h[2] = h[6])
//   s1 = x[-1] XOR x[-7]     (pesa C1 = h[1] = h[7])
//   s0 = x[0]  XOR x[-8]     (pesa C0 = h[0] = h[8])
//
// Ancho de salida: S(17,15), igual que rom_fir_full, para poder conectar
// cualquiera de las dos ROMs al mismo acumulador sin ajustes
// (peor caso real: min=-7074, max=27233).
// =============================================================================

module rom_fir_reduced (
    input  logic [4:0]         addr,   // {s4,s3,s2,s1,s0}
    output logic signed [16:0] data
);

    always_comb begin
        case (addr)
            5'd0 : data = 17'sd0         ; // 0
            5'd1 : data = -17'sd1494     ; // C0
            5'd2 : data = -17'sd5580     ; // C1
            5'd3 : data = -17'sd7074     ; // C1+C0
            5'd4 : data = 17'sd2281      ; // C2
            5'd5 : data = 17'sd787       ; // C2+C0
            5'd6 : data = -17'sd3299     ; // C2+C1
            5'd7 : data = -17'sd4793     ; // C2+C1+C0
            5'd8 : data = 17'sd10138     ; // C3
            5'd9 : data = 17'sd8644      ; // C3+C0
            5'd10: data = 17'sd4558      ; // C3+C1
            5'd11: data = 17'sd3064      ; // C3+C1+C0
            5'd12: data = 17'sd12419     ; // C3+C2
            5'd13: data = 17'sd10925     ; // C3+C2+C0
            5'd14: data = 17'sd6839      ; // C3+C2+C1
            5'd15: data = 17'sd5345      ; // C3+C2+C1+C0
            5'd16: data = 17'sd14814     ; // C4
            5'd17: data = 17'sd13320     ; // C4+C0
            5'd18: data = 17'sd9234      ; // C4+C1
            5'd19: data = 17'sd7740      ; // C4+C1+C0
            5'd20: data = 17'sd17095     ; // C4+C2
            5'd21: data = 17'sd15601     ; // C4+C2+C0
            5'd22: data = 17'sd11515     ; // C4+C2+C1
            5'd23: data = 17'sd10021     ; // C4+C2+C1+C0
            5'd24: data = 17'sd24952     ; // C4+C3
            5'd25: data = 17'sd23458     ; // C4+C3+C0
            5'd26: data = 17'sd19372     ; // C4+C3+C1
            5'd27: data = 17'sd17878     ; // C4+C3+C1+C0
            5'd28: data = 17'sd27233     ; // C4+C3+C2
            5'd29: data = 17'sd25739     ; // C4+C3+C2+C0
            5'd30: data = 17'sd21653     ; // C4+C3+C2+C1
            5'd31: data = 17'sd20159     ; // C4+C3+C2+C1+C0
            default: data = 17'sd0;
        endcase
    end

endmodule
