`timescale 1ns / 1ps

/*
 * -----------------------------------------------------------------------------
 * Module Name:  PC
 * Project:      RISC V 32bit Processor
 * Date:         2026-03-05
 * * Description:
 * Implements the Program Counter (PC) register for the Instruction Fetch (IF) 
 * stage. This sequential logic element acts as the primary instruction pointer, 
 * synchronously latching the memory address of the next instruction to be fetched 
 * from the Instruction Memory.
 * * Inputs:
 * - clk, reset: System clock and global synchronous active-high reset.
 * - next_pc:    32-bit address calculated by the IF stage (typically PC+4 or a branch target).
 * * Outputs:
 * - current_pc: 32-bit address of the currently executing instruction.
 * -----------------------------------------------------------------------------
 */
module PC(
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] next_pc,
    output wire [31:0] current_pc
);

    // Internal state register
    reg [31:0] addr;

    always @(posedge clk) begin
        if (reset) begin
            // Architectural Note: Boot Vector Initialization
            // Upon a system reset, the Program Counter is initialized to 
            // 32'h80000000. This specific address aligns with standard RISC-V 
            // memory maps (such as those used in typical QEMU virt machines 
            // or bare-metal linkers), designating the entry point of the firmware.
            addr <= 32'h80000000;
        end
        else begin
            // Synchronous execution: Latch the evaluated next address
            addr <= next_pc;
        end
    end

    // Continuous assignment to expose the internal state to the datapath
    assign current_pc = addr;

endmodule
