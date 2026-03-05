`timescale 1ns / 1ps

/*
 * -----------------------------------------------------------------------------
 * Module Name:  id_ex_register
 * Project:      RISC V 32bit Processor
 * Date:         2026-03-05
 * * Description:
 * Implements the synchronous pipeline register separating the Instruction Decode 
 * (ID) and Execute (EX) stages. It latches the decoded control signals, register 
 * operands, immediate payloads, and program counter values. Furthermore, it 
 * propagates architectural metadata (source/destination register addresses) 
 * required by downstream forwarding and hazard detection units.
 * * Inputs:
 * - clk, reset:    System clock and global synchronous reset.
 * - flush:         Control hazard mitigation signal used to dynamically clear the stage.
 * - id_*:          Decoded control signals, data, and metadata from the ID stage.
 * * Outputs:
 * - ex_*:          Latched state elements provided to the EX, MEM, and WB stages.
 * -----------------------------------------------------------------------------
 */
module id_ex_register(
    input  wire        clk,
    input  wire        reset,
    input  wire        flush,

    // --- Inputs from ID Stage ---

    // Control Signals (Propagating to MEM/WB stages)
    input  wire        id_RegWrite,
    input  wire        id_MemtoReg,
    input  wire        id_MemRead,
    input  wire        id_MemWrite,
    
    // Control Signals (Consumed by the EX Stage)
    input  wire        id_Branch,
    input  wire        id_Jump,      
    input  wire [1:0]  id_op_a_sel, 
    input  wire        id_ALUSrc,
    input  wire [1:0]  id_ALUOp,

    // Data Payloads
    input  wire [31:0] id_read_data_1,
    input  wire [31:0] id_read_data_2,
    input  wire [31:0] id_immediate,
    
    // Architectural Addresses
    input  wire [4:0]  id_rs1,
    input  wire [4:0]  id_rs2,
    input  wire [31:0] id_pc_plus_4,

    // Architectural Metadata for Hazard Resolution
    input  wire [4:0]  id_rd,
    input  wire [2:0]  id_funct3,
    input  wire [6:0]  id_funct7,
    
    // --- Outputs to EX Stage ---

    // Control Signals
    output reg         ex_RegWrite,
    output reg         ex_MemtoReg,
    output reg         ex_Branch,
    output reg         ex_Jump,      
    output reg  [1:0]  ex_op_a_sel, 
    output reg         ex_MemRead,
    output reg         ex_MemWrite,
    output reg         ex_ALUSrc,
    output reg  [1:0]  ex_ALUOp,

    // Data Payloads
    output reg  [31:0] ex_read_data_1,
    output reg  [31:0] ex_read_data_2,
    output reg  [31:0] ex_immediate,
    
    // Architectural Addresses
    output reg  [4:0]  ex_rs1,
    output reg  [4:0]  ex_rs2,
    output reg  [31:0] ex_pc_plus_4,
    
    // Architectural Metadata
    output reg  [4:0]  ex_rd,
    output reg  [2:0]  ex_funct3,
    output reg  [6:0]  ex_funct7
);

    always @(posedge clk) begin
        // Architectural Note: Control Hazard Mitigation (Pipeline Flushing)
        // If a branch is taken or a jump is executed, the instruction currently 
        // in the ID stage was fetched speculatively and is incorrect. Asserting 
        // the 'flush' signal zero-fills this register, effectively converting the 
        // invalid instruction into a hardware NOP (No Operation) to maintain 
        // architectural correctness.
        if (reset || flush) begin
            ex_RegWrite    <= 1'b0;
            ex_MemtoReg    <= 1'b0;
            ex_Branch      <= 1'b0;
            ex_Jump        <= 1'b0;
            ex_op_a_sel    <= 2'b00; 
            ex_MemRead     <= 1'b0;
            ex_MemWrite    <= 1'b0;
            ex_ALUSrc      <= 1'b0;
            ex_ALUOp       <= 2'b00;
            
            ex_read_data_1 <= 32'b0;
            ex_read_data_2 <= 32'b0;
            ex_immediate   <= 32'b0;
            
            ex_rs1         <= 5'b0;
            ex_rs2         <= 5'b0;
            ex_pc_plus_4   <= 32'b0;
            
            ex_rd          <= 5'b0;
            ex_funct3      <= 3'b0;
            ex_funct7      <= 7'b0;
        end
        else begin
            // Synchronous State Propagation
            ex_RegWrite    <= id_RegWrite;
            ex_MemtoReg    <= id_MemtoReg;
            ex_Branch      <= id_Branch;
            ex_Jump        <= id_Jump;
            ex_op_a_sel    <= id_op_a_sel; 
            ex_MemRead     <= id_MemRead;
            ex_MemWrite    <= id_MemWrite;
            ex_ALUSrc      <= id_ALUSrc;
            ex_ALUOp       <= id_ALUOp;

            ex_read_data_1 <= id_read_data_1;
            ex_read_data_2 <= id_read_data_2;
            ex_immediate   <= id_immediate;
            
            // Design Consideration: Hazard Metadata Forwarding
            // rs1 and rs2 are passed to the EX stage specifically so the 
            // Forwarding Unit can compare them against the destination registers 
            // of the MEM and WB stages to dynamically route bypassed data.
            ex_rs1         <= id_rs1;
            ex_rs2         <= id_rs2;
            ex_pc_plus_4   <= id_pc_plus_4;
            
            ex_rd          <= id_rd;
            ex_funct3      <= id_funct3;
            ex_funct7      <= id_funct7;
        end
    end

endmodule
