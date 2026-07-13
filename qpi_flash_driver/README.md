# memory_interface
This folder contains the MX25L25645G memory interface driver. The driver is designed to work with the MX25L25645G memory chip, providing functions for reading, writing, and erasing data.

This is an unfinished project and the C driver is not written. The HDL is working with following functions:
* READ
* WRITE 
* ERASE

## WRITE policy
This driver does not check if the memory is already written. It will write to the memory regardless of its current state. It is the responsibility of the user to ensure that the chip is erased before writing new data to it. 

## Cause of the project
The project was created to provide a simple and efficient interface for the MX25L25645G. It was initially unsure of how to store the data on the SITARE-1 payload. We were focused on using the flash memory. But we decided to use the RAM in the end as the payload which is not working correctly won't likely store correct data.

Nonetheless, this project can be used for other projects that require a memory interface driver for the MX25L25645G chip. Specially for the Deep Space Navigation where it is desirable to store all the data in the non-volatile memory as the spacecraft may do power cycle in between acquisition of data.

## How it would've been implemented
The flash was intended to be used as cheap long term storage for the event data. The storage would have been implemented as a circular buffer, where new data would overwrite the oldest data when the memory is full.

In each block, the first sector would be reserved for metadata with information about the block, such as the timestamp of the first data point and a thermometer code to indicate state of the rest of the sectors. This is to boot the flash correctly and to know which sectors are valid and which are not. Once initialized, the ERASE and the WRITE functions can be used blindly.

## Directory structure
``` text
memory_interface/
├── docs                        : Contains the documentation for the memory interface driver.
├── hdl                         : HDL source files
├── MX25L25645G, Verilog, v1.21 : Vendor model for the MX25L25645G memory chip.
├── README.md                   : This file
└── tests                       : Testing files
```