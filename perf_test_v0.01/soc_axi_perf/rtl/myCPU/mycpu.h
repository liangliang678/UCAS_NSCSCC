`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD          35

    `define PF_TO_FS_BUS_WD    39
    `define FS_TO_DS_BUS_WD    869
    `define DS_TO_ES_BUS_WD    389
    `define ES_TO_PMS_BUS_WD   631
    `define PMS_TO_MS_BUS_WD   227
    `define MS_TO_WS_BUS_WD    141

    `define WS_TO_RF_BUS_WD    76

    `define DS_FORWARD_BUS_WD  13
    `define ES_FORWARD_BUS_WD  81
    `define PMS_FORWARD_BUS_WD 79
    `define MS_FORWARD_BUS_WD  81
    `define WS_FORWARD_BUS_WD  77

    `define EXCEPTION_ADEL          0
    `define EXCEPTION_ADES          1
    `define EXCEPTION_INT_OVERFLOW  2
    `define EXCEPTION_SYSCALL       3
    `define EXCEPTION_BREAK         4
    `define EXCEPTION_RESERVE       5
    `define EXCEPTION_INT           6

    `define CR_STATUS    8'b01100000
    `define CR_CAUSE     8'b01101000
    `define CR_EPC       8'b01110000
    `define CR_COUNT     8'b01001000
    `define CR_COMPARE   8'b01011000
    `define CR_BADADDR   8'b01000000
    `define CR_ENTRYHI   8'b01010000
    `define CR_ENTRYLO0  8'b00010000
    `define CR_ENTRYLO1  8'b00011000
    `define CR_INDEX     8'b00000000


`endif
