`timescale 1ns / 1ps

/*
 * -----------------------------------------------------------------------------
 * Module Name:  execute_stage
 * Project:      RISC V 32bit Processor
 * Date:         2026-03-05
 * * Description:
 * Implements the Execute (EX) stage of the pipeline. This module is responsible 
 * for arithmetic and logical computations, branch condition evaluation, and 
 * resolving Read-After-Write (RAW) data hazards via forwarding multiplexers. 
 * It also calculates target addresses for branch and jump instructions.
 * * Inputs:
 * - ex_RegWrite...: Control signals propagated from the ID/EX register.
 * - ex_op_a_sel:    Multiplexer control for ALU Input A (00=RS1, 01=PC, 10=Zero).
 * - forward_a/b:    Forwarding control signals from the Hazard Detection Unit.
 * - mem_alu_result: Forwarded data from the EX/MEM stage (Distance 1).
 * - wb_alu_result:  Forwarded data from the MEM/WB stage (Distance 2).
 * * Outputs:
 * - mem_RegWrite_out...: Control signals passed down to the EX/MEM register.
 * - branch_target_addr_out: Calculated absolute address for jumps/branches.
 * - branch_taken_out:       Asserted if a branch condition is met or a jump occurs.
 * -----------------------------------------------------------------------------
 */
module execute_stage(
    // Inputs from ID/EX Register
    input  wire        ex_RegWrite,
    input  wire        ex_MemtoReg,
    input  wire        ex_Branch,
    input  wire        ex_Jump,      
    input  wire [1:0]  ex_op_a_sel, 
    input  wire        ex_MemRead,
    input  wire        ex_MemWrite,
    input  wire        ex_ALUSrc,
    input  wire [1:0]  ex_ALUOp,
    input  wire [31:0] ex_read_data_1,
    input  wire [31:0] ex_read_data_2,
    input  wire [31:0] ex_immediate,
    input  wire [31:0] ex_pc_plus_4,
    input  wire [4:0]  ex_rd,
    input  wire [2:0]  ex_funct3,
    input  wire [6:0]  ex_funct7,
    
    // Forwarding controls and bypassed data
    input  wire [1:0]  forward_a,
    input  wire [1:0]  forward_b,
    input  wire [31:0] mem_alu_result, 
    input  wire [31:0] wb_alu_result,  
    
    // Outputs to EX/MEM Register
    output wire        mem_RegWrite_out,
    output wire        mem_MemtoReg_out,
    output wire        mem_MemWrite_out,
    output wire        mem_MemRead_out,
    output wire [31:0] mem_alu_result_out,
    output wire [31:0] mem_write_data_out, 
    output wire        mem_zero_flag_out,
    output wire [4:0]  mem_rd_out,
    output wire [2:0]  mem_funct3_out,

    // Outputs for PC Mux (Instruction Fetch Stage)
    output wire [31:0] branch_target_addr_out,
    output reg         branch_taken_out
);
    // Internal networks
    wire [4:0]  alu_control_signal;
    wire        zero_flag;
    wire [31:0] alu_result;

    // Post-forwarding operand registers
    reg  [31:0] forwarded_operand_a; 
    reg  [31:0] forwarded_operand_b;
    
    // Final ALU Input networks
    reg  [31:0] final_alu_input_a; 
    wire [31:0] final_alu_input_b;

    // ------------------------------------------------------------------------
    // 1. Data Hazard Resolution (Forwarding Multiplexers)
    // ------------------------------------------------------------------------
    // Design Consideration: Priority Encoding for Forwarding
    // The forwarding multiplexers intercept stale data from the ID stage and 
    // replace it with the most recent architectural state. Distance 1 hazards 
    // (EX/MEM) take precedence over Distance 2 hazards (MEM/WB).
    
    always @(*) begin
        case (forward_a)
            2'b00: forwarded_operand_a = ex_read_data_1; // Baseline: No hazard
            2'b01: forwarded_operand_a = mem_alu_result; // Priority 1: EX/MEM bypass
            2'b10: forwarded_operand_a = wb_alu_result;  // Priority 2: MEM/WB bypass
            default: forwarded_operand_a = ex_read_data_1;
        endcase
    end

    always @(*) begin
        case (forward_b)
            2'b00: forwarded_operand_b = ex_read_data_2; 
            2'b01: forwarded_operand_b = mem_alu_result; 
            2'b10: forwarded_operand_b = wb_alu_result;  
            default: forwarded_operand_b = ex_read_data_2;
        endcase
    end

    // ------------------------------------------------------------------------
    // 2. ALU Operand Selection (Precision Addressing)
    // ------------------------------------------------------------------------
    
    // Architectural Note: Multi-purpose ALU utilization
    // By manipulating the input multiplexers, the primary ALU is leveraged to 
    // execute AUIPC, LUI, and JAL addressing without requiring supplementary adders.
    always @(*) begin
        case (ex_op_a_sel)
            2'b00: final_alu_input_a = forwarded_operand_a;      // Standard Register Operands
            2'b01: final_alu_input_a = ex_pc_plus_4 - 32'd4;     // Base PC mapping (AUIPC / JAL)
            2'b10: final_alu_input_a = 32'b0;                    // Zero injection (LUI)
            default: final_alu_input_a = forwarded_operand_a;
        endcase
    end

    // Operand B selects between the forwarded register data and the immediate payload
    assign final_alu_input_b = (ex_ALUSrc) ? ex_immediate : forwarded_operand_b;

    // ------------------------------------------------------------------------
    // 3. Execution Core Instantiation
    // ------------------------------------------------------------------------
    alu_control ALUC (
        .ALUOp       (ex_ALUOp),
        .funct3      (ex_funct3),
        .funct7      (ex_funct7),
        .alu_control (alu_control_signal)
    );
    
    alu ALU (
        .a           (final_alu_input_a), 
        .b           (final_alu_input_b),
        .alu_control (alu_control_signal),
        .result      (alu_result),
        .zero        (zero_flag)
    );
    
    // ------------------------------------------------------------------------
    // 4. Control Flow and Branch Evaluation
    // ------------------------------------------------------------------------
    
    // Dedicated adder for PC-relative branch target derivation
    wire [31:0] branch_adder_result = ex_pc_plus_4 + ex_immediate - 32'd4;
    
    // Architectural Note: JALR Masking Rule
    // The base RISC-V integer instruction set specifies that the least-significant 
    // bit of a JALR target address must be cleared (set to 0) to maintain alignment.
    assign branch_target_addr_out = (ex_Jump) ? {alu_result[31:1], 1'b0} : branch_adder_result;
    
    always @(*) begin
        // Condition Evaluation
        if (ex_Branch) begin
            case(ex_funct3)
                3'b000: branch_taken_out = (zero_flag == 1'b1);       // BEQ
                3'b001: branch_taken_out = (zero_flag == 1'b0);       // BNE
                3'b100: branch_taken_out = (alu_result[0] == 1'b1);   // BLT (Signed)
                3'b101: branch_taken_out = (alu_result[0] == 1'b0);   // BGE (Signed)
                3'b110: branch_taken_out = (alu_result[0] == 1'b1);   // BLTU (Unsigned)
                3'b111: branch_taken_out = (alu_result[0] == 1'b0);   // BGEU (Unsigned)
                default: branch_taken_out = 1'b0;
            endcase
        end else begin
            branch_taken_out = 1'b0;
        end
        
        // Unconditional Jump Override
        if (ex_Jump) begin
            branch_taken_out = 1'b1;
        end
    end

    // ------------------------------------------------------------------------
    // 5. State Propagation to EX/MEM
    // ------------------------------------------------------------------------
    assign mem_RegWrite_out = ex_RegWrite;
    assign mem_MemtoReg_out = ex_MemtoReg;
    assign mem_MemWrite_out = ex_MemWrite;
    assign mem_MemRead_out  = ex_MemRead;
    
    // Implementation Detail: Return Address Preservation
    // Unconditional jumps (JAL/JALR) require the return address (PC+4) to be 
    // written back to the register file, overwriting the standard ALU calculation.
    assign mem_alu_result_out = (ex_Jump) ? ex_pc_plus_4 : alu_result;
    
    assign mem_write_data_out = forwarded_operand_b; 
    assign mem_zero_flag_out  = zero_flag;
    assign mem_rd_out         = ex_rd;
    assign mem_funct3_out     = ex_funct3;

endmodule
