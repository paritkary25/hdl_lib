The IP sends the data in the following format:
* [63:48] 0x"b01d"
* [47:32] Transaction counter (incremented after every start)
* [31:24] Number of packets
* [23:16] Number of frames per packet
* [15: 8] Current packet counter (starting from 0)
* [ 7: 0] Current frame counter (starting from 0)

A packet is defined by TLAST. So, if the burst length is 4, then every 4 frames, TLAST will be sent. If the burst length is 8, then every 8 frames, TLAST will be sent.

How to configure the burst:
1. Set the number of packets and frames per packet in the AXI4Lite register (0x00 and 0x04)
2. Start by performing a write transaction to the AXI4Lite register (0x0C) with any value.

Status of the burst can be accessed by reading the AXI4Lite register 0x10. This register stores the last generated frame.

## AXI4Lite Register Map:
| Address | RW | Name           | Description                         |
|---------|----|----------------|-------------------------------------|
| 0x00    | RW | NUM_PKT        | Number of packets to be sent       |
| 0x04    | RW | NUM_FRAMES     | Number of frames per packet        |
| 0x08    | RW | CONFIG         | [0]: enable TLAST. [31:16]: data density |
| 0x0C    | RW | START          | Write anything to trigger the xfr   |
| 0x10    | RO | LAST_FRAME     | Last generated frame (lower word)               |
| 0x14    | RO | LAST_FRAME     | Last generated frame (upper word)                |
| 0x18    | RO | STATUS         | Status register (1: Transaction in Progress, 0: Idle ) |

Characteristics: 
* An internal transaction counter, incremented after every start
* Arbitrary burst size of upto 256 is supported
* Upto 256 packets can be sent
* Variable frame width is supported
    * For frame width > 64 bits, the data is appended with 0s
    * For frame width < 64 bits, the MSBs are truncated (see frame format)
* Data density is configurable via CONFIG[31:16]: after that many back-to-back
  transfers, a single bubble cycle (tvalid = 0) is inserted before resuming.
  A value of 0 disables bubble insertion.

Additional notes:
* TSTRB/TKEEP is not used.
* Do not change configuration while the burst is ongoing. This may lead to undefined behaviour.

