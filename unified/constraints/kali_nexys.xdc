## ============================================================================
## KaLi — Nexys A7-100T Constraints File
## Device: xc7a100tcsg324-1
## Top module: kali_nexys_top
##
## Pin assignment summary:
##   CLK100MHZ  → E3         100MHz system clock
##   CPU_RESETN → C12        Active-low reset (hold = reset)
##
##   SW[0]      → J15        mode:         0=Dilithium,  1=Kyber
##   SW[1]      → L16        inv:          0=NTT fwd,    1=INTT inv
##   SW[2]      → M13        compress_sel: 0=decompress, 1=compress
##   SW[3]      → R15  ┐
##   SW[4]      → R17  │     d[3:0]: compression parameter
##   SW[5]      → T18  │     valid values: 1,4,5,10,11
##   SW[6]      → U18  ┘     (set in binary on SW[6:3])
##   SW[7]      → R13  ┐
##   SW[8]      → T8   │
##   SW[9]      → U8   │     coeff_in[8:0]: lower 9 bits of
##   SW[10]     → R16  │     the input coefficient (0–511 range
##   SW[11]     → T13  │     from switches; padded to 12 bits)
##   SW[12]     → H6   │
##   SW[13]     → U12  │
##   SW[14]     → U11  │
##   SW[15]     → V10  ┘
##
##   BTNC       → N17        valid_in:  press to trigger operation
##   BTNU       → M18        page up:   next display page
##   BTND       → P18        page down: prev display page
##   CPU_RESETN → C12        rst_n:     hold LOW to reset
##
##   LED[0..15] → (see below) lower 16 bits of current result
##   LED16_B    → R12        valid_out blink (result ready)
##   LED16_G    → M16        inv indicator
##   LED16_R    → N15        mode indicator (Kyber=ON)
##   LED17_B    → G14        page[1]
##   LED17_G    → R11        page[0]
##   LED17_R    → N16        compress_sel indicator
##
##   7-seg CA..CG, DP, AN[7:0] → see below
## ============================================================================


## ----------------------------------------------------------------------------
## Clock
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { CLK100MHZ }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { CLK100MHZ }];


## ----------------------------------------------------------------------------
## Reset (active-low, CPU_RESETN)
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN C12   IOSTANDARD LVCMOS33 } [get_ports { CPU_RESETN }];


## ----------------------------------------------------------------------------
## Switches → inputs
## SW[0]  mode
## SW[1]  inv
## SW[2]  compress_sel
## SW[6:3] d[3:0]
## SW[15:7] coeff_in[8:0]
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports { SW[0] }];
set_property -dict { PACKAGE_PIN L16   IOSTANDARD LVCMOS33 } [get_ports { SW[1] }];
set_property -dict { PACKAGE_PIN M13   IOSTANDARD LVCMOS33 } [get_ports { SW[2] }];
set_property -dict { PACKAGE_PIN R15   IOSTANDARD LVCMOS33 } [get_ports { SW[3] }];
set_property -dict { PACKAGE_PIN R17   IOSTANDARD LVCMOS33 } [get_ports { SW[4] }];
set_property -dict { PACKAGE_PIN T18   IOSTANDARD LVCMOS33 } [get_ports { SW[5] }];
set_property -dict { PACKAGE_PIN U18   IOSTANDARD LVCMOS33 } [get_ports { SW[6] }];
set_property -dict { PACKAGE_PIN R13   IOSTANDARD LVCMOS33 } [get_ports { SW[7] }];
set_property -dict { PACKAGE_PIN T8    IOSTANDARD LVCMOS18 } [get_ports { SW[8] }];
set_property -dict { PACKAGE_PIN U8    IOSTANDARD LVCMOS18 } [get_ports { SW[9] }];
set_property -dict { PACKAGE_PIN R16   IOSTANDARD LVCMOS33 } [get_ports { SW[10] }];
set_property -dict { PACKAGE_PIN T13   IOSTANDARD LVCMOS33 } [get_ports { SW[11] }];
set_property -dict { PACKAGE_PIN H6    IOSTANDARD LVCMOS33 } [get_ports { SW[12] }];
set_property -dict { PACKAGE_PIN U12   IOSTANDARD LVCMOS33 } [get_ports { SW[13] }];
set_property -dict { PACKAGE_PIN U11   IOSTANDARD LVCMOS33 } [get_ports { SW[14] }];
set_property -dict { PACKAGE_PIN V10   IOSTANDARD LVCMOS33 } [get_ports { SW[15] }];


## ----------------------------------------------------------------------------
## Buttons
## BTNC → valid_in (trigger computation)
## BTNU → page up
## BTND → page down
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports { BTNC }];
set_property -dict { PACKAGE_PIN M18   IOSTANDARD LVCMOS33 } [get_ports { BTNU }];
set_property -dict { PACKAGE_PIN P18   IOSTANDARD LVCMOS33 } [get_ports { BTND }];


