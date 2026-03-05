`timescale 1ns / 1ps

/*
 * -----------------------------------------------------------------------------
 * Module Name:  immediate_generator
 * Project:      RISC V 32bit Processor
 * Date:         2026-03-05
 * * Description:
 * This module extracts and sign-extends the immediate values from various 
 * RISC-V instruction formats (I, S, B, J, U)
 * * Inputs:
 * - instruction: 32-bit instruction word
 * * Outputs:
 * - immediate:   32-bit sign-extended immediate value
 * -----------------------------------------------------------------------------
 */
module immediate_generator(
    input  wire [31:0] instruction,
    output reg  [31:0] immediate
);
    always @(*) begin
        case (instruction[6:0])
            // I-Type Instructions (e.g., LW, ADDI, JALR) 
            // Implementation Detail: The 12-bit immediate is found in the top 12 bits 
            // of the instruction and is sign-extended to 32 bits.
            7'b0000011, 
            7'b0010011, 
            7'b1100111: begin 
                immediate = {{20{instruction[31]}}, instruction[31:20]}; 
            end

            // S-Type Instructions (e.g., SW) [cite: 113]
            // Design Consideration: The immediate is split between instruction[31:25] 
            // and instruction[11:7] to maintain source register positioning.
            7'b0100011: begin 
                immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]}; // [cite: 113]
            end

            // B-Type Instructions (e.g., BEQ, BNE) 
            // Architectural Note: The immediate represents a memory offset. The LSB is 
            // implicitly zero, creating a 13-bit signed offset.
            7'b1100011: begin 
                immediate = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0}; 
            end
            
            // J-Type Instructions (e.g., JAL) 
            // Architectural Note: Similar to B-Type, the LSB is implicitly zero. The 
            // bits are scrambled in the instruction encoding to minimize multiplexer 
            // complexity in the hardware design.
            7'b1101111: begin
                immediate = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
            end
            
            // U-Type Instructions (e.g., LUI, AUIPC) 
            7'b0110111, 
            7'b0010111: begin 
                immediate = {instruction[31:12], 12'b0}; 
            end

            default: begin
                immediate = 32'b0; 
            end
        endcase
    end
endmodule
