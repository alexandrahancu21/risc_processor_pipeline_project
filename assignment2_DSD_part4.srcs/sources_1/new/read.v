`timescale 1ns / 1ps
`include "macros.vh"

module read (
    input clk,
    input rst,
    input [15:0] instruction,
    
    // Signals from Write Back 
    input [`D_SIZE-1:0] wb_data_in, // the data coming from the WB Stage to be written
    input [2:0] wb_rd_addr,
    input wb_write_en,
    
    // Inputs for Forwarding (data "stolen" from the route)
    input [`D_SIZE-1:0] ex_alu_result, // result from the EX stage (for Forwarding)
    input [1:0] forward_a, // MUX A selector
    input [1:0] forward_b, // MUX B selector
    
    // Outputs to Pipeline Register ID/EX
    output [6:0] opcode,
    output [2:0] rd,
    output [`D_SIZE-1:0] rs1_val, // final Value after MUX
    output [`D_SIZE-1:0] rs2_val, // final Value after MUX

    // Outputs needed for Hazard Unit
    output [2:0] rs1_addr_out,
    output [2:0] rs2_addr_out
);
    // Register File intern 
    reg [`D_SIZE-1:0] reg_file [0:7];
    integer i;

    // Decoding instruction 
    assign opcode = instruction[15:9];
    assign rd     = instruction[8:6];
    
    // Extract the source addresses and send them out (for Hazard Unit)
    wire [2:0] rs1_addr = instruction[5:3];
    wire [2:0] rs2_addr = instruction[2:0];

    // Asynchronous (combinational) reading from registers
    assign rs1_addr_out = rs1_addr;
    assign rs2_addr_out = rs2_addr;
    
    // Read value from Registers
    wire [`D_SIZE-1:0] rdata1 = reg_file[rs1_addr];
    wire [`D_SIZE-1:0] rdata2 = reg_file[rs2_addr];
    
    // Forwarding MUXs 
    // Selects the correct source based on the signals from the Hazard Unit

    // For rs1
    assign rs1_val = (forward_a == 2'b10) ? ex_alu_result : // take from EX
    (forward_a == 2'b01) ? wb_data_in : // take from WB
    rdata1; // take from Register

    // For rs2
    assign rs2_val = (forward_b == 2'b10) ? ex_alu_result :
    (forward_b == 2'b01) ? wb_data_in :
    rdata2;

    // Synchronous write to registers (Write Back)
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            for (i = 0; i < 8; i = i + 1) 
                reg_file[i] <= 0;
        end else if (wb_write_en) begin
            reg_file[wb_rd_addr] <= wb_data_in; 
        end
    end

endmodule