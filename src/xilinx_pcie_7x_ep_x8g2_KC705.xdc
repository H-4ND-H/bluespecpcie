##-----------------------------------------------------------------------------
##
## (c) Copyright 2010-2011 Xilinx, Inc. All rights reserved.
##
## This file contains confidential and proprietary information
## of Xilinx, Inc. and is protected under U.S. and
## international copyright and other intellectual property
## laws.
##
## DISCLAIMER
## This disclaimer is not a license and does not grant any
## rights to the materials distributed herewith. Except as
## otherwise provided in a valid license issued to you by
## Xilinx, and to the maximum extent permitted by applicable
## law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
## WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
## AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
## BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
## INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
## (2) Xilinx shall not be liable (whether in contract or tort,
## including negligence, or under any other theory of
## liability) for any loss or damage of any kind or nature
## related to, arising under or in connection with these
## materials, including for any direct, or any indirect,
## special, incidental, or consequential loss or damage
## (including loss of data, profits, goodwill, or any type of
## loss or damage suffered as a result of any action brought
## by a third party) even if such damage or loss was
## reasonably foreseeable or Xilinx had been advised of the
## possibility of the same.
##
## CRITICAL APPLICATIONS
## Xilinx products are not designed or intended to be fail-
## safe, or for use in any application requiring fail-safe
## performance, such as life-support or safety devices or
## systems, Class III medical devices, nuclear facilities,
## applications related to the deployment of airbags, or any
## other applications that could lead to death, personal
## injury, or severe property or environmental damage
## (individually and collectively, "Critical
## Applications"). Customer assumes the sole risk and
## liability of any use of Xilinx products in Critical
## Applications, subject only to applicable laws and
## regulations governing limitations on product liability.
##
## THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
## PART OF THIS FILE AT ALL TIMES.
##
##-----------------------------------------------------------------------------
## Project    : Series-7 Integrated Block for PCI Express
## File       : xilinx_pcie_7x_ep_x8g1.xdc
## Version    : 3.3
#
###############################################################################
# User Configuration 
# Link Width   - x8
# Link Speed   - gen1
# Family       - virtex7
# Part         - xc7vx485t
# Package      - ffg1157
# Speed grade  - -1
# PCIe Block   - X1Y0
###############################################################################
#
###############################################################################
# User Time Names / User Time Groups / Time Specs
###############################################################################

###############################################################################
# User Physical Constraints
###############################################################################


###############################################################################
# Pinout and Related I/O Constraints
###############################################################################

#
# SYS reset (input) signal.  The sys_reset_n signal should be
# obtained from the PCI Express interface if possible.  For
# slot based form factors, a system reset signal is usually
# present on the connector.  For cable based form factors, a
# system reset signal may not be available.  In this case, the
# system reset signal must be generated locally by some form of
# supervisory circuit.  You may change the IOSTANDARD and LOC
# to suit your requirements and VCCO voltage banking rules.
# Some 7 series devices do not have 3.3 V I/Os available.
# Therefore the appropriate level shift is required to operate
# with these devices that contain only 1.8 V banks.
#

#set_property PULLUP true [get_ports sys_rst_n]

###############################################################################
# Physical Constraints
###############################################################################
#
# SYS clock 100 MHz (input) signal. The sys_clk_p and sys_clk_n
# signals are the PCI Express reference clock. Virtex-7 GT
# Transceiver architecture requires the use of a dedicated clock
# resources (FPGA input pins) associated with each GT Transceiver.
# To use these pins an IBUFDS primitive (refclk_ibuf) is
# instantiated in user's design.
# Please refer to the Virtex-7 GT Transceiver User Guide
# (UG) for guidelines regarding clock resource selection.
#


set_property IOSTANDARD LVCMOS25 [get_ports CLK_emcclk]
#set_property LOC R24 [get_ports CLK_emcclk]
set_property BITSTREAM.CONFIG.BPI_SYNC_MODE Type2 [current_design]
set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN div-2 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullup [current_design]
set_property CONFIG_MODE BPI16 [current_design]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 2.5 [current_design]

set_property LOC IBUFDS_GTE2_X0Y1 [get_cells -hierarchical -regexp {.*pcie/refclk_ibuf}]

###############################################################################
# Timing Constraints
###############################################################################
#
#create_clock -name sys_clk -period 10 [get_ports sys_clk_p]
create_clock -name sys_clk -period 10 [get_pins -hier refclk_ibuf/O]
set_property LOC U7 [get_ports CLK_sys_clk_n] 
#actually PCIE_CLK_QO_N
set_property LOC U8 [get_ports CLK_sys_clk_p]
#
# 
#set_false_path -to [get_pins {pcie_7x_0_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/S0}]
#set_false_path -to [get_pins {pcie_7x_0_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/S1}]
set_false_path -to [get_pins -hier {pclk_i1_bufgctrl.pclk_i1/S0}]
set_false_path -to [get_pins -hier {pclk_i1_bufgctrl.pclk_i1/S1}]
#
#
#set_case_analysis 1 [get_pins -hier {pcie_7x_0_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/S0}]
#set_case_analysis 0 [get_pins -hier {pcie_7x_0_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/S1}]
set_property DONT_TOUCH true [get_cells -of [get_nets -of [get_pins -hier -regexp { .*pcie_7x_0_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/S0}]]]

#
#
# Timing ignoring the below pins to avoid CDC analysis, but care has been taken in RTL to sync properly to other clock domain.
#
#
###############################################################################
# Tandem Configuration Constraints
###############################################################################

#set_false_path -from [get_ports sys_rst_n]

set_property IOSTANDARD LVCMOS15 [get_ports led[0]]
set_property IOSTANDARD LVCMOS15 [get_ports led[1]]
set_property IOSTANDARD LVCMOS15 [get_ports led[2]]
set_property IOSTANDARD LVCMOS15 [get_ports led[3]]
set_property LOC AB8 [get_ports led[0]]
set_property LOC AA8 [get_ports led[1]]
set_property LOC AC9 [get_ports led[2]]
# USER CLK HEART BEAT = led_3
set_property LOC AB9 [get_ports led[3]]

set_property IOSTANDARD LVCMOS25 [get_ports RST_N_sys_rst_n]
set_property PULLUP true [get_ports RST_N_sys_rst_n]
set_property LOC G25 [get_ports RST_N_sys_rst_n]
set_false_path -from [get_ports RST_N_sys_rst_n]






create_generated_clock -name clk_125mhz_x0y0 [get_pins -hierarchical -regexp {.*pcie_7x_0_support_i/pipe_clock_i/mmcm_i/CLKOUT0}]
create_generated_clock -name clk_250mhz_x0y0 [get_pins -hier -regexp {.*pcie_7x_0_support_i/pipe_clock_i/mmcm_i/CLKOUT1}]
create_generated_clock -name clk_125mhz_mux_x0y0 \ 
-source [get_pins -hier -regexp {.*pcie_7x_0_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/I0}] \
		-divide_by 1 \
		[get_pins -hier -regexp {.*pcie_7x_0_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/O}]
#
create_generated_clock -name clk_250mhz_mux_x0y0 \ 
-source [get_pins -hier -regexp { .*pcie_7x_0_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/I1}] \
	-divide_by 1 -add -master_clock [get_clocks -of [get_pins -hier -regexp { .*pcie_7x_0_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/I1}]] \
	[get_pins -hier -regexp { .*pcie_7x_0_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/O}]
#
set_clock_groups -name pcieclkmux -physically_exclusive -group clk_125mhz_mux_x0y0 -group clk_250mhz_mux_x0y0



