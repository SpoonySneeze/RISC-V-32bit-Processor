`timescale 1ns / 1ps

/*
 * -----------------------------------------------------------------------------
 * Module Name:  mem_wb_register
 * Project:      RISC-V 32-bit Pipelined Processor
 * Description:
 * This synchronous pipeline register separates the Memory (MEM) and 
 * Write-Back (WB) stages. It latches the result of arithmetic operations, 
 * data retrieved from memory, and the associated destination register address.
 * -----------------------------------------------------------------------------
 */

module mem_wb_register(
    input wire clk,
    input wire reset,

    // Control and Data Inputs (from MEM stage)
    input wire        mem_RegWrite,   // Write enable for Register File
    input wire        mem_MemtoReg,   // Mux select for memory vs. ALU result
    input wire [31:0] mem_read_data,  // Data fetched from Data Memory
    input wire [31:0] mem_alu_result, // Address or arithmetic result
    input wire [4:0]  mem_rd,          // Destination register index

    // Control and Data Outputs (to WB stage)
    output reg        wb_RegWrite,
    output reg        wb_MemtoReg,
    output reg [31:0] wb_read_data,
    output reg [31:0] wb_alu_result,
    output reg [4:0]  wb_rd
);

    /* * Architectural Note: Synchronous State Propagation
     * On every rising edge, the pipeline state is advanced. If a reset is 
     * triggered, wb_RegWrite is explicitly pulled low to prevent 
     * accidental corruption of the Register File.
     */
    always @(posedge clk) begin
        if (reset) begin
            wb_RegWrite   <= 1'b0;
            wb_MemtoReg   <= 1'b0;
            wb_read_data  <= 32'b0;
            wb_alu_result <= 32'b0;
            wb_rd         <= 5'b0;
        end
        else begin
            wb_RegWrite   <= mem_RegWrite;
            wb_MemtoReg   <= mem_MemtoReg;
            wb_read_data  <= mem_read_data;
            wb_alu_result <= mem_alu_result;
            wb_rd         <= mem_rd;
        end
    end

endmodule
