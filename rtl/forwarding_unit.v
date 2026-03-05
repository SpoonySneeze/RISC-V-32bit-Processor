`timescale 1ns / 1ps

/*
 * -----------------------------------------------------------------------------
 * Module Name:  forwarding_unit
 * Project:      RISC V 32bit Processor
 * Date:         2026-03-05
 * * Description:
 * Implements the data forwarding (bypassing) logic required to resolve 
 * Read-After-Write (RAW) data hazards in the instruction pipeline. It dynamically 
 * compares the source registers of the instruction currently in the Execute (EX) 
 * stage against the destination registers of instructions in the subsequent 
 * Memory (MEM) and Write-Back (WB) stages, overriding the ALU inputs when a 
 * dependency is detected.
 * * Inputs:
 * - ex_rs1, ex_rs2: Source register addresses for the instruction in EX.
 * - mem_rd:         Destination register address from the EX/MEM pipeline register.
 * - mem_RegWrite:   Register write enable flag from the EX/MEM pipeline register.
 * - wb_rd:          Destination register address from the MEM/WB pipeline register.
 * - wb_RegWrite:    Register write enable flag from the MEM/WB pipeline register.
 * * Outputs:
 * - forward_a:      Multiplexer select signal for ALU Input A (00: ID/EX, 01: EX/MEM, 10: MEM/WB).
 * - forward_b:      Multiplexer select signal for ALU Input B (00: ID/EX, 01: EX/MEM, 10: MEM/WB).
 * -----------------------------------------------------------------------------
 */
module forwarding_unit (
    input  wire [4:0] ex_rs1,
    input  wire [4:0] ex_rs2,

    input  wire [4:0] mem_rd,
    input  wire       mem_RegWrite,
    
    input  wire [4:0] wb_rd, 
    input  wire       wb_RegWrite,  

    output reg  [1:0] forward_a, 
    output reg  [1:0] forward_b  
);

    // ------------------------------------------------------------------------
    // 1. Forwarding Logic for ALU Operand A (rs1)
    // ------------------------------------------------------------------------
    always @(*) begin
        // Architectural Note: Distance 1 Hazard & Zero Register Exemption
        // The EX/MEM stage represents the most recent data (Priority 1).
        // Furthermore, RISC-V architecture mandates that register x0 is hardwired 
        // to zero. Forwarding must be strictly bypassed if the destination is x0, 
        // preventing accidental propagation of non-zero data to x0 references.
        if ((mem_RegWrite) && (mem_rd != 5'b0) && (mem_rd == ex_rs1)) begin
            forward_a = 2'b01; 
        end
        // Architectural Note: Distance 2 Hazard & Priority Encoding
        // The MEM/WB stage (Priority 2) is only evaluated if no Distance 1 hazard 
        // exists. This inherently resolves the "Double Data Hazard" scenario, 
        // ensuring the ALU receives the most temporally recent architectural state.
        else if ((wb_RegWrite) && (wb_rd != 5'b0) && (wb_rd == ex_rs1)) begin
            forward_a = 2'b10;
        end
        // Default condition: No active dependencies; utilize data from ID/EX register.
        else begin
            forward_a = 2'b00;
        end
    end

    // ------------------------------------------------------------------------
    // 2. Forwarding Logic for ALU Operand B (rs2)
    // ------------------------------------------------------------------------
    // Implementation Detail: Independent Forwarding Paths
    // Operand B requires an identical, independent evaluation path to support 
    // instructions utilizing two distinct source registers (e.g., R-Type operations).
    always @(*) begin
        if ((mem_RegWrite) && (mem_rd != 5'b0) && (mem_rd == ex_rs2)) begin
            forward_b = 2'b01; 
        end
        else if ((wb_RegWrite) && (wb_rd != 5'b0) && (wb_rd == ex_rs2)) begin
            forward_b = 2'b10;
        end
        else begin
            forward_b = 2'b00;
        end
    end

endmodule
