`timescale 1ns / 1ps

/*
 * -----------------------------------------------------------------------------
 * Module Name:  riscv_tb
 * Project:      RISC V 32bit Processor
 * Date:         2026-03-05
 * * Description:
 * This module serves as the Top-Level Testbench for the RISC-V processor. It 
 * provides the stimulus (clocking and reset) required to drive the DUT 
 * (Device Under Test) and manages the simulation lifecycle. 
 * * Verification Features:
 * 1. Synchronous Reset: Ensures all pipeline registers and the Program Counter 
 * start at a deterministic state.
 * 2. Compliance Testing: Implements a Signature Dump mechanism to export 
 * memory contents, facilitating automated comparison against a Golden 
 * Instruction Set Simulator (ISS) like Imperas or Spike.
 * -----------------------------------------------------------------------------
 */

module riscv_tb();
    reg clk;
    reg reset;

    // Implementation Detail: DUT Instantiation
    // The processor top-level core is instantiated as the Device Under Test.
    risc_v_top dut (
        .clk(clk),
        .reset(reset)
    );

    // ------------------------------------------------------------------------
    // 1. Clock Generation
    // ------------------------------------------------------------------------
    // Generates a 100MHz oscillating signal with a 50% duty cycle.
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // ------------------------------------------------------------------------
    // 2. Stimulus and Observation
    // ------------------------------------------------------------------------
    initial begin
        // System Initialization
        reset = 1;
        #20 reset = 0; // Assertion of reset for 2 full clock cycles.
        
        // Execution Window
        // Allows the processor to execute instructions loaded in 'code.mem'.
        #2000; 
        
        /*
         * Architectural Note: Signature Dumping
         * To verify ISA compliance, the first 4KB of Data Memory (DMEM) is 
         * exported to an external file. This "Signature" represents the final 
         * state of the execution and is used to validate the correctness of 
         * the RTL against architectural benchmarks.
         */
        $writememh("rtl_signature.output", dut.DMEM.memory, 16'h0000, 16'h0FFF);
        
        $display("Simulation Finished. Signature dumped to rtl_signature.output");
        $finish;
    end
endmodule
