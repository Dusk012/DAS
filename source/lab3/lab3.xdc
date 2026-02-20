#####################################################################
##
##  Fichero:
##    lab3.xdc  12/09/2023
##
##    (c) J.M. Mendias
##    Diseño Automático de Sistemas
##    Facultad de Informática. Universidad Complutense de Madrid
##
##  Propósito:
##    Configuración del laboratorio 3
##
##  Notas de diseño:
##
#####################################################################

#
# Voltaje del interfaz de configuración de la FPGA
#
set_property CFGBVS VCCO [current_design];
set_property CONFIG_VOLTAGE 3.3 [current_design];

#
# Reloj del sistema: 100 MHz
#
set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports clk];
create_clock -name sysClk -period 10.0 -waveform {0 5} [get_ports clk];

#
# Pines conectados a los pulsadores
#
set_property -dict { PACKAGE_PIN W19 IOSTANDARD LVCMOS33 } [get_ports coin];    # btnL
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports go];      # btnC
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports aRst];    # btnU

#
# Pines conectados al display 7 segmentos
#
set_property -dict { PACKAGE_PIN W7 IOSTANDARD LVCMOS33 } [get_ports {segs_n[6]}];
set_property -dict { PACKAGE_PIN W6 IOSTANDARD LVCMOS33 } [get_ports {segs_n[5]}];
set_property -dict { PACKAGE_PIN U8 IOSTANDARD LVCMOS33 } [get_ports {segs_n[4]}];
set_property -dict { PACKAGE_PIN V8 IOSTANDARD LVCMOS33 } [get_ports {segs_n[3]}];
set_property -dict { PACKAGE_PIN U5 IOSTANDARD LVCMOS33 } [get_ports {segs_n[2]}];
set_property -dict { PACKAGE_PIN V5 IOSTANDARD LVCMOS33 } [get_ports {segs_n[1]}];
set_property -dict { PACKAGE_PIN U7 IOSTANDARD LVCMOS33 } [get_ports {segs_n[0]}];
set_property -dict { PACKAGE_PIN V7 IOSTANDARD LVCMOS33 } [get_ports {segs_n[7]}];

set_property -dict { PACKAGE_PIN U2 IOSTANDARD LVCMOS33 } [get_ports {an_n[0]}];
set_property -dict { PACKAGE_PIN U4 IOSTANDARD LVCMOS33 } [get_ports {an_n[1]}];
set_property -dict { PACKAGE_PIN V4 IOSTANDARD LVCMOS33 } [get_ports {an_n[2]}];
set_property -dict { PACKAGE_PIN W4 IOSTANDARD LVCMOS33 } [get_ports {an_n[3]}];