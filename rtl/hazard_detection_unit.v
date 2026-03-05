`timescale 1ns / 1ps

/*
 * -----------------------------------------------------------------------------
 * Module Name:  hazard_detection_unit
 * Project:      RISC V 32bit Processor
 * Date:         2026-03-05
 * * Description:
 * Implements the stall logic required to resolve Load-Use data hazards. This 
 * unit monitors the instruction currently in the Instruction Decode (ID) stage 
 * against the instruction in the Execute (EX) stage. If a Load-Use dependency 
 * is detected, it asserts a stall signal to freeze the IF and ID pipeline 
 * registers, effectively injecting a "bubble" (NOP) into the EX stage.
 * * Inputs:
 * - id_rs1, id_rs2: Source register addresses for the instruction currently in ID.
 * - ex_rd:          Destination register address for the instruction currently in EX.
 * - ex_MemRead:     Control flag asserted if the instruction in EX is a Memory Load.
 * * Outputs:
 * - stall_pipeline: Asserts high (1) to induce a pipeline stall.
 * -----------------------------------------------------------------------------
 */
module hazard_detection_unit(
    // Inputs from ID Stage (Instruction currently being decoded)
    input  wire [4:0] id_rs1,
    input  wire [4:0] id_rs2,

    // Inputs from EX Stage (Instruction immediately preceding)
    input  wire [4:0] ex_rd,
    input  wire       ex_MemRead, 

    // Outputs to Pipeline Control
    output reg        stall_pipeline   
);

    always @(*) begin
        // Design Consideration: Default Operational State
        // The baseline state assumes continuous instruction flow without interruption.
        stall_pipeline = 1'b0; 

        // Architectural Note: Load-Use Hazard Condition Evaluation
        // A pipeline stall is strictly required if, and only if:
        // 1. The preceding instruction is a memory read (ex_MemRead == 1).
        // 2. The destination register is not the hardwired zero register (ex_rd != 0).
        // 3. The destination register of the load matches either of the source 
        //    registers required by the current instruction in the ID stage.
        if (ex_MemRead && (ex_rd != 5'b0) && ((ex_rd == id_rs1) || (ex_rd == id_rs2))) begin 
            stall_pipeline = 1'b1; // Induce one-cycle pipeline bubble
        end
    end

endmodule
