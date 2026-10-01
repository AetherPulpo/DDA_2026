"""
golden_model.py

Genera la secuencia de salida esperada ("golden") de un filtro FIR de 9
taps implementado por Aritmetica Distribuida, para despues usarla como
referencia en un testbench de SystemVerilog (GP04_ejercico4_tb.sv).

Orden de trabajo: primero se corre ESTE script; su salida (x_test[] y
golden[]) se copia tal cual al testbench de SystemVerilog.

Pasos que reproduce, identicos a lo que hace el RTL:
    1) Cuantiza los coeficientes h[n] a S(16,15) (redondeo half-away-from-
       zero, la misma convencion que arrayFixedInt con roundMode='round').
    2) Corre el filtro FIR bit-serie (LSB->MSB, resta en el bit de signo) --
       misma arquitectura que se implementa despues en ejercicio4a.sv /
       ejercicio4b.sv.
    3) Reescala el resultado de S(17,15) a S(8,7), igual que hace el modulo
       rnd.sv con P_MODE=2 (round half away from zero, con saturacion).

Correr con: python3 golden_model.py
"""

import math

# ---------------------------------------------------------------------------
# 1) Coeficientes del filtro y cuantizacion a S(16,15)
# ---------------------------------------------------------------------------
H_FLOAT = [-0.0456, -0.1703, 0.0696, 0.3094, 0.4521,
            0.3094, 0.0696, -0.1703, -0.0456]

NBF_COEFF = 15                 # bits fraccionarios de los coeficientes: S(16,15)
SCALE_COEFF = 2 ** NBF_COEFF


def quantize_round(x, scale):
    """Redondeo half-away-from-zero a entero, en unidades de 1/scale."""
    return math.floor(x * scale + 0.5) if x >= 0 else math.ceil(x * scale - 0.5)


H_Q = [quantize_round(h, SCALE_COEFF) for h in H_FLOAT]

N_COEFF = len(H_Q)   # 9
NB_IN   = 8           # x[n] en S(8,7)
NBF_IN  = 7
NB_OUT  = NB_IN       # y[n] en S(8,7)
NBF_OUT = NBF_IN
NB_PP   = 17          # ancho de la ROM / acumulador: S(17,15)

print("Coeficientes h[n] cuantizados a S(16,15):", H_Q)


# ---------------------------------------------------------------------------
# 2) ROM de aritmetica distribuida: suma de coeficientes segun los bits
#    activos de la direccion (misma tabla que despues se vuelca en
#    rom_fir_full.sv)
# ---------------------------------------------------------------------------
def rom_fir_full(addr9):
    """addr9: entero 0..511. El bit k de la direccion corresponde a h[k]."""
    return sum(H_Q[k] for k in range(N_COEFF) if (addr9 >> k) & 1)


def to_signed(value, bits):
    """Reinterpreta 'value' como entero con signo de 'bits' bits (C2)."""
    value &= (1 << bits) - 1
    if value >= 1 << (bits - 1):
        value -= 1 << bits
    return value


# ---------------------------------------------------------------------------
# 3) Reescalado S(17,15) -> S(8,7): redondeo half-away-from-zero + saturacion
#    (misma formula que despues implementa el modulo rnd.sv con P_MODE=2)
# ---------------------------------------------------------------------------
DELTA_FRAC = NBF_COEFF - NBF_OUT   # 15 - 7 = 8 bits a descartar


def rnd_round_half_away(din, nb_to_rnd, nb_out):
    offset = (1 << (nb_to_rnd - 1)) - 1 if din < 0 else (1 << (nb_to_rnd - 1))
    rounded = (din + offset) >> nb_to_rnd  # >> en Python trunca hacia -inf, igual que en HW
    max_val = (1 << (nb_out - 1)) - 1
    min_val = -(1 << (nb_out - 1))
    return max(min_val, min(max_val, rounded))


# ---------------------------------------------------------------------------
# 4) Filtro FIR bit-serie completo (la misma arquitectura que se implementa
#    despues en ejercicio4a.sv, con la ROM completa)
# ---------------------------------------------------------------------------
def fir_da(x_seq, extra_flush=3):
    """
    x_seq: lista de enteros S(8,7) (-128..127).
    Devuelve UNA muestra de salida (S(8,7)) por cada grupo de NB_IN ciclos
    procesado, en el mismo orden temporal en que las produciria el RTL
    (incluye 'extra_flush' grupos de mas al final, sosteniendo la ultima
    muestra, para tener margen y no cortar la secuencia a mitad de camino).
    """
    data_q = [0] * N_COEFF
    bit_counter = 0
    accumulator = 0
    outputs = []
    sample_idx = 0
    i_data = x_seq[0] if x_seq else 0
    total_groups = len(x_seq) + extra_flush

    for _ in range(total_groups * NB_IN):
        addr = 0
        for k in range(N_COEFF):
            addr |= (((data_q[k] >> bit_counter) & 1) << k)
        partial_product = rom_fir_full(addr)

        if bit_counter == 0:
            outputs.append(rnd_round_half_away(accumulator, DELTA_FRAC, NB_OUT))
            new_acc = partial_product
        elif bit_counter == NB_IN - 1:
            new_acc = to_signed((accumulator >> 1) - partial_product, NB_PP)
        else:
            new_acc = to_signed((accumulator >> 1) + partial_product, NB_PP)

        if bit_counter == NB_IN - 1:
            data_q = [i_data] + data_q[:-1]
            sample_idx += 1
            if sample_idx < len(x_seq):
                i_data = x_seq[sample_idx]

        bit_counter = 0 if bit_counter == NB_IN - 1 else bit_counter + 1
        accumulator = new_acc

    return outputs


# ---------------------------------------------------------------------------
# 5) Vector de estimulo y calculo del golden
# ---------------------------------------------------------------------------
X_TEST = [0, 127, -128, 1, -1, 64, -64, 0, 0, 0,
          100, -100, 50, -50, 32, -32, 10, -10, 20, -20]

# La arquitectura tiene 1 grupo de latencia de arranque: el primer resultado
# que produce (outs[0]) corresponde al estado inicial (todo en cero), antes
# de que la primera muestra real haya terminado de procesarse. El resultado
# que corresponde a x_test[0] aparece recien en outs[1].
PIPELINE_OFFSET = 1

if __name__ == "__main__":
    outs = fir_da(X_TEST, extra_flush=3)
    golden = outs[PIPELINE_OFFSET: PIPELINE_OFFSET + len(X_TEST)]

    print("\nx_test:", X_TEST)
    print("golden:", golden)

    # Formato listo para pegar en el testbench de SystemVerilog
    print("\n--- Para copiar en GP04_ejercico4_tb.sv ---\n")
    print(f"    int x_test[{len(X_TEST)}] = '{{")
    print("        " + ", ".join(str(v) for v in X_TEST) + "")
    print("    };\n")
    print(f"    int golden[$] = '{{")
    print("        " + ", ".join(str(v) for v in golden) + "")
    print("    };")