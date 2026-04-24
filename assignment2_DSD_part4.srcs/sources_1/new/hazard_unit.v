`timescale 1ns / 1ps

module hazard_unit(
    // Inputs (Addresses of registers we check)
    input [2:0] rs1_id, // Source 1 from read stage
    input [2:0] rs2_id, // Source 2 from read stage

    input [2:0] rd_ex, // Destination from Execute stage
    input reg_write_ex, 
    input mem_read_ex, //  Signal that the instruction in EX is LOAD

    input [2:0] rd_wb, // Destination from WriteBack stage
    input reg_write_wb, 

    // Outputs (Control signals for MUXs in ID)
    // 00 = RegFile, 01 = Forward from WB, 10 = Forward from EX
    output reg [1:0] forward_a,
    output reg [1:0] forward_b,
    output reg pipeline_stall // "Freeze" signal
);

always @(*) begin
// Forwarding for Source 1 (rs1)
    forward_a = 2'b00; // Default: take from registers

// Check Hazard with EX
// If the instruction in EX has just computed a result and is writing to a register that we need as Source 1 NOW -> FORWARD FROM EX
    if ((reg_write_ex) && (rd_ex == rs1_id)) begin
        forward_a = 2'b10;
    end
    
// Check Hazard with WB
// If the instruction in WB has finished calculating a value and is writing to a register that we need as Source 1 NOW -> FORWARD FROM WB
    else if ((reg_write_wb) && (rd_wb == rs1_id)) begin
        forward_a = 2'b01;
    end

// Forwarding for Source 2 (rs2)
    forward_b = 2'b00; // Default 
// If the instruction in EX has just computed a result and is writing to a register that we need as Source 2 NOW -> FORWARD FROM EX
    if ((reg_write_ex) && (rd_ex == rs2_id)) begin 
        forward_b = 2'b10; 
    end 
// If the instruction in WB has finished calculating a value and is writing to a register that we need as Source 2 NOW -> FORWARD FROM WB
    else if ((reg_write_wb) && (rd_wb == rs2_id)) begin 
        forward_b = 2'b01; 
    end 
    
// Logic Stall (Load-Use Hazard)
// If the instruction in EX reads from memory (LOAD) and is about to write to a register that we need NOW in ID -> STALL
    pipeline_stall = 1'b0;
    if (mem_read_ex == 1'b1 && ((rd_ex == rs1_id) || (rd_ex == rs2_id))) begin
        pipeline_stall = 1'b1;
    end
end
endmodule