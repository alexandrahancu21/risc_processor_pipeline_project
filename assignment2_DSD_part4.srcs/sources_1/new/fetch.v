`timescale 1ns / 1ps
`include "macros.vh"

module fetch(
    input clk,
    input rst,
    input branch_taken, // signal: jump to given address
    input [`A_SIZE-1:0] branch_target, // jump address
    input stall, // stop signal
    output [`A_SIZE-1:0] instr_addr
);
reg [`A_SIZE-1:0] pc;

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        pc <= 0;
    end else begin
        if (branch_taken) begin
            pc <= branch_target;
        end else if (!stall) begin
            pc <= pc + 1;
        end
        // If it stalls, PC stays at the same value (pc <= pc)    
        end
end

assign instr_addr = pc;

endmodule