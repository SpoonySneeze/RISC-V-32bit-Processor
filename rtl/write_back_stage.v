`timescale 1ns / 1ps

/*
 * -----------------------------------------------------------------------------
 * Module Name:  write_back_stage
 * Project:      RISC V 32bit Processor
 * Date:         2026-03-05
 * * Description:
 * Implements the final stage (WB) of the 5-stage RISC-V pipeline. This stage 
 * is responsible for selecting the final data payload to be written back to 
 * the Register File. It acts as the "Commit" point where instruction results 
 * are retired.
 * * Inputs:
 * - wb_RegWrite:   Control signal enabling the write operation.
 * - wb_MemtoReg:   Mux selector (1: Memory Data, 0: ALU Result).
 * - wb_alu_result: 32-bit data computed during the Execute stage.
 * - wb_read_data:  32-bit data retrieved from the Memory stage.
 * - wb_rd:         5-bit destination register address.
 * * Outputs:
 * - write_value:   The final 32-bit value to be stored in the Register File.
 * - out_reg_write: Verified write-enable signal (protected against x0 writes).
 * - out_rd:        The destination register address for the Write-Back operation.
 * -----------------------------------------------------------------------------
 */

module write_back_stage(
    input wire wb_RegWrite,
    input wire wb_MemtoReg,
    input wire [31:0] wb_alu_result,
    input wire [31:0] wb_read_data,
    input wire [4:0] wb_rd,
    output wire [31:0] write_value,
    output wire out_reg_write,
    output wire [4:0] out_rd
    );
    
    // Architectural Note: Write-Back Source Selection
    // This multiplexer resolves the origin of the data payload.
    // Loads (LW, LB, LH) use the wb_read_data path.
    // Computational instructions (ADD, SUB, ORI, etc.) use the wb_alu_result path.
    assign write_value = (wb_MemtoReg) ? wb_read_data : wb_alu_result;
    
    // Design Consideration: Register x0 Protection
    // In the RISC-V ISA, register x0 is hardwired to zero. 
    // This logic provides a final hardware safeguard: even if a control signal 
    // erroneously attempts to write to x0, the write-enable is suppressed here.
    assign out_reg_write = (wb_rd == 5'b0) ? 1'b0 : wb_RegWrite;

    // Pass-through of the destination address
    assign out_rd = wb_rd;

endmodule
