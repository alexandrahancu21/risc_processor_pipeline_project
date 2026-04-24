`timescale 1ns / 1ps
`include "macros.vh"

module write_back(
    // Inputs from EX/WB Pipeline Register
    input [6:0] opcode,
    input [`D_SIZE-1:0] alu_result,
    input [2:0] rd_in,
    // Input from Data Memory
    input [`D_SIZE-1:0] mem_data_in,
    // Outputs to ID Stage (Loopback)
    output reg [`D_SIZE-1:0] wb_data,
    output [2:0] wb_rd_addr,
    output reg wb_write_en
);

    assign wb_rd_addr = rd_in;

    always @(*) begin
        wb_write_en = 1'b0;
        wb_data = 32'b0;

        case (opcode)
            `ADD, `SUB, `AND, `OR, `XOR, `SHIFTRA: begin
                wb_write_en = 1'b1;
                wb_data = alu_result;
            end
            `LOAD: begin
                wb_write_en = 1'b1;
                wb_data = mem_data_in; // select the data from memory 
            end
            // STORE, JUMP, HALT do not write into registers
            default: wb_write_en = 1'b0;
        endcase
    end
endmodule