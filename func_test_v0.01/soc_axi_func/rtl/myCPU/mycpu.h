`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD       35

    `define PF_TO_FS_BUS_WD 75
    `define FS_TO_DS_BUS_WD 129
    `define DS_TO_ES_BUS_WD 232
    `define ES_TO_MS_BUS_WD 291
    `define MS_TO_WS_BUS_WD 149

    `define WS_TO_RF_BUS_WD 38

    `define STALL_ES_BUS_WD 50
    `define STALL_MS_BUS_WD 49
    `define STALL_WS_BUS_WD 48

    `define EXCEPTION_ADEL          0
    `define EXCEPTION_ADES          1
    `define EXCEPTION_INT_OVERFLOW  2
    `define EXCEPTION_SYSCALL       3
    `define EXCEPTION_BREAK         4
    `define EXCEPTION_RESERVE       5
    `define EXCEPTION_INT           6

`endif