# PCIe Lane 0
set_property LOC GTXE2_CHANNEL_X0Y7 [get_cells -hierarchical -regexp {.*gt_top_i/pipe_wrapper_i/pipe_lane\[0\].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]
# PCIe Lane 1
set_property LOC GTXE2_CHANNEL_X0Y6 [get_cells -hierarchical -regexp {.*gt_top_i/pipe_wrapper_i/pipe_lane\[1\].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]
# PCIe Lane 2
set_property LOC GTXE2_CHANNEL_X0Y5 [get_cells -hierarchical -regexp {.*gt_top_i/pipe_wrapper_i/pipe_lane\[2\].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]
# PCIe Lane 3
set_property LOC GTXE2_CHANNEL_X0Y4 [get_cells -hierarchical -regexp {.*gt_top_i/pipe_wrapper_i/pipe_lane\[3\].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]
# PCIe Lane 4
set_property LOC GTXE2_CHANNEL_X0Y3 [get_cells -hierarchical -regexp {.*gt_top_i/pipe_wrapper_i/pipe_lane\[4\].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]
# PCIe Lane 5
set_property LOC GTXE2_CHANNEL_X0Y2 [get_cells -hierarchical -regexp {.*gt_top_i/pipe_wrapper_i/pipe_lane\[5\].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]
# PCIe Lane 6
set_property LOC GTXE2_CHANNEL_X0Y1 [get_cells -hierarchical -regexp {.*gt_top_i/pipe_wrapper_i/pipe_lane\[6\].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]
# PCIe Lane 7
set_property LOC GTXE2_CHANNEL_X0Y0 [get_cells -hierarchical -regexp {.*gt_top_i/pipe_wrapper_i/pipe_lane\[7\].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]

set_property LOC PCIE_X0Y3 [get_cells -hierarchical -regexp {.*pcie_top_i/pcie_7x_i/pcie_block_i}]
#Why is it X0Y3?
#set_property LOC PCIE_X0Y0 [get_cells -hierarchical -regexp {.*pcie_top_i/pcie_7x_i/pcie_block_i}]

#set_property LOC RAMB36_X4Y34 [get_cells -hier {pcie_7x_0pcie_7x_0_core_top/pcie_top_i/pcie_7x_i/pcie_bram_top/pcie_brams_rx/brams[0].ram/use_sdp.ramb36sdp/genblk*.bram36_dp_bl.bram36_tdp_bl}]
#set_property LOC RAMB36_X4Y33 [get_cells -hier {pcie_7x_0pcie_7x_0_core_top/pcie_top_i/pcie_7x_i/pcie_bram_top/pcie_brams_rx/brams[1].ram/use_sdp.ramb36sdp/genblk*.bram36_dp_bl.bram36_tdp_bl}]
#set_property LOC RAMB36_X4Y31 [get_cells -hier {pcie_7x_0pcie_7x_0_core_top/pcie_top_i/pcie_7x_i/pcie_bram_top/pcie_brams_tx/brams[0].ram/use_sdp.ramb36sdp/genblk*.bram36_dp_bl.bram36_tdp_bl}]
#set_property LOC RAMB36_X4Y30 [get_cells -hier {pcie_7x_0pcie_7x_0_core_top/pcie_top_i/pcie_7x_i/pcie_bram_top/pcie_brams_tx/brams[1].ram/use_sdp.ramb36sdp/genblk*.bram36_dp_bl.bram36_tdp_bl}]



set_property PACKAGE_PIN M5 [get_ports {pcie_pins_rxn_i[0]}]
set_property PACKAGE_PIN M6 [get_ports {pcie_pins_rxp_i[0]}]
set_property PACKAGE_PIN P5 [get_ports {pcie_pins_rxn_i[1]}]
set_property PACKAGE_PIN P6 [get_ports {pcie_pins_rxp_i[1]}]
set_property PACKAGE_PIN R3 [get_ports {pcie_pins_rxn_i[2]}]
set_property PACKAGE_PIN R4 [get_ports {pcie_pins_rxp_i[2]}]
set_property PACKAGE_PIN T5 [get_ports {pcie_pins_rxn_i[3]}]
set_property PACKAGE_PIN T6 [get_ports {pcie_pins_rxp_i[3]}]
set_property PACKAGE_PIN V5 [get_ports {pcie_pins_rxn_i[4]}]
set_property PACKAGE_PIN V6 [get_ports {pcie_pins_rxp_i[4]}]
set_property PACKAGE_PIN W3 [get_ports {pcie_pins_rxn_i[5]}]
set_property PACKAGE_PIN W4 [get_ports {pcie_pins_rxp_i[5]}]
set_property PACKAGE_PIN Y5 [get_ports {pcie_pins_rxn_i[6]}]
set_property PACKAGE_PIN Y6 [get_ports {pcie_pins_rxp_i[6]}]
set_property PACKAGE_PIN AA3 [get_ports {pcie_pins_rxn_i[7]}]
set_property PACKAGE_PIN AA4 [get_ports {pcie_pins_rxp_i[7]}]
set_property PACKAGE_PIN L3 [get_ports {pcie_pins_TXN[0]}]
set_property PACKAGE_PIN L4 [get_ports {pcie_pins_TXP[0]}]
set_property PACKAGE_PIN M1 [get_ports {pcie_pins_TXN[1]}]
set_property PACKAGE_PIN M2 [get_ports {pcie_pins_TXP[1]}]
set_property PACKAGE_PIN N3 [get_ports {pcie_pins_TXN[2]}]
set_property PACKAGE_PIN N4 [get_ports {pcie_pins_TXP[2]}]
set_property PACKAGE_PIN P1 [get_ports {pcie_pins_TXN[3]}]
set_property PACKAGE_PIN P2 [get_ports {pcie_pins_TXP[3]}]
set_property PACKAGE_PIN T1 [get_ports {pcie_pins_TXN[4]}]
set_property PACKAGE_PIN T2 [get_ports {pcie_pins_TXP[4]}]
set_property PACKAGE_PIN U3 [get_ports {pcie_pins_TXN[5]}]
set_property PACKAGE_PIN U4 [get_ports {pcie_pins_TXP[5]}]
set_property PACKAGE_PIN V1 [get_ports {pcie_pins_TXN[6]}]
set_property PACKAGE_PIN V2 [get_ports {pcie_pins_TXP[6]}]
set_property PACKAGE_PIN Y1 [get_ports {pcie_pins_TXN[7]}]
set_property PACKAGE_PIN Y2 [get_ports {pcie_pins_TXP[7]}]






###############################################################################
# End
###############################################################################
