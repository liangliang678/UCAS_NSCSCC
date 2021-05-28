`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD       35

    `define FS_TO_DS_BUS_WD 129
    `define DS_TO_ES_BUS_WD 232
    `define ES_TO_MS_BUS_WD 259
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

    `define AR_IDLE          0
    `define AR_INST_OK       1
    `define AR_DATA_OK       2
    `define AR_REQ           3
    `define S_AR_IDLE        4'b0001
    `define S_AR_INST_OK     4'b0010
    `define S_AR_DATA_OK     4'b0100
    `define S_AR_REQ         4'b1000

    `define R_IDLE           0
    `define R_INST_RESP      1
    `define R_DATA_RESP      2
    `define S_R_IDLE         3'b001
    `define S_R_INST_RESP    3'b010
    `define S_R_DATA_RESP    3'b100

    `define W_IDLE           0
    `define W_REQ_OK         1
    `define W_REQ            2
    `define W_ADDR_REQ       3
    `define W_DATA_REQ       4
    `define S_W_IDLE         5'b00001
    `define S_W_REQ_OK       5'b00010
    `define S_W_REQ          5'b00100
    `define S_W_ADDR_REQ     5'b01000
    `define S_W_DATA_REQ     5'b10000

    `define B_IDLE           0
    `define B_RESP           1
    `define S_B_IDLE         2'b01
    `define S_B_RESP         2'b10
`endif
