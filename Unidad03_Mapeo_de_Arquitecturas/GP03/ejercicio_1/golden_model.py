#!/usr/bin/env python3
# golden_model.py -- modelo de referencia del lazo de recuperacion de fase
#   python3 golden_model.py              -> trayectoria esperada
#   python3 golden_model.py o_phase.txt  -> compara contra el dump del TB SV
import sys, math

NBF, ONE, FULL = 15, 1<<15, 1<<16
N_SAMPLES, THETA, AMP = 400, 0.30, 0.70
SEED_PHASE = 0.20   # <-- fase inicial (perturbacion). Con 0 el lazo queda muerto.

B0,B1,B2 = 0.10,0.20,0.10
A1,A2    = -0.30,0.10
KP,KI    = 0.05,0.005

def q15(x):
    return max(-32768, min(32767, round(x*ONE)))

def wrap_round_phase(p):
    q = math.floor(p*ONE+0.5) if p>=0 else math.ceil(p*ONE-0.5)
    return ((q+32768)%FULL)-32768

def run():
    mo0=mo1=mo2=0j; dl0=dl1=dl2=0j
    off1=0.0; pc=0.0
    phase_full = q15(SEED_PHASE)/ONE       # semilla
    phase_q    = phase_full
    out=[]
    for n in range(N_SAMPLES):
        in_re = q15(AMP*math.cos(THETA))/ONE
        in_im = q15(AMP*math.sin(THETA))/ONE
        mo_re =  in_im*phase_q
        mo_im = -in_re*phase_q
        mo2,mo1,mo0 = mo1,mo0,complex(mo_re,mo_im)
        dl2,dl1 = dl1,dl0
        dl0 = complex(B0*mo0.real+B1*mo1.real+B2*mo2.real-A1*dl1.real-A2*dl2.real,
                      B0*mo0.imag+B1*mo1.imag+B2*mo2.imag-A1*dl1.imag-A2*dl2.imag)
        offset = dl2.real*dl0.real - dl2.imag*dl0.imag
        off0,off1 = off1,offset
        pc = KP*off0 + KI*off1 + pc - KP*off1
        phase_full += pc
        oq = wrap_round_phase(phase_full)
        phase_q = oq/ONE
        out.append(oq)
    return out

def main():
    exp=run()
    if len(sys.argv)>1:
        got=[int(l) for l in open(sys.argv[1]) if l.strip()]
        n=min(len(exp),len(got))
        maxe=max((abs(got[i]-exp[i]) for i in range(n)),default=0)
        print(f"muestras={n}  error_max={maxe} LSB")
        print("[PASS]" if maxe<=4 else "[FAIL]")
    else:
        for i in range(0,len(exp),20):
            print(f"n={i:3d}  o_phase={exp[i]:7d}  ({exp[i]/ONE:+.5f})")
        print(f"final: {exp[-1]}  ({exp[-1]/ONE:+.5f})")

if __name__=="__main__": main()
