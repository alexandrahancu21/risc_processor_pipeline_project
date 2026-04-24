`timescale 1ns / 1ps
`include "macros.vh"

module test_pipeline_core;
    reg clk;
    reg rst;
    
    // Signals for connecting to pipeline_core
    wire [`A_SIZE-1:0] pc;
    wire [15:0] instruction;
    
    wire mem_read, mem_write;
    wire [`A_SIZE-1:0] mem_addr;
    wire [`D_SIZE-1:0] mem_data_out; // data written to memory
    reg  [`D_SIZE-1:0] mem_data_in;  // data read from memory
    
    // Simulated memories
    reg [`D_SIZE-1:0] data_memory [0:`A_SIZE-1];
    reg [15:0] program_mem [0:31];
    
    integer i;
    
    assign instruction = (!rst) ? 16'b0 : program_mem[pc];
    
    // Read from memory (LOAD)
    always @(posedge clk) begin
        if (mem_read) begin
            mem_data_in <= data_memory[mem_addr];
        end else begin
            mem_data_in <= 32'b0;
        end
    end

    // Write to memory (STORE)
    always @(posedge clk) begin
        if (mem_write) begin
            data_memory[mem_addr] <= mem_data_out;
            $display("[MEM] Writing to address %d, Value: %h, Time: %t", mem_addr, mem_data_out, $time);
        end
    end

    pipeline_core uut (
        .clk(clk),
        .rst(rst),
        .pc(pc),
        .instruction(instruction),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_addr(mem_addr),
        .mem_data_out(mem_data_out),
        .mem_data_in(mem_data_in)
    );

    always #5 clk = ~clk;

    initial begin
 
        for (i = 0; i < 64; i = i + 1) 
            program_mem[i] = {`NOP, `R0, `R0, `R0};
        for (i = 0; i < 1024; i = i + 1) 
            data_memory[i] = 32'b0;
            
        // 0: ADD R1 = R2 + R3 (R2=1, R3=5 -> R1=6)
        program_mem[0] = {`ADD, `R1, `R2, `R3};
        
        // 1: SUB R4 = R1 - R3 (6 - 5 -> R4=1) // Depends on R1
        program_mem[1] = {`SUB, `R4, `R1, `R3};
        
        // 2: OR R2 = R4 | R3 (1 | 5 -> R2=5) 
        program_mem[2] = {`OR, `R2, `R4, `R3}; // Depends on R4

        // 3: AND R6 = R2 & R4 (5 & 1 -> R6=1)
        program_mem[3] = {`AND, `R6, `R2, `R4}; // Depends on R2
        
        // 4: ADD R4 = R1 + R2 (6 + 5 -> R4=0b)
        program_mem[4] = {`ADD, `R4, `R1, `R2};
 
        // 5: XOR R7 = R3 ^ R4 (5 ^ 0b -> R7=0e) // Depends on R4 (calculated in instr 4)
        program_mem[5] = {`XOR, `R7, `R3, `R4};
        
        // 6: LOAD R1 = mem[R3] (mem[5])
        // R3 is 5. At address 5 in memory we will manually put a value.
        program_mem[6] = {`LOAD, `R1, `R3, `R0};
        
        // 7: STORE mem[R6] = R1 (mem[1] = Previously loaded value)
        // Depends on R1 loaded
        program_mem[7] = {`STORE, `R0, `R6, `R1};
        
        // 8: Jump to the address 5
        program_mem[8] = {`JUMP, `R0, `R3, `R0};
        
        // 9: SHIFTRA R5 = R1 >>> R4
        program_mem[9] = {`SHIFTRA, `R5, `R1, `R4};
        
        // 10: LOAD R2 = mem[R6] (Reading back from address 1)
        // R6 is still 1. We should load BABACAFE into R2.
        program_mem[10] = {`LOAD, `R2, `R6, `R0};
        
        // 11: HALT (infinity loop here)
        program_mem[11] = {`HALT, `R0, `R0, `R0};
       
        clk = 0;
        rst = 0;
        
        #1; 
        rst = 0;
        #10;
        rst = 1; // Release reset
        
        // Inject initial values into registers directly in the ID module (for simulation only)
        // R2 = 1, R3 = 5, R4 = 2 (initial), Mem[5] = BABACAFE
        uut.ID_MODULE.reg_file[2] = 32'd1;
        uut.ID_MODULE.reg_file[3] = 32'd5;
        uut.ID_MODULE.reg_file[4] = 32'd2; 
        
        // Initialize Data Memory
        data_memory[1] = 32'hBABACADE;
        data_memory[5] = 32'hBABACAFE;
        
        #300;
        $display("Simulation over");
        $finish;
    end

    initial begin
        $monitor("Time=%t | PC=%d | IF_Instr=%h | EX_Res=%h | WB_Data=%h | WB_Reg=%d | WB_En=%b",
                 $time, pc, instruction, uut.ex_alu_res_loop, uut.wb_final_data, uut.wb_final_rd, uut.wb_final_write_en);
    end

endmodule