# flash simulation test
This directory contains files used in simulation testing of the flash. Only essential files are included here, the rest of the files can be generated using vivado.

## To replicate the simulation test
1. Open Vivado and create a new project.    
2. Add the `sim_top.vhdl` file as the top level source.
3. Add the HDL files from the `hdl/` directory.
4. Import the `design_1.tcl` file and run it to generate the block diagram.
5. Export the hardware and launch the Vitis IDE.
6. Create a new workspace
7. Import the platform `.xsa` file  
8. Create a platform project and create an empty appilcation project.
9. Add the `main.c` file to the application project.
10. In the Vivado project, open the block design again and associate the generated `.elf` file with the microblaze.
11. Run the simulation.

## Directory structure
``` text
00_simulation_test/    
├── design_1.tcl       : tcl to generate the block diagram
├── flash_adapter.wcfg : My waveform configuration files
├── lscript.ld         : microblaze linker
├── main.c             : Code running on the microblaze
├── README.md          : This file
└── sim_top.vhdl       : Top level simulation file
```