## ----------------------------------------------------------------------------
## LEDs [15:0] → lower 16 bits of active result
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { LED[0] }];
set_property -dict { PACKAGE_PIN K15   IOSTANDARD LVCMOS33 } [get_ports { LED[1] }];
set_property -dict { PACKAGE_PIN J13   IOSTANDARD LVCMOS33 } [get_ports { LED[2] }];
set_property -dict { PACKAGE_PIN N14   IOSTANDARD LVCMOS33 } [get_ports { LED[3] }];
set_property -dict { PACKAGE_PIN R18   IOSTANDARD LVCMOS33 } [get_ports { LED[4] }];
set_property -dict { PACKAGE_PIN V17   IOSTANDARD LVCMOS33 } [get_ports { LED[5] }];
set_property -dict { PACKAGE_PIN U17   IOSTANDARD LVCMOS33 } [get_ports { LED[6] }];
set_property -dict { PACKAGE_PIN U16   IOSTANDARD LVCMOS33 } [get_ports { LED[7] }];
set_property -dict { PACKAGE_PIN V16   IOSTANDARD LVCMOS33 } [get_ports { LED[8] }];
set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS33 } [get_ports { LED[9] }];
set_property -dict { PACKAGE_PIN U14   IOSTANDARD LVCMOS33 } [get_ports { LED[10] }];
set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS33 } [get_ports { LED[11] }];
set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports { LED[12] }];
set_property -dict { PACKAGE_PIN V14   IOSTANDARD LVCMOS33 } [get_ports { LED[13] }];
set_property -dict { PACKAGE_PIN V12   IOSTANDARD LVCMOS33 } [get_ports { LED[14] }];
set_property -dict { PACKAGE_PIN V11   IOSTANDARD LVCMOS33 } [get_ports { LED[15] }];


## ----------------------------------------------------------------------------
## RGB LEDs
## LED16: R=mode(Kyber),  G=inv(INTT),  B=valid_out pulse
## LED17: R=compress_sel, G=page[0],    B=page[1]
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN R12   IOSTANDARD LVCMOS33 } [get_ports { LED16_B }];
set_property -dict { PACKAGE_PIN M16   IOSTANDARD LVCMOS33 } [get_ports { LED16_G }];
set_property -dict { PACKAGE_PIN N15   IOSTANDARD LVCMOS33 } [get_ports { LED16_R }];
set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { LED17_B }];
set_property -dict { PACKAGE_PIN R11   IOSTANDARD LVCMOS33 } [get_ports { LED17_G }];
set_property -dict { PACKAGE_PIN N16   IOSTANDARD LVCMOS33 } [get_ports { LED17_R }];


## ----------------------------------------------------------------------------
## 7-Segment Display
## Segments CA..CG active LOW, anodes AN[7:0] active LOW
##
## Digit layout (left→right on board):
##   AN[7]=digit7 (MSB of result)  ...  AN[0]=digit0 (LSB of result)
##
## Page 0: 8 hex digits of mod_red result
##   e.g. coeff_in=100, mode=0(Dilithium): 100*100=10000 mod 8380417 = 0000_2710
##
## Page 1: upper 4 digits = compress result, lower 4 digits = d value
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports { CA }];
set_property -dict { PACKAGE_PIN R10   IOSTANDARD LVCMOS33 } [get_ports { CB }];
set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports { CC }];
set_property -dict { PACKAGE_PIN K13   IOSTANDARD LVCMOS33 } [get_ports { CD }];
set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports { CE }];
set_property -dict { PACKAGE_PIN T11   IOSTANDARD LVCMOS33 } [get_ports { CF }];
set_property -dict { PACKAGE_PIN L18   IOSTANDARD LVCMOS33 } [get_ports { CG }];
set_property -dict { PACKAGE_PIN H15   IOSTANDARD LVCMOS33 } [get_ports { DP }];

set_property -dict { PACKAGE_PIN J17   IOSTANDARD LVCMOS33 } [get_ports { AN[0] }];
set_property -dict { PACKAGE_PIN J18   IOSTANDARD LVCMOS33 } [get_ports { AN[1] }];
set_property -dict { PACKAGE_PIN T9    IOSTANDARD LVCMOS33 } [get_ports { AN[2] }];
set_property -dict { PACKAGE_PIN J14   IOSTANDARD LVCMOS33 } [get_ports { AN[3] }];
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { AN[4] }];
set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS33 } [get_ports { AN[5] }];
set_property -dict { PACKAGE_PIN K2    IOSTANDARD LVCMOS33 } [get_ports { AN[6] }];
set_property -dict { PACKAGE_PIN U13   IOSTANDARD LVCMOS33 } [get_ports { AN[7] }];


## ----------------------------------------------------------------------------
## Timing exceptions
## The debouncer and 7-seg refresh counter are purely slow-path logic.
## False path on all switch/button inputs to avoid overconstraining.
## ----------------------------------------------------------------------------
set_false_path -from [get_ports {SW[*]}]
set_false_path -from [get_ports {BTNC}]
set_false_path -from [get_ports {BTNU}]
set_false_path -from [get_ports {BTND}]
set_false_path -from [get_ports {CPU_RESETN}]
