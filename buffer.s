#define ETH_BUFFERS_RX 1024
#define ETH_BUFFERS_TX 1024

.data
.balign 4
.global rxbuffer, txbuffer, rxbufferlist, txbufferlist

rxbuffer:
  .space 128*1024

txbuffer:
  .space 128*1024

rxbufferlist:
  .space 8*1024

txbufferlist:
  .space 8*1024