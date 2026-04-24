`timescale 1ns / 1ps
`include "macros.vh"

module execute(
    // Inputs from ID/EX Pipeline Register
    input [6:0] opcode,
    input [`D_SIZE-1:0] rs1_val,
    input [`D_SIZE-1:0] rs2_val,
    input [2:0] rd_in,

   // Outputs to EX/WB Pipeline Register
    output reg [`D_SIZE-1:0] alu_result,
    output [2:0] rd_out,
    output [6:0] opcode_out,
    
    // Tells the Hazard unit whether the current instruction in EX will write to registers
    output reg reg_write_en,
    
    // Outputs for JUMP
    output reg branch_taken, // signal: 1 = We need to jump
    output reg [`A_SIZE-1:0] branch_target_addr, // address where we jump
    
    // Data Memory Interface (for LOAD/STORE)
    output reg mem_write,
    output reg mem_read,
    output reg [`A_SIZE-1:0] mem_addr, // calculated address
    output reg [`D_SIZE-1:0] mem_data_out // data to write to memory (STORE)
);
    assign rd_out = rd_in;
    assign opcode_out = opcode;

always @(*) begin
    // Default values
    alu_result = 0;
    mem_write = 0;
    mem_read = 0;
    mem_addr = 0;
    mem_data_out = 0;
    reg_write_en = 0;
    
    // Default Branch signals
    branch_taken = 0;
    branch_target_addr = 0;

    case (opcode)
        `ADD: begin
            alu_result = rs1_val + rs2_val; 
            reg_write_en = 1'b1;
         end
        `SUB: begin
            alu_result = rs1_val - rs2_val;
            reg_write_en = 1'b1;
         end 
        `AND: begin
            alu_result = rs1_val & rs2_val;
            reg_write_en = 1'b1;
         end
        `OR: begin
            alu_result = rs1_val | rs2_val;
            reg_write_en = 1'b1;
         end
        `XOR: begin
            alu_result = rs1_val ^ rs2_val;
            reg_write_en = 1'b1;
         end
        `SHIFTRA: begin
            alu_result = $signed(rs1_val) >>> rs2_val;
            reg_write_en = 1'b1;
         end
        `LOAD: begin
            mem_read = 1'b1;
            mem_addr = rs1_val[`A_SIZE-1:0]; // the address is in rs1
            reg_write_en = 1'b1;
         end
        `STORE: begin
            mem_write = 1'b1;
            mem_addr = rs1_val[`A_SIZE-1:0]; // the address is in rs1
            mem_data_out = rs2_val;          // the data of writing is rs2 
            reg_write_en = 1'b0;
         end
        `JUMP: begin
            branch_taken = 1'b1;
            // seq_core: pc_next = rs1_val
            branch_target_addr = rs1_val[`A_SIZE-1:0]; 
            reg_write_en = 1'b0;
         end
        default: begin 
            alu_result = 0; 
            reg_write_en = 1'b0; 
        end
    endcase
end

endmodule