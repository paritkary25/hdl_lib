// File: main.c
// Author: YP
// Last Modifies:

// word is 32 bits.
#include <strings.h>
#include <stdint.h>
#include <stdio.h>
#include <wchar.h>

#include "xparameters.h"
#include "xio.h"
#include "mb_interface.h"
#include "xil_io.h"

#define cmd_reg_off    0 * 4
#define cmd_mode_mask  0
#define cmd_flash_NRST_mask 1<<3

#define mode_BOOT        0
#define mode_FLASH_RESET 1
#define mode_RD          2
#define mode_WR          3
#define mode_SE          4
#define mode_BE          5
#define mode_CE          6
#define mode_DPD         7

#define stat_reg_off   2 * 4 
#define stat_bit_mask  1
#define stat_id_ok     1<<1
#define stat_wip_mask  1<<2 
#define stat_qpi_trx_busy 1<<3

int main( ) {
    uint32_t ready;
    do {
        ready = Xil_In32(XPAR_FLASH_AXIS_QSPI_ADAP_0_BASEADDR + stat_reg_off) & (stat_bit_mask); 
    } while( !ready );

    Xil_Out32( XPAR_FLASH_AXIS_QSPI_ADAP_0_BASEADDR + cmd_reg_off, mode_RD );

    // Read 20 bytes from address 0x0000_0040
    putfsl( 0x00004000, 0 );
    putfsl( 20, 0 );

    do {
        ready = !( Xil_In32( XPAR_FLASH_AXIS_QSPI_ADAP_0_BASEADDR + stat_reg_off ) & ( stat_wip_mask ) );
    } while( !ready );

    // testing read from second block
    // Read single word from adress 0x01FF_0030
    putfsl( 0x01FF0030, 0 );
    putfsl( 4, 0 );

    do {
        ready = !( Xil_In32( XPAR_FLASH_AXIS_QSPI_ADAP_0_BASEADDR + stat_reg_off ) & ( stat_wip_mask ) );
    } while( !ready );

    // Performing a word write at 0x00001111 and reading it back
    Xil_Out32( XPAR_FLASH_AXIS_QSPI_ADAP_0_BASEADDR + cmd_reg_off, mode_WR);

    putfsl( 0x00001111, 0 );
    putfsl( 0xd0bad0ba, 0 );

    do {
        ready = !( Xil_In32( XPAR_FLASH_AXIS_QSPI_ADAP_0_BASEADDR + stat_reg_off ) & ( stat_wip_mask ) );
    } while( !ready );

    Xil_Out32( XPAR_FLASH_AXIS_QSPI_ADAP_0_BASEADDR + cmd_reg_off, mode_RD);
    putfsl( 0x00001111, 0 );
    putfsl( 4, 0 );

    do {
        ready = !( Xil_In32( XPAR_FLASH_AXIS_QSPI_ADAP_0_BASEADDR + stat_reg_off ) & ( stat_wip_mask ) );
    } while( !ready );

    // Write some data at 0x01BABABA
    Xil_Out32( XPAR_FLASH_AXIS_QSPI_ADAP_0_BASEADDR + cmd_reg_off, mode_WR);
    putfsl( 0x01BABABA, 0 );
    putfsl( 0xb000b555, 0 );
    putfsl( 0x65156aaa, 0 );
    putfsl( 0x01234567, 0 );
    putfsl( 0x890abcde, 0 );
    putfsl( 0xfedcba09, 0 );

    do {
        ready = !( Xil_In32( XPAR_FLASH_AXIS_QSPI_ADAP_0_BASEADDR + stat_reg_off ) & ( stat_wip_mask ) );
    } while( !ready );

    Xil_Out32( XPAR_FLASH_AXIS_QSPI_ADAP_0_BASEADDR + cmd_reg_off, mode_RD);
    putfsl( 0x01BABABA, 0 );
    putfsl( 32, 0 );

    do {
        ready = !( Xil_In32( XPAR_FLASH_AXIS_QSPI_ADAP_0_BASEADDR + stat_reg_off ) & ( stat_wip_mask ) );
    } while( !ready );

    // DPD
    Xil_Out32( XPAR_FLASH_AXIS_QSPI_ADAP_0_BASEADDR + cmd_reg_off, mode_DPD);
    for( volatile uint32_t i = 0; i < 1024; i++ );
    Xil_Out32( XPAR_FLASH_AXIS_QSPI_ADAP_0_BASEADDR + cmd_reg_off, mode_RD);

    do {
        ready = Xil_In32(XPAR_FLASH_AXIS_QSPI_ADAP_0_BASEADDR + stat_reg_off) & (stat_bit_mask); 
    } while( !ready );

    // Do sector erase at 0x01BABABA and check the data again
    Xil_Out32( XPAR_FLASH_AXIS_QSPI_ADAP_0_BASEADDR + cmd_reg_off, mode_SE);
    putfsl( 0x01BABABA, 0 );

    do {
        ready = !( Xil_In32( XPAR_FLASH_AXIS_QSPI_ADAP_0_BASEADDR + stat_reg_off ) & ( stat_wip_mask ) );
    } while( !ready );

    Xil_Out32( XPAR_FLASH_AXIS_QSPI_ADAP_0_BASEADDR + cmd_reg_off, mode_RD);
    putfsl( 0x01BABABA, 0 );
    putfsl( 32, 0 );

    do {
        ready = !( Xil_In32( XPAR_FLASH_AXIS_QSPI_ADAP_0_BASEADDR + stat_reg_off ) & ( stat_wip_mask ) );
    } while( !ready );

    // Reset
    Xil_Out32( XPAR_FLASH_AXIS_QSPI_ADAP_0_BASEADDR + cmd_reg_off, 0xFFFFFFFF & cmd_flash_NRST_mask);
    Xil_Out32( XPAR_FLASH_AXIS_QSPI_ADAP_0_BASEADDR + cmd_reg_off, mode_RD);

    while( 1 );
}