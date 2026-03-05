`timescale 1ns / 1ps

/*
 * -----------------------------------------------------------------------------
 * Module Name:  control_unit
 * Project:      RISC V 32bit Processor
 * Date:         2026-03-05
 * * Description:
 * The primary instruction decoder. It evaluates the 7-bit opcode from the 
 * fetched instruction and asserts the proper control signals to route data 
 * through the processor's multiplexers, memory, and registers. 
 * * Inputs:
 * - opcode:     7-bit opcode field (instr[6:0])
 * * Outputs:
 * - reg_write:  Enables writing to the register file
 * - mem_to_reg: Selects Data Memory (1) or ALU Output (0) for register writeback
 * - mem_read:   Enables reading from Data Memory
 * - mem_write:  Enables writing to Data Memory
 * - branch:     Flags a branch instruction (combined with ALU zero flag later)
 * - jump:       Flags an unconditional jump (JAL, JALR)
 * - op_a_sel:   Selects ALU Input A (00=RS1, 01=PC, 10=Zero)
 * - alu_src:    Selects ALU Input B (0=RS2, 1=Immediate)
 * - alu_op:     2-bit code passed to the ALU Control unit
 * -----------------------------------------------------------------------------
 */
module control_unit(
    input  wire [6:0] opcode,

    output reg        reg_write,
    output reg        mem_to_reg,
    output reg        mem_read,
    output reg        mem_write,
    output reg        branch,
    output reg        jump,
    output reg  [1:0] op_a_sel,  // Multiplexer control for ALU Input A
    output reg        alu_src,   // Multiplexer control for ALU Input B
    output reg  [1:0] alu_op     // Operation category for ALU Control
);

    always @(*) begin
        // ---------------------------------------------------------------------
        // GOTCHA: Default Assignments
        // We assign a default value to EVERY output right at the top. 
        // If we don't do this, any unspecified signal in a case statement 
        // will infer a latch, which causes timing nightmares in FPGAs/ASICs.
        // ---------------------------------------------------------------------
        reg_write  = 0; 
        mem_to_reg = 0; 
        mem_read   = 0; 
        mem_write  = 0;
        branch     = 0; 
        jump       = 0; 
        alu_src    = 0;      // Default B = Reg2 (rs2_data)
        op_a_sel   = 2'b00;  // Default A = Reg1 (rs1_data)
        alu_op     = 2'b00;

        case(opcode)
            // Load Word (LW, LB, LH, etc.)
            7'b0000011: begin
                reg_write  = 1; 
                mem_to_reg = 1; 
                mem_read   = 1; 
                alu_src    = 1;      // B = Immediate (Offset)
                alu_op     = 2'b00;  // ADD (Base + Offset)
            end

            // I-Type Arithmetic (ADDI, SLTI, XORI, etc.)
            7'b0010011: begin
                reg_write = 1; 
                alu_src   = 1;       // B = Immediate
                alu_op    = 2'b11;   // Delegate specific operation to ALU Control
            end

            // Store Word (SW, SB, SH)
            7'b0100011: begin
                mem_write = 1; 
                alu_src   = 1;       // B = Immediate (Offset)
                alu_op    = 2'b00;   // ADD (Base + Offset)
            end

            // R-Type Arithmetic (ADD, SUB, AND, etc.)
            7'b0110011: begin
                reg_write = 1; 
                // A=Reg1, B=Reg2 are handled by defaults above
                alu_op    = 2'b10;   // Delegate specific operation to ALU Control
            end

            // Branch Instructions (BEQ, BNE, BLT, etc.)
            7'b1100011: begin
                branch = 1; 
                // A=Reg1, B=Reg2 are handled by defaults above
                alu_op = 2'b01;      // Let ALU Control determine SUB or Compare
            end
            
            // LUI (Load Upper Immediate)
            //  LUI simply loads an immediate into a register. We trick
            // the ALU into doing this by adding 0 to the Immediate.
            7'b0110111: begin
                reg_write = 1;
                op_a_sel  = 2'b10;   // A = Zero (Hardwired 0)
                alu_src   = 1;       // B = Immediate
                alu_op    = 2'b00;   // ADD (0 + Imm)
            end

            // AUIPC (Add Upper Immediate to PC)
            //  Needs to add the immediate to the current PC, not a register.
            7'b0010111: begin
                reg_write = 1;
                op_a_sel  = 2'b01;   // A = Program Counter (PC)
                alu_src   = 1;       // B = Immediate
                alu_op    = 2'b00;   // ADD (PC + Imm)
            end

            // JAL (Jump and Link)
            // Note: Datapath must route (PC+4) to the register file 'write_data',
            // while the ALU calculates the jump target address.
            7'b1101111: begin
                jump      = 1;
                reg_write = 1;
                op_a_sel  = 2'b01;   // A = Program Counter (PC)
                alu_src   = 1;       // B = Immediate
                alu_op    = 2'b00;   // ADD (PC + Imm) -> Jump Target
            end
            
            // JALR (Jump and Link Register)
            7'b1100111: begin
                jump      = 1; 
                reg_write = 1;
                op_a_sel  = 2'b00;   // A = RS1 Data
                alu_src   = 1;       // B = Immediate
                alu_op    = 2'b00;   // ADD (RS1 + Imm) -> Jump Target
            end
            
            // Default case to catch invalid opcodes and prevent latches
            default: begin
                // All signals remain at 0 via the defaults at the top
            end
        endcase
    end
endmodule
