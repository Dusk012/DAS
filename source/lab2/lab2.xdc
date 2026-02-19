#####################################################################
##
##  Fichero:
##    lab2.xdc  07/09/2023
##
##    (c) J.M. Mendias
##    Diseño Automático de Sistemas
##    Facultad de Informática. Universidad Complutense de Madrid
##
##  Propósito:
##    Configuración del laboratorio 2
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
# Pines conectados al array de leds
#
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {leds[0]}];
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports {leds[1]}];
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {leds[2]}];
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports {leds[3]}];
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports {leds[4]}];
set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports {leds[5]}];
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports {leds[6]}];
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports {leds[7]}];
set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 } [get_ports {leds[8]}];
set_property -dict { PACKAGE_PIN V3  IOSTANDARD LVCMOS33 } [get_ports {leds[9]}];
set_property -dict { PACKAGE_PIN W3  IOSTANDARD LVCMOS33 } [get_ports {leds[10]}];
set_property -dict { PACKAGE_PIN U3  IOSTANDARD LVCMOS33 } [get_ports {leds[11]}];
set_property -dict { PACKAGE_PIN P3  IOSTANDARD LVCMOS33 } [get_ports {leds[12]}];
set_property -dict { PACKAGE_PIN N3  IOSTANDARD LVCMOS33 } [get_ports {leds[13]}];
set_property -dict { PACKAGE_PIN P1  IOSTANDARD LVCMOS33 } [get_ports {leds[14]}];
set_property -dict { PACKAGE_PIN L1  IOSTANDARD LVCMOS33 } [get_ports {leds[15]}];

#
# Pines conectados a los pulsadores
#
set_property -dict { PACKAGE_PIN W19 IOSTANDARD LVCMOS33 } [get_ports startStop];   # btnL
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports lap];         # btnC
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports clear];       # btnU


