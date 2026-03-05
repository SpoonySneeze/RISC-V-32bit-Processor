`timescale 1ns / 1ps

/*
 * -----------------------------------------------------------------------------
 * Module Name:  alu_control
 * Project:      RISC V 32bit Processor
 * Date:         2026-03-05
 * * Description:
 * This module acts as a secondary decoder for the ALU. It takes the high-level 
 * 2-bit 'ALUOp' signal from the main Control Unit and combines it with the 
 * instruction's 'funct3' and 'funct7' fields to generate the specific 5-bit 
 * control signal required by the ALU.
 * * Inputs:
 * - ALUOp:       2-bit signal from main control (00=Mem, 01=Branch, 10/11=R/I-Type)
 * - funct3:      3-bit function field from the instruction (instr[14:12])
 * - funct7:      7-bit function field from the instruction (instr[31:25])
 * * Outputs:
 * - alu_control: 5-bit operation code sent directly to the ALU
 * -----------------------------------------------------------------------------
 */
module alu_control(
    input  wire [1:0] ALUOp,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg  [4:0] alu_control
);

    // Combinational block to determine the exact ALU operation
    always @(*) begin
        case (ALUOp)
            // Case 1: Load/Store (lw, sw)
            // The ALU must perform an ADD to calculate the memory address.
            2'b00: begin
                alu_control = 5'b00000; // ADD
            end

            // Case 2: Branch Instructions
            // The ALU performs subtractions or comparisons to resolve branches.
            2'b01: begin
                case (funct3)
                    3'b000, 3'b001: alu_control = 5'b00001; // BEQ, BNE -> SUB
                    3'b100, 3'b101: alu_control = 5'b10100; // BLT, BGE -> SLT (Signed compare)
                    3'b110, 3'b111: alu_control = 5'b10101; // BLTU, BGEU -> SLTU (Unsigned compare)
                    default:        alu_control = 5'b00000;
                endcase
            end

            // Case 3: I/R-type Instructions
            // We need to look at funct3 and funct7 to determine the specific operation.
            2'b10, 2'b11: begin
                case (funct3)
                    3'b000: begin 
                        // If it is R-Type (ALUOp=10) AND bit 30 (funct7[5]) is 1, it's SUB.
                        // For I-Type (ALUOp=11) or when bit 30 is 0, it's ADD.
                        if (ALUOp == 2'b10 && funct7[5] == 1'b1) begin
                            alu_control = 5'b00001; // SUB (SUBTRACT)
                        end else begin
                            alu_control = 5'b00000; // ADD / ADDI (ADD) 
                        end
                    end
                    3'b001: alu_control = 5'b10001; // SLL / SLLI (Shift Left Logical)
                    3'b010: alu_control = 5'b10100; // SLT / SLTI (Set Less Than, Signed)
                    3'b011: alu_control = 5'b10101; // SLTU / SLTIU (Set Less Than, Unsigned)
                    3'b100: alu_control = 5'b00100; // XOR / XORI (Exclusive OR)
                    3'b101: begin 
                        // Differentiate between Logical and Arithmetic right shifts using bit 30
                        if (funct7[5] == 1'b0) begin
                            alu_control = 5'b10110; // SRL / SRLI (Shift Right Logical)
                        end else begin
                            alu_control = 5'b10111; // SRA / SRAI (Shift Right Arithmetic)
                        end
                    end
                    3'b111: alu_control = 5'b00111; // AND / ANDI (Bitwise AND)
                    default: alu_control = 5'b00000; // Default to prevent inferred latches
                endcase
            end

            // Default case to prevent latches for any unknown ALUOp values
            default: begin
                alu_control = 5'b00000;
            end
        endcase
    end

endmodule
