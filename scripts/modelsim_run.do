# ============================================================
# Generic ModelSim compile, simulate, and waveform script
#
# Required variables supplied by the Makefile:
#   TOP
#   SOURCES
#   BUILD_DIR
#   BATCH
# ============================================================

transcript on
onerror {quit -code 1}

puts "============================================================"
puts "ModelSim simulation"
puts "Top module : $TOP"
puts "Build dir  : $BUILD_DIR"
puts "Sources    : $SOURCES"
puts "============================================================"

# Create a clean target-specific simulation library.
file mkdir $BUILD_DIR

if {[file exists "$BUILD_DIR/work"]} {
    file delete -force "$BUILD_DIR/work"
}

vlib "$BUILD_DIR/work"
vmap work "$BUILD_DIR/work"

# Compile the package first, followed by the DUT and testbench.
eval vlog \
    -sv \
    +incdir+include \
    -work work \
    $SOURCES

# Keep internal DUT signals accessible for waveform debugging.
vsim -voptargs=+acc work.$TOP

# Automatically display the testbench and DUT hierarchy.
add wave -divider "Simulation"
add wave -r sim:/$TOP/*

configure wave -signalnamewidth 1
configure wave -namecolwidth 250
configure wave -valuecolwidth 120

# Keep the GUI open after the testbench calls $finish.
onfinish stop

run -all
wave zoom full

puts "============================================================"
puts "Simulation finished."
puts "============================================================"

# Batch target exits automatically.
# GUI target leaves ModelSim open.
if {$BATCH} {
    quit -code 0
}
