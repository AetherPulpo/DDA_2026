//! @title FPGA Files List
//! @author Advance Digital Design - Ariel Pola
//! @date 10-10-2021
//! @version Unit03 - Mapeo de Arquitecturas Dedicadas
//! @brief Transmitter filter 
//! - PRBS generator with polyphase filters and block memory for save samples
//! - PRBS generator generates a bit per 8 clock cycles

`include "D:\Maestria\DDA\DDA_2026\Unidad03_Mapeo_de_Arquitecturas\Lab03\rtl2025\include\artyc_include.v"

`include "D:\Maestria\DDA\DDA_2026\Unidad03_Mapeo_de_Arquitecturas\Lab03\rtl2025\parallel_prbs_gen\prbsx.v"

`include "D:\Maestria\DDA\DDA_2026\Unidad03_Mapeo_de_Arquitecturas\Lab03\rtl2025\debug\bram.v"
`include "D:\Maestria\DDA\DDA_2026\Unidad03_Mapeo_de_Arquitecturas\Lab03\rtl2025\debug\ram_fsm.v"
`include "D:\Maestria\DDA\DDA_2026\Unidad03_Mapeo_de_Arquitecturas\Lab03\rtl2025\debug\ram_save.v"

`include "D:\Maestria\DDA\DDA_2026\Unidad03_Mapeo_de_Arquitecturas\Lab03\rtl2025\srrc\tx_fcsg.v"
`include "D:\Maestria\DDA\DDA_2026\Unidad03_Mapeo_de_Arquitecturas\Lab03\rtl2025\srrc\tx_srrc.v"
