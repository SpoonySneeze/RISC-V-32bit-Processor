`timescale 1ns / 1ps

/*
 * -----------------------------------------------------------------------------
 * Module Name:  ex_mem_register
 * Project:      RISC V 32bit Processor
 * Date:         2026-03-05
 * * Description:
 * Implements the synchronous pipeline register between the Execute (EX) and 
 * Memory (MEM) stages. It preserves the state of an instruction—including 
 * calculated addresses, data to be stored, and propagation control signals—
 * across the clock boundary.
 * * Inputs:
 * - clk, reset:     System clock and synchronous active-high reset.
 * - ex_RegWrite...: Control signals propagating to the MEM and WB stages.
 * - ex_rs1...:      Source and destination register identifiers.
 * - ex_alu_result:  Computed data or memory address from the EX stage.
 * - ex_write_data:  Data payload intended for data memory (for store operations).
 * * Outputs:
 * - mem_RegWrite...: Latched signals available to the MEM stage.
 * -----------------------------------------------------------------------------
 */
module ex_mem_register(
    input  wire        clk,
    input  wire        reset,

    // Inputs from the EX stage
    input  wire        ex_RegWrite,
    input  wire        ex_MemtoReg,
    input  wire        ex_MemWrite,
    input  wire        ex_MemRead,
    
    input  wire [4:0]  ex_rs1,
    input  wire [4:0]  ex_rs2,
    input  wire [4:0]  ex_rd,
    input  wire [2:0]  ex_funct3,
    
    // Execute stage produced values
    input  wire [31:0] ex_alu_result,
    input  wire [31:0] ex_write_data,
    input  wire        ex_zero_flag,

    // Outputs to the MEM stage
    output reg         mem_RegWrite,
    output reg         mem_MemtoReg,
    output reg         mem_MemWrite,
    output reg         mem_MemRead,
    
    output reg  [4:0]  mem_rs1,
    output reg  [4:0]  mem_rs2,
    output reg  [4:0]  mem_rd,
    output reg  [2:0]  mem_funct3,
    
    // Execute stage latched outputs
    output reg  [31:0] mem_alu_result,
    output reg  [31:0] mem_write_data,
    output reg         mem_zero_flag
);

    // Architectural Note: Synchronous State Preservation
    // Pipeline registers isolate combinational logic stages. On every rising 
    // clock edge, the outputs of the EX stage are sampled and held stable for 
    // the MEM stage to use during the subsequent clock cycle.
    always @(posedge clk) begin
        if (reset) begin
            // Design Consideration: Safe Reset State
            // All control signals are forced to zero to prevent unintended 
            // memory writes or register file modifications during system reset.
            mem_RegWrite   <= 1'b0;
            mem_MemtoReg   <= 1'b0;
            mem_MemWrite   <= 1'b0;
            mem_MemRead    <= 1'b0;
            mem_rs1        <= 5'b0;
            mem_rs2        <= 5'b0;
            mem_rd         <= 5'b0;
            mem_alu_result <= 32'b0;
            mem_write_data <= 32'b0;
            mem_zero_flag  <= 1'b0;
            mem_funct3     <= 3'b0;
        end
        else begin
            // Normal execution data propagation
            mem_RegWrite   <= ex_RegWrite;
            mem_MemtoReg   <= ex_MemtoReg;
            mem_MemWrite   <= ex_MemWrite;
            mem_MemRead    <= ex_MemRead;
            
            mem_rs1        <= ex_rs1;
            mem_rs2        <= ex_rs2;
            mem_rd         <= ex_rd;
            mem_funct3     <= ex_funct3;
            
            mem_alu_result <= ex_alu_result;
            mem_write_data <= ex_write_data;
            mem_zero_flag  <= ex_zero_flag;
        end
    end

endmodule
