`timescale 1ns / 1ps
`include "macros.vh"

module pipeline_core(
    input clk,
    input rst,
    // program memory
    output [`A_SIZE-1:0] pc,
    input [15:0] instruction,
    // data memory
    output mem_read,
    output mem_write,
    output [`A_SIZE-1:0] mem_addr,
    output [`D_SIZE-1:0] mem_data_out,
    input [`D_SIZE-1:0] mem_data_in
);

// JUMP signals (connect EX with IF)
    wire ex_branch_taken;
    wire [`A_SIZE-1:0] ex_branch_target;
    
// Stall Signal from Hazard Unit
    wire hazard_stall;
    
// 1. Fetch Stage
    wire [`A_SIZE-1:0] fetch_instr_addr;
    fetch IF_MODULE (
        .clk(clk), .rst(rst),
        .branch_taken(ex_branch_taken),
        .branch_target(ex_branch_target),
        .stall(hazard_stall), // connect stall signal on PC
        .instr_addr(fetch_instr_addr)
    );
    assign pc = fetch_instr_addr; 
    
// Pipeline Register: IF -> ID 
    reg [15:0] if_id_instr;
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            if_id_instr <= `NOP; 
        end else if (ex_branch_taken) begin
            // FLUSH: If we jump, we delete the instruction that was just fetched
            if_id_instr <= `NOP;
        end else if (!hazard_stall) begin // only if it is NOT STALL, we update
            if_id_instr <= instruction;
        end
        // If it stalls, we keep the old value (freeze the instruction)
     end
    
// Hazard & Forwarding
    wire [1:0] fwd_a, fwd_b;
    wire [2:0] id_rs1_addr_out, id_rs2_addr_out;
    
// Loopback Signals (Forwarding)
    wire [`D_SIZE-1:0] ex_alu_res_loop; // the result from EX returned to ID
    
// Hazard Control Signals (Write Enables)
    wire ex_reg_write_en;     // comes from EX
    wire wb_final_write_en;   // comes from WB

// Feedback signals from WB (Data)
    wire [`D_SIZE-1:0] wb_final_data;
    wire [2:0] wb_final_rd;

// 2. Read Stage
    wire [6:0] id_opcode;
    wire [2:0] id_rd;
    wire [`D_SIZE-1:0] id_rs1_val;
    wire [`D_SIZE-1:0] id_rs2_val;
    
    read ID_MODULE (
        .clk(clk), .rst(rst),
        .instruction(if_id_instr),
        
        // Loopback Write Back
        .wb_data_in(wb_final_data),
        .wb_rd_addr(wb_final_rd),
        .wb_write_en(wb_final_write_en),
        
        // Loopback Forwarding 
        .ex_alu_result(ex_alu_res_loop), // the result "stolen" from EX
        .forward_a(fwd_a),               
        .forward_b(fwd_b),
        
        .opcode(id_opcode),
        .rd(id_rd),
        .rs1_val(id_rs1_val),
        .rs2_val(id_rs2_val),
        
        // Outputs for Hazard Unit
        .rs1_addr_out(id_rs1_addr_out),
        .rs2_addr_out(id_rs2_addr_out)
    );
               
// Pipeline Register: ID -> EX
    reg [6:0] id_ex_opcode;
    reg [2:0] id_ex_rd;
    reg [`D_SIZE-1:0] id_ex_rs1_val;
    reg [`D_SIZE-1:0] id_ex_rs2_val;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            id_ex_opcode <= `NOP;
            id_ex_rd <= 0;
            id_ex_rs1_val <= 0;
            id_ex_rs2_val <= 0;
        end else if (ex_branch_taken || hazard_stall) begin
            // Insert a Bubble (NOP) into EX to give memory time
            id_ex_opcode <= `NOP; 
            id_ex_rd <= 0; 
            id_ex_rs1_val <= 0; 
            id_ex_rs2_val <= 0;
        end else begin
            id_ex_opcode <= id_opcode;
            id_ex_rd <= id_rd;
            id_ex_rs1_val <= id_rs1_val;
            id_ex_rs2_val <= id_rs2_val;
        end
    end
    
// 3. Execute Stage
    wire [6:0] ex_opcode_out;
    wire [2:0] ex_rd_out;
    
    execute EX_MODULE (
        .opcode(id_ex_opcode),
        .rs1_val(id_ex_rs1_val),
        .rs2_val(id_ex_rs2_val),
        .rd_in(id_ex_rd),
        
        .alu_result(ex_alu_res_loop),   // output uses loopback Forwarding
        .rd_out(ex_rd_out),
        .opcode_out(ex_opcode_out),
        
        .reg_write_en(ex_reg_write_en), // new output to Hazard Unit
        
        // New Outputs Branch
        .branch_taken(ex_branch_taken),
        .branch_target_addr(ex_branch_target),
        
        .mem_write(mem_write),
        .mem_read(mem_read),
        .mem_addr(mem_addr),
        .mem_data_out(mem_data_out)
    );
  
// Pipeline Register: EX -> WB
    reg [6:0] ex_wb_opcode;
    reg [2:0] ex_wb_rd;
    reg [`D_SIZE-1:0] ex_wb_alu_result;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            ex_wb_opcode <= `NOP;
            ex_wb_rd <= 0;
            ex_wb_alu_result <= 0;
        end else begin
            ex_wb_opcode <= ex_opcode_out;
            ex_wb_rd <= ex_rd_out;
            ex_wb_alu_result <= ex_alu_res_loop;
        end
    end

// 4. Write Back Stage
    write_back WB_MODULE (
        .opcode(ex_wb_opcode),
        .alu_result(ex_wb_alu_result),
        .rd_in(ex_wb_rd),
        .mem_data_in(mem_data_in), 
        
        .wb_data(wb_final_data),         // output to ID and MUX Forwarding
        .wb_rd_addr(wb_final_rd),        // output to ID and Hazard Unit
        .wb_write_en(wb_final_write_en)  // output to ID and Hazard Unit
    );
    
// 5. Hazard Unit
    hazard_unit HAZARD_CTRL (
        // Inputs from ID 
        .rs1_id(id_rs1_addr_out),
        .rs2_id(id_rs2_addr_out),
        
        // Inputs from EX 
        .rd_ex(ex_rd_out),
        .reg_write_ex(ex_reg_write_en),
        
        // Inputs from WB
        .rd_wb(wb_final_rd),
        .reg_write_wb(wb_final_write_en),
        
        .mem_read_ex(mem_read), // Critical Signal for LOAD detection
        .pipeline_stall(hazard_stall), // Output that stops the pipeline
        
        // Outputs (order the MUXs from the ID)
        .forward_a(fwd_a),
        .forward_b(fwd_b)
    );

endmodule