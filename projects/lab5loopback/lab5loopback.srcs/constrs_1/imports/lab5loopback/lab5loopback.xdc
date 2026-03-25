#####################################################################
##
##  Fichero:
##    lab5loopback.xdc  12/09/2023
##
##    (c) J.M. Mendias
##    Diseño Automático de Sistemas
##    Facultad de Informática. Universidad Complutense de Madrid
##
##  Propósito:
##    Configuración del laboratorio 5: Loopback sin FIFO
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
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports rst];    # btnU

#
# Pines conectados al USB-RS232 Interface
#
set_property -dict { PACKAGE_PIN B18 IOSTANDARD LVCMOS33 } [get_ports RxD];
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports TxD];