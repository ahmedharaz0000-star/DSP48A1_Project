vlib work
vmap work work
vlog -work work DSP48A1.v
vlog -work work tb_DSP48A1.v
vsim -voptargs=+acc work.tb_DSP48A1
add wave -position insertpoint sim:/tb_DSP48A1/*
run -all
wave zoom full
