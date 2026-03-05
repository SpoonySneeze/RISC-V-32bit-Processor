`timescale 1ns / 1ps

/*
 * -----------------------------------------------------------------------------
 * Module Name:  if_id_register
 * Project:      RISC V 32bit Processor
 * Date:         2026-03-05
 * * Description:
 * Implements the synchronous pipeline register separating the Instruction Fetch 
 * (IF) and Instruction Decode (ID) stages[cite: 98]. It is responsible for latching 
 * the fetched instruction and the corresponding program counter value[cite: 100]. 
 * Critically, this module incorporates both data and control hazard mitigation 
 * interfaces, allowing the pipeline to be dynamically stalled or flushed[cite: 98].
 * * Inputs:
 * - clk, reset:     System clock and global synchronous reset.
 * - flush:          Control signal to clear the register (inject a NOP) during control hazards[cite: 98].
 * - stall:          Control signal to freeze the register state during Load-Use hazards[cite: 98].
 * - if_instruction: 32-bit instruction word fetched from instruction memory[cite: 98].
 * - if_pc_plus_4:   The program counter value associated with the fetched instruction[cite: 98, 99].
 * * Outputs:
 * - id_instruction: Latched instruction provided to the ID stage[cite: 99, 108].
 * - id_pc_plus_4:   Latched program counter provided to the ID stage[cite: 99, 108].
 * -----------------------------------------------------------------------------
 */
module if_id_register(
    input  wire        clk,
    input  wire        reset,
    input  wire        flush, 
    input  wire        stall,
    input  wire [31:0] if_instruction,
    input  wire [31:0] if_pc_plus_4,     
    output wire [31:0] id_instruction,
    output wire [31:0] id_pc_plus_4      
);

    // Architectural Note: State Preservation
    // Internal registers hold the pipeline state for exactly one clock cycle, 
    // decoupling the combinational fetch logic from the decode logic[cite: 100].
    reg [31:0] instruction_reg;
    reg [31:0] pc_reg;

    always @(posedge clk) begin
        // Design Consideration: Evaluation Hierarchy
        // The priority of state manipulation is absolute: Reset -> Flush -> Stall -> Normal Operation.
        
        if (reset) begin
            // Global initialization to a safe state[cite: 102].
            instruction_reg <= 32'b0;
            pc_reg          <= 32'b0;
        end  
        else if (flush == 1'b1) begin
            // Architectural Note: Control Hazard Mitigation
            // Asserted when a branch is taken or a jump is resolved. The speculatively 
            // fetched instruction is invalidated by zero-filling the register, 
            // which effectively propagates as a harmless NOP (addi x0, x0, 0)[cite: 103, 104].
            instruction_reg <= 32'b0;
            pc_reg          <= 32'b0;
        end
        else if (stall) begin
            // Architectural Note: Data Hazard Mitigation
            // Asserted by the Hazard Detection Unit during a Load-Use dependency. 
            // The register maintains its previous state, effectively pausing the 
            // frontend of the processor while injecting a bubble into the EX stage[cite: 104, 105].
            instruction_reg <= instruction_reg;
            pc_reg          <= pc_reg;
        end
        else begin
            // Normal operation: Latch incoming data from the Instruction Fetch stage[cite: 106, 107].
            instruction_reg <= if_instruction;
            pc_reg          <= if_pc_plus_4;
        end
    end

    // Continuous assignment to drive the output ports from the internal latches[cite: 107, 108].
    assign id_instruction = instruction_reg;
    assign id_pc_plus_4   = pc_reg;
    
endmodule
