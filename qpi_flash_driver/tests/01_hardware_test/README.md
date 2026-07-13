# Flash Hardware Test
This directory contains the hardware test for the QPI flash. The test is implemented in a Jupyter notebook and can be run on the FPGA board to verify the functionality of the QPI flash interface.

## To replicate the hardware test
1. Open Vivado and create a new project.
2. Import the hdl files and the `design_1.tcl` file to generate the block diagram.
3. Generate the bitstream, copy the `.bit` and `.hwh` files to the SD card.
4. Launch the Jupyter notebook `qpi_flash_test.ipynb` and follow the instructions to run the test on the Pynq Z2 board. (See more about the Jupyter PYNQ environment at [pynq.io](https://pynq.io))

## Directory structure
``` text
01_hardware_test/
├── block_design.png   : Block design screenshot for reference
├── design_1.tcl
├── qpi_flash_test.ipynb
└── README.md
```