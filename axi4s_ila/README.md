# AXI4 Slave ILA
This directory contains work related to AXI4 Stream In-System Logic Analyzer. 

The motivation to make this is follows:
* There is no ILA like in Xilinx toolchain in the Microchip toolchain, the SmartDebug can not replace the ILA
* ILA servers as a really good tool to debug the signals

This specific ILA is specialised for the AXI4S but a similar logic can be modified and easily adapted for generic IOs.

## Features
* Uses fabric ram for data storage and can be read back with AXI4Lite interface
* Data acquisition happens continously in a circular buffer
* Pass through AXI4 Stream ports ensures no delay is introduced due to the IP
* Customizable trigger:
1. Trigger can be set with AXI4Lite interface
2. Any AXI4S signal can be set as a trigger condition
3. Once setting the triggers condition, the ILA can be armed
4. Number of samples before and after trigger can be adjusted

## Ports
* axi4s_in: AXI4S Slave port: Serves as slave port for the master
* axi4s_out: AXI4S Master port: Serves as master port for the slave
* axi4lite: AXI4Lite Slave port: Configuration and readout port

## Configuration Parameters
* Buffer size

## axi4lite Register Map

## Serving suggestions
This design contains minimal AXI4S ports, user can add rest of the ports from the standard.
This can be further optimised for the data storage compression although I don't prefer that as it will make the readout complex.
