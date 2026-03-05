`timescale 1ns / 1ps

/*
 * -----------------------------------------------------------------------------
 * Module Name:  register_file
 * Project:      RISC V 32bit Processor
 * Date:         2026-03-05
 * * Description:
 * Implements the 32x32-bit integer register file dictated by the base RISC-V ISA. 
 * It features two asynchronous read ports and one synchronous write port. 
 * Crucially, it incorporates internal data forwarding (write-through) logic to 
 * resolve intra-cycle structural hazards between the Write-Back and Decode stages.
 * * Inputs:
 * - clk, reset:   System clock and synchronous active-high reset.
 * - write_enable: Asserted high to permit writing to the specified destination.
 * - read_reg_1/2: 5-bit source register addresses.
 * - write_reg:    5-bit destination register address.
 * - write_data:   32-bit data payload arriving from the Write-Back (WB) stage.
 * * Outputs:
 * - read_data_1/2: 32-bit operands supplied to the execution pipeline.
 * -----------------------------------------------------------------------------
 */
module register_file(
    input  wire        clk,
    input  wire        reset,
    input  wire        write_enable,
    input  wire [4:0]  read_reg_1,
    input  wire [4:0]  read_reg_2,
    input  wire [4:0]  write_reg,
    input  wire [31:0] write_data,
    output wire [31:0] read_data_1,
    output wire [31:0] read_data_2
);
    
    // Architectural Note: Storage Allocation
    // The base RV32I architecture requires 32 general-purpose registers, 
    // each 32 bits wide.
    reg [31:0] registers [0:31];
    integer i;

    // ------------------------------------------------------------------------
    // 1. Synchronous Write Logic
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            // Design Consideration: Initialization
            // While a loop initializes the array perfectly in simulation, physical 
            // synthesis tools map this to distributed RAM (LUTRAM) in FPGAs.
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'b0;
            end
        end else begin
            // Architectural Note: Zero Register Immutability
            // Register x0 is hardwired to zero. Writes to address 5'b0 are 
            // architecturally ignored to maintain compliance with the ISA.
            if (write_enable && write_reg != 5'b0) begin
                registers[write_reg] <= write_data;
            end
        end
    end
    
    // ------------------------------------------------------------------------
    // 2. Asynchronous Read Logic with Internal Forwarding
    // ------------------------------------------------------------------------
    
    // Implementation Detail: Intra-Cycle Hazard Resolution (Write-Through)
    // In a classic 5-stage pipeline, the WB stage writes to the register file 
    // while the ID stage reads from it concurrently. To prevent the ID stage 
    // from fetching stale data before the clock edge commits the write, a 
    // combinational bypass is implemented. If the read address matches an 
    // active write address, the incoming 'write_data' is instantly routed 
    // to the output ports, bypassing the storage array entirely.
    
    assign read_data_1 = (read_reg_1 == 5'b0) ? 32'b0 :
                         ((read_reg_1 == write_reg && write_enable) ? write_data : registers[read_reg_1]);

    assign read_data_2 = (read_reg_2 == 5'b0) ? 32'b0 :
                         ((read_reg_2 == write_reg && write_enable) ? write_data : registers[read_reg_2]);

endmodule
