`timescale 1ns / 1ps

/*
 * -----------------------------------------------------------------------------
 * Module Name:  alu
 * Project:      RISC V 32bit Processor
 * Date:         2026-03-05
 * * Description:
 * This module is the core computational unit of the processor. It takes two 
 * 32-bit operands and executes arithmetic, logical, shift, or comparison 
 * operations based on a 5-bit control signal. The zero flag output is primarily 
 * used by the control unit to resolve branch instructions (e.g., BEQ, BNE).
 * * Inputs:
 * - a:           32-bit operand A (typically rs1 data)
 * - b:           32-bit operand B (typically rs2 data or immediate value)
 * - alu_control: 5-bit control signal specifying the operation to perform
 * * Outputs:
 * - result:      32-bit result of the computation
 * - zero:        High (1) if the result is exactly zero, otherwise Low (0)
 * -----------------------------------------------------------------------------
 */
module alu(
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [4:0]  alu_control,
    output reg  [31:0] result,
    output wire        zero
);

    // Combinational block to calculate the result based on the control signal
    always @(*) begin
        case (alu_control)
            5'b00000: result = a + b;                        // ADD
            5'b00001: result = a - b;                        // SUBTRACT
            5'b10001: result = a << b[4:0];                  // SLL (Shift Left Logical)
            5'b10100: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // SLT (Set Less Than, Signed)
            5'b10101: result = (a < b) ? 32'd1 : 32'd0;      // SLTU (Set Less Than, Unsigned)
            5'b00100: result = a ^ b;                        // XOR
            5'b10110: result = a >> b[4:0];                  // SRL (Shift Right Logical)
            5'b10111: result = $signed(a) >>> b[4:0];        // SRA (Shift Right Arithmetic)
            5'b00110: result = a | b;                        // OR
            5'b00111: result = a & b;                        // AND
            default:  result = 32'b0;                        // Default to 0 to prevent inferred latches
        endcase
    end

    // Flag generation for branch resolution
    assign zero = (result == 32'b0);

endmodule