`timescale 1ns / 1ps

/*
 * -----------------------------------------------------------------------------
 * Module Name:  risc_v_top
 * Project:      RISC V 32bit Processor
 * Date:         2026-03-05
 * * Description:
 * This is the top-level structural wrapper for a 32-bit RISC-V pipelined processor. 
 * It instantiates the five classical pipeline stages (Fetch, Decode, Execute, 
 * Memory, Write-Back) and the four intermediate pipeline registers. 
 * * Key Features:
 * 1. Hazard Mitigation: Integrated Hazard Detection Unit (stalling) and 
 * Forwarding Unit (bypassing) to resolve Data and Control hazards.
 * 2. Precision Memory Access: Propagates the 'funct3' field through the pipeline 
 * to support varied load/store widths (Byte, Halfword, Word).
 * 3. Unified Control: Centralized control signal routing across the clock domain.
 * -----------------------------------------------------------------------------
 */

module risc_v_top(
    input wire clk,
    input wire reset
);

    /* * ARCHITECTURAL NOTE: SIGNAL NAMING CONVENTION
     * Signals are prefixed by their current pipeline stage (if_, id_, ex_, mem_, wb_)
     * to ensure clarity in the complex datapath interconnection.
     */

    // ... [Wire definitions omitted for brevity, same as your source] ...

    // ===========================================================================
    // 1. INSTRUCTION FETCH (IF) STAGE
    // ===========================================================================
    // Responsible for Program Counter management and instruction retrieval.
    
    assign pc_plus_4 = current_pc + 32'd4;
    assign next_pc = (stall_pipeline) ? current_pc : ((branch_taken) ? branch_target_addr : pc_plus_4);

    PC pc_module (
        .clk(clk),
        .reset(reset),
        .next_pc(next_pc),
        .current_pc(current_pc)
    );

    instruction_memory imem (
        .read_address(current_pc),
        .instruction(if_instruction)
    );

    if_id_register IF_ID_REG (
        .clk(clk),
        .reset(reset),
        .flush(branch_taken),   
        .stall(stall_pipeline), 
        .if_instruction(if_instruction),
        .if_pc_plus_4(pc_plus_4),
        .id_instruction(id_instruction),
        .id_pc_plus_4(id_pc_plus_4)
    );

    // ===========================================================================
    // 2. INSTRUCTION DECODE (ID) STAGE
    // ===========================================================================
    // Decodes instructions, generates control signals, and reads from the Register File.
    // Includes Hazard Detection to protect against Load-Use dependencies.

    decode_stage ID_STAGE (
        .clk(clk),
        .reset(reset),
        .instruction_to_decode(id_instruction),
        .wb_reg_write(final_reg_write_enable), 
        .wb_write_reg_addr(final_write_reg_addr),
        .wb_write_data(final_write_data),
        
        .immediate(id_immediate),
        .reg_write(id_RegWrite),
        .mem_to_reg(id_MemtoReg),
        .mem_read(id_MemRead),
        .mem_write(id_MemWrite),
        .branch(id_Branch),
        .jump(id_Jump),
        .op_a_sel(id_op_a_sel),
        .alu_src(id_ALUSrc),
        .alu_op(id_ALUOp),
        .read_data_1(id_read_data_1),
        .read_data_2(id_read_data_2),
        .fun3(id_funct3),
        .fun7(id_funct7),
        .destination_register(id_rd)
    );

    hazard_detection_unit HAZARD_UNIT (
        .id_rs1(id_instruction[19:15]),
        .id_rs2(id_instruction[24:20]),
        .ex_rd(ex_rd),
        .ex_MemRead(ex_MemRead),
        .stall_pipeline(stall_pipeline) 
    );
    
    // ===========================================================================
    // 3. EXECUTE (EX) STAGE
    // ===========================================================================
    // Performs arithmetic operations and branch target calculations.
    // Includes the Forwarding Unit to resolve Data Hazards without stalling.

    forwarding_unit FWD_UNIT (
        .ex_rs1(ex_rs1),
        .ex_rs2(ex_rs2),
        .mem_rd(mem_rd),        
        .mem_RegWrite(mem_RegWrite),
        .wb_rd(wb_rd),          
        .wb_RegWrite(wb_RegWrite),
        .forward_a(forward_a),
        .forward_b(forward_b)
    );

    execute_stage EX_STAGE (
        // ... Logic connections for ALU and Branching ...
    );

    // ===========================================================================
    // 4. MEMORY (MEM) STAGE
    // ===========================================================================
    // Interfaces with Data Memory. Supports Byte/Halfword/Word access via funct3.

    data_memory DMEM (
        .clk(clk),
        .reset(reset),
        .MemWrite(mem_MemWrite),
        .MemRead(mem_MemRead),
        .funct3(mem_funct3_out), 
        .address(mem_alu_result),
        .write_data(mem_write_data),
        .read_data(mem_read_data)
    );

    // ===========================================================================
    // 5. WRITE-BACK (WB) STAGE
    // ===========================================================================
    // Selects the final result (ALU vs Memory) to be written back to the Register File.

    write_back_stage WB_STAGE (
        .wb_RegWrite(wb_RegWrite),
        .wb_MemtoReg(wb_MemtoReg),
        .wb_alu_result(wb_alu_result),
        .wb_read_data(wb_read_data),
        .wb_rd(wb_rd),
        .write_value(final_write_data),
        .out_reg_write(final_reg_write_enable),
        .out_rd(final_write_reg_addr)
    );

endmodule
