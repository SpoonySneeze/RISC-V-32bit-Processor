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
 * 1. It is simple test as you can see in the code.mem file it is a simple loop and add program.
 * 2. We are dumping things into the .vcd file so that we can look actually what's happning using GTKwave.
 * -----------------------------------------------------------------------------
 */

module riscv_tb;

    reg clk;
    reg reset;

    // Instantiate DUT
    risc_v_top dut (
        .clk(clk),
        .reset(reset)
    );

    // Clock generation: 100MHz
    always #5 clk = ~clk;

    // Dump everything for GTKWave
    initial begin
        $dumpfile("riscv_full.vcd");
        $dumpvars(0, riscv_tb);
    end

    // Reset sequence
    initial begin
        clk   = 0;
        reset = 1;

        #20;
        reset = 0;     // release reset
    end

    // Stop simulation after some cycles
    initial begin
        #5000;
        $display("TIMEOUT: Simulation finished.");
        $finish;
    end

    // Monitor final write-back (this is your OUTPUT)
    always @(posedge clk) begin
        if (dut.final_reg_write_enable) begin
            $display(
                "[%0t] WB: x%0d <= %0d (0x%h)",
                $time,
                dut.final_write_reg_addr,
                dut.final_write_data,
                dut.final_write_data
            );

            // PASS condition for your loop
            if (dut.final_write_reg_addr == 5'd11 &&
                dut.final_write_data == 32'd15) begin
                $display("=================================");
                $display("PASS: Loop sum result = 15");
                $display("=================================");
                #20;
                $finish;
            end
        end
    end

endmodule
