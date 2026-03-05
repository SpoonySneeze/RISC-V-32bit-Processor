`timescale 1ns / 1ps

/*
 * -----------------------------------------------------------------------------
 * Module Name:  decode_stage
 * Project:      RISC V 32bit Processor
 * Date:         2026-03-05
 * * Description:
 * Implements the Instruction Decode (ID) stage of the pipeline. This structural 
 * module aggregates the Main Control Unit, the Register File, and the Immediate 
 * Generator. It dissects the fetched 32-bit instruction into its constituent 
 * architectural fields and manages the data write-back loop from the final stage.
 * * Inputs:
 * - clk, reset:            System clock and synchronous reset.
 * - instruction_to_decode: 32-bit instruction word from the IF/ID register.
 * - wb_reg_write:          Write enable signal from the Write-Back (WB) stage.
 * - wb_write_reg_addr:     Destination register address from the WB stage.
 * - wb_write_data:         Data payload to be written to the Register File.
 * * Outputs:
 * - immediate:             32-bit sign-extended immediate value.
 * - reg_write ... alu_op:  Control signals bound for the ID/EX pipeline register.
 * - read_data_1/2:         32-bit operands fetched from the Register File.
 * - fun3, fun7:            Function fields passed to the Execution stage.
 * - destination_register:  Destination address (rd) passed down the pipeline.
 * -----------------------------------------------------------------------------
 */
module decode_stage(
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] instruction_to_decode,
    
    // Inputs from Write-Back Stage (Feedback Loop)
    input  wire        wb_reg_write,
    input  wire [4:0]  wb_write_reg_addr,
    input  wire [31:0] wb_write_data,
    
    // Outputs to ID/EX Register
    output wire [31:0] immediate,
    output wire        reg_write,
    output wire        mem_to_reg,
    output wire        mem_read,
    output wire        mem_write,
    output wire        branch,
    output wire        jump,
    output wire [1:0]  op_a_sel, 
    output wire        alu_src,
    output wire [1:0]  alu_op,
    output wire [31:0] read_data_1,
    output wire [31:0] read_data_2,
    output wire [2:0]  fun3,
    output wire [6:0]  fun7,
    output wire [4:0]  destination_register
);
    
    // Implementation Detail: Register Field Extraction
    // The base RISC-V ISA specification deliberately keeps source register 
    // fields (rs1, rs2) in the same bit positions across all instruction formats 
    // to minimize decoding latency and hardware complexity.
    wire [4:0] rs1_addr = instruction_to_decode[19:15];
    wire [4:0] rs2_addr = instruction_to_decode[24:20];

    // 1. Control Unit Instantiation
    control_unit CU (
        .opcode     (instruction_to_decode[6:0]),
        .reg_write  (reg_write),
        .mem_to_reg (mem_to_reg),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .branch     (branch),
        .jump       (jump),
        .op_a_sel   (op_a_sel), 
        .alu_src    (alu_src),
        .alu_op     (alu_op)
    );
    
    // 2. Register File Instantiation
    // Architectural Note: Pipeline Write-Back Resolution
    // The Register File acts as the primary data dependency bridge. It reads 
    // using addresses provided by the current ID stage, but it writes using 
    // data and addresses propagated back from the final Write-Back (WB) stage.
    register_file RF (
        .clk          (clk),
        .reset        (reset),
        .write_enable (wb_reg_write),
        .read_reg_1   (rs1_addr),
        .read_reg_2   (rs2_addr),
        .write_reg    (wb_write_reg_addr), 
        .write_data   (wb_write_data),
        .read_data_1  (read_data_1),
        .read_data_2  (read_data_2)
    );

    // 3. Immediate Generator Instantiation
    immediate_generator IG (
        .instruction  (instruction_to_decode),
        .immediate    (immediate)
    );

    // Implementation Detail: Instruction Field Propagation
    // These fields are forwarded through the pipeline registers because they 
    // are required by the Execution stage (for secondary ALU decoding via 
    // funct3/funct7) and the Memory/Write-Back stages (for destination routing).
    assign fun3                 = instruction_to_decode[14:12];
    assign fun7                 = instruction_to_decode[31:25];
    assign destination_register = instruction_to_decode[11:7];

endmodule
