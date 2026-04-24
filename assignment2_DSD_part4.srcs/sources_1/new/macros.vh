`define A_SIZE  10
`define D_SIZE  32

// opcodes (7 bits)
`define NOP     7'b0000000
`define	ADD     7'b0000001
`define SUB     7'b0000010
`define AND     7'b0000011
`define OR      7'b0000100
`define XOR     7'b0000101
`define LOAD    7'b0001000 
`define STORE   7'b0001001 
`define JUMP    7'b0010000
`define HALT    7'b0010001
`define SHIFTRA 7'b0010010

// register definition (3 bits)
`define R0      3'd0
`define R1      3'd1
`define R2      3'd2
`define R3      3'd3
`define R4      3'd4
`define R5      3'd5
`define R6      3'd6
`define R7      3'd7
