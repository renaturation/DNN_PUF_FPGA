
############## clock and reset define##################
create_clock -period 20.000 [get_ports clk]
set_property IOSTANDARD LVCMOS18 [get_ports clk]
set_property IOSTANDARD LVCMOS18 [get_ports rstn]
set_property PACKAGE_PIN AE10 [get_ports clk]
set_property PACKAGE_PIN AD24 [get_ports rstn]

############## led define##################
set_property PACKAGE_PIN Y28 [get_ports {led1}]
set_property PACKAGE_PIN AA28  [get_ports {led2}]
set_property IOSTANDARD LVCMOS18 [get_ports {led1}]
set_property IOSTANDARD LVCMOS18 [get_ports {led2}]