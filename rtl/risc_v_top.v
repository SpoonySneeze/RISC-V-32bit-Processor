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

    // ===========================================================================
    // WIRE DEFINITIONS
    // ===========================================================================

    // --- IF Stage ---
    wire [31:0] current_pc;
    wire [31:0] next_pc;
    wire [31:0] pc_plus_4;
    wire [31:0] if_instruction;
    
    // --- ID Stage ---
    wire [31:0] id_pc_plus_4;
    wire [31:0] id_instruction;
    wire [31:0] id_immediate;
    wire [31:0] id_read_data_1;
    wire [31:0] id_read_data_2;
    wire [4:0]  id_rs1_addr; 
    wire [4:0]  id_rs2_addr; 
    wire [4:0]  id_rd;
    wire [2:0]  id_funct3;
    wire [6:0]  id_funct7;
    
    // Control Signals (ID)
    wire id_RegWrite, id_MemtoReg, id_MemRead, id_MemWrite;
    wire id_Branch, id_ALUSrc, id_Jump;
    wire [1:0] id_op_a_sel;
    wire [1:0] id_ALUOp;

    // --- EX Stage ---
    wire [31:0] ex_pc_plus_4;
    wire [31:0] ex_read_data_1;
    wire [31:0] ex_read_data_2;
    wire [31:0] ex_immediate;
    wire [4:0]  ex_rs1, ex_rs2, ex_rd;
    wire [2:0]  ex_funct3;
    wire [6:0]  ex_funct7;
    
    // Control Signals (EX)
    wire ex_RegWrite, ex_MemtoReg, ex_MemRead, ex_MemWrite, ex_Branch, ex_ALUSrc, ex_Jump;
    wire [1:0] ex_op_a_sel; 
    wire [1:0] ex_ALUOp;

    // --- Hazard & Forwarding Wires ---
    wire stall_pipeline;       
    wire branch_taken;         
    wire [1:0] forward_a;      
    wire [1:0] forward_b;      
    wire [31:0] branch_target_addr;
    wire id_ex_flush_signal;   

    // --- MEM Stage ---
    wire mem_RegWrite, mem_MemtoReg, mem_MemWrite, mem_MemRead;
    wire [31:0] mem_alu_result;
    wire [31:0] mem_write_data; 
    wire [31:0] mem_read_data;  
    wire [4:0]  mem_rd;
    wire [31:0] mem_alu_result_in; 
    wire [31:0] mem_write_data_in; 
    wire [4:0]  mem_rd_in;         
    wire mem_RegWrite_in, mem_MemtoReg_in, mem_MemWrite_in, mem_MemRead_in;
    wire mem_zero_flag_in, mem_zero_flag_unused;
    wire [4:0] mem_rs1_unused, mem_rs2_unused; 
    
    // --- NEW WIRES: Funct3 Propagation for Memory Access Size ---
    wire [2:0] mem_funct3_in;  // Output from EX Stage
    wire [2:0] mem_funct3_out; // Output from EX/MEM Register

    // --- WB Stage ---
    wire wb_RegWrite, wb_MemtoReg;
    wire [31:0] wb_read_data;
    wire [31:0] wb_alu_result;
    wire [4:0]  wb_rd;
    wire [31:0] final_write_data;     
    wire final_reg_write_enable;      
    wire [4:0] final_write_reg_addr;  

    // ===========================================================================
    // 1. INSTRUCTION FETCH (IF) STAGE
    // ===========================================================================

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

    assign id_rs1_addr = id_instruction[19:15];
    assign id_rs2_addr = id_instruction[24:20];

    hazard_detection_unit HAZARD_UNIT (
        .id_rs1(id_rs1_addr),
        .id_rs2(id_rs2_addr),
        .ex_rd(ex_rd),
        .ex_MemRead(ex_MemRead),
        .stall_pipeline(stall_pipeline) 
    );
    
    assign id_ex_flush_signal = branch_taken || stall_pipeline;

    id_ex_register ID_EX_REG (
        .clk(clk),
        .reset(reset),
        .flush(id_ex_flush_signal), 
        
        .id_RegWrite(id_RegWrite), 
        .id_MemtoReg(id_MemtoReg), 
        .id_MemRead(id_MemRead), 
        .id_MemWrite(id_MemWrite),
        .id_Branch(id_Branch), 
        .id_Jump(id_Jump),
        .id_op_a_sel(id_op_a_sel),
        .id_ALUSrc(id_ALUSrc), 
        .id_ALUOp(id_ALUOp),
        
        .id_read_data_1(id_read_data_1), 
        .id_read_data_2(id_read_data_2),
        .id_immediate(id_immediate), 
        .id_pc_plus_4(id_pc_plus_4),
        .id_rs1(id_rs1_addr), 
        .id_rs2(id_rs2_addr), 
        .id_rd(id_rd), 
        .id_funct3(id_funct3), 
        .id_funct7(id_funct7),
        
        .ex_RegWrite(ex_RegWrite), 
        .ex_MemtoReg(ex_MemtoReg),
        .ex_MemRead(ex_MemRead), 
        .ex_MemWrite(ex_MemWrite),
        .ex_Branch(ex_Branch), 
        .ex_Jump(ex_Jump),
        .ex_op_a_sel(ex_op_a_sel),
        .ex_ALUSrc(ex_ALUSrc), 
        .ex_ALUOp(ex_ALUOp),
        .ex_read_data_1(ex_read_data_1), 
        .ex_read_data_2(ex_read_data_2),
        .ex_immediate(ex_immediate), 
        .ex_pc_plus_4(ex_pc_plus_4),
        .ex_rs1(ex_rs1), 
        .ex_rs2(ex_rs2),
        .ex_rd(ex_rd), 
        .ex_funct3(ex_funct3), 
        .ex_funct7(ex_funct7)
    );

    // ===========================================================================
    // 3. EXECUTE (EX) STAGE
    // ===========================================================================

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
        .ex_RegWrite(ex_RegWrite), 
        .ex_MemtoReg(ex_MemtoReg),
        .ex_Branch(ex_Branch), 
        .ex_Jump(ex_Jump),
        .ex_op_a_sel(ex_op_a_sel),
        .ex_MemRead(ex_MemRead),
        .ex_MemWrite(ex_MemWrite), 
        .ex_ALUSrc(ex_ALUSrc),
        .ex_ALUOp(ex_ALUOp),
        .ex_read_data_1(ex_read_data_1), 
        .ex_read_data_2(ex_read_data_2),
        .ex_immediate(ex_immediate), 
        .ex_pc_plus_4(ex_pc_plus_4),
        .ex_rd(ex_rd), 
        .ex_funct3(ex_funct3), 
        .ex_funct7(ex_funct7),
        
        .forward_a(forward_a),
        .forward_b(forward_b),
        .mem_alu_result(mem_alu_result), 
        .wb_alu_result(final_write_data), 
        
        .mem_RegWrite_out(mem_RegWrite_in), 
        .mem_MemtoReg_out(mem_MemtoReg_in),
        .mem_MemWrite_out(mem_MemWrite_in), 
        .mem_MemRead_out(mem_MemRead_in),
        .mem_alu_result_out(mem_alu_result_in),
        .mem_write_data_out(mem_write_data_in),
        .mem_zero_flag_out(mem_zero_flag_in),
        .mem_rd_out(mem_rd_in),
        .branch_target_addr_out(branch_target_addr),
        .branch_taken_out(branch_taken),
        
        // NEW OUTPUT CONNECTION
        .mem_funct3_out(mem_funct3_in) 
    );

    ex_mem_register EX_MEM_REG (
        .clk(clk),
        .reset(reset),
        .ex_RegWrite(mem_RegWrite_in), 
        .ex_MemtoReg(mem_MemtoReg_in),
        .ex_MemWrite(mem_MemWrite_in), 
        .ex_MemRead(mem_MemRead_in),
        .ex_rs1(5'b0),
        .ex_rs2(5'b0), 
        .ex_rd(mem_rd_in),
        .ex_alu_result(mem_alu_result_in),
        .ex_write_data(mem_write_data_in),
        .ex_zero_flag(mem_zero_flag_in),
        
        // NEW INPUT CONNECTION
        .ex_funct3(mem_funct3_in),
        
        .mem_RegWrite(mem_RegWrite), 
        .mem_MemtoReg(mem_MemtoReg),
        .mem_MemWrite(mem_MemWrite), 
        .mem_MemRead(mem_MemRead),
        .mem_rs1(mem_rs1_unused), 
        .mem_rs2(mem_rs2_unused),
        .mem_rd(mem_rd),
        .mem_alu_result(mem_alu_result),
        .mem_write_data(mem_write_data),
        .mem_zero_flag(mem_zero_flag_unused),
        
        // NEW OUTPUT CONNECTION
        .mem_funct3(mem_funct3_out) 
    );

    data_memory DMEM (
        .clk(clk),
        .reset(reset),
        .MemWrite(mem_MemWrite),
        .MemRead(mem_MemRead),
        // NEW INPUT CONNECTION
        .funct3(mem_funct3_out), 
        .address(mem_alu_result),
        .write_data(mem_write_data),
        .read_data(mem_read_data)
    );

    mem_wb_register MEM_WB_REG (
        .clk(clk),
        .reset(reset),
        .mem_RegWrite(mem_RegWrite),
        .mem_MemtoReg(mem_MemtoReg),
        .mem_read_data(mem_read_data),
        .mem_alu_result(mem_alu_result),
        .mem_rd(mem_rd),
        .wb_RegWrite(wb_RegWrite),
        .wb_MemtoReg(wb_MemtoReg),
        .wb_read_data(wb_read_data),
        .wb_alu_result(wb_alu_result),
        .wb_rd(wb_rd)
    );

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