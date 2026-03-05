`timescale 1ns / 1ps

/*
 * -----------------------------------------------------------------------------
 * Module Name:  data_memory
 * Project:      RISC V 32bit Processor
 * Date:         2026-03-05
 * * Description:
 * Implements the main data memory (RAM) for the processor. It provides 64KB 
 * of storage organized as 16,384 32-bit words. The module supports byte (8-bit), 
 * halfword (16-bit), and word (32-bit) access. Reads are asynchronous 
 * (combinational) and writes are synchronous to the clock edge.
 * * Inputs:
 * - clk:         System clock
 * - reset:       Synchronous reset to clear memory contents
 * - MemWrite:    High to enable writing to memory
 * - MemRead:     High to enable reading from memory
 * - funct3:      3-bit signal from instruction (instr[14:12]) to determine size/sign
 * - address:     32-bit memory address (from ALU result)
 * - write_data:  32-bit data to be written (from rs2)
 * * Outputs:
 * - read_data:   32-bit data read from memory
 * -----------------------------------------------------------------------------
 */
module data_memory(
    input  wire        clk,
    input  wire        reset,
    input  wire        MemWrite,
    input  wire        MemRead,
    input  wire [2:0]  funct3,        
    input  wire [31:0] address,
    input  wire [31:0] write_data,
    output reg  [31:0] read_data      
);

    //  16384 words * 4 bytes/word = 65,536 bytes (64KB total).
    // The memory is stored as 32-bit words, NOT an array of bytes.
    reg [31:0] memory [0:16383];
    integer i;

    //  Word Alignment and Byte Offsets
    // RISC-V addresses point to individual BYTES. Since our array holds WORDS,
    // we drop the bottom 2 bits of the address to get the word index.
    // We use the bottom 2 bits to figure out *which* byte inside the word we want.
    wire [13:0] word_addr   = address[15:2];
    wire [1:0]  byte_offset = address[1:0]; 

    // --- READ LOGIC (Combinational) ---
    always @(*) begin
        // Default to zero to prevent latches
        read_data = 32'b0; 
        
        if (MemRead) begin
            case (funct3)
                // LB (Load Byte) - Sign Extended
                //  Endianness. RISC-V is Little-Endian. Byte 0 is the 
                // least significant byte (bits 7:0). We extract the specific byte, 
                // then copy its Most Significant Bit (the sign bit) 24 times to pad it out.
                3'b000: begin
                    case(byte_offset)
                        2'b00: read_data = {{24{memory[word_addr][7]}},  memory[word_addr][7:0]};
                        2'b01: read_data = {{24{memory[word_addr][15]}}, memory[word_addr][15:8]};
                        2'b10: read_data = {{24{memory[word_addr][23]}}, memory[word_addr][23:16]};
                        2'b11: read_data = {{24{memory[word_addr][31]}}, memory[word_addr][31:24]};
                    endcase
                end
                
                // LH (Load Halfword) - Sign Extended
                //  Halfwords must be aligned to 2-byte boundaries. 
                // We only check bit 1 of the offset (00 -> lower half, 10 -> upper half).
                3'b001: begin
                    case(byte_offset[1]) 
                        1'b0: read_data = {{16{memory[word_addr][15]}}, memory[word_addr][15:0]};
                        1'b1: read_data = {{16{memory[word_addr][31]}}, memory[word_addr][31:16]};
                    endcase
                end
                
                // LW (Load Word)
                3'b010: read_data = memory[word_addr];
                
                // LBU (Load Byte Unsigned) - Zero Extended
                //  Zero extension just pads the top 24 bits with hardcoded 0s.
                3'b100: begin
                    case(byte_offset)
                        2'b00: read_data = {24'b0, memory[word_addr][7:0]};
                        2'b01: read_data = {24'b0, memory[word_addr][15:8]};
                        2'b10: read_data = {24'b0, memory[word_addr][23:16]};
                        2'b11: read_data = {24'b0, memory[word_addr][31:24]};
                    endcase
                end

                // LHU (Load Halfword Unsigned) - Zero Extended
                3'b101: begin
                    case(byte_offset[1])
                        1'b0: read_data = {16'b0, memory[word_addr][15:0]};
                        1'b1: read_data = {16'b0, memory[word_addr][31:16]};
                    endcase
                end
                
                default: read_data = memory[word_addr];
            endcase
        end
    end

    // --- WRITE LOGIC (Synchronous) ---
    always @(posedge clk) begin
        if (reset) begin
            // GOTCHA: Synthesis Warning!
            // A looping reset over a massive array is great for simulation, 
            // but physical FPGA Block RAMs usually cannot clear all addresses in 1 cycle. 
            // If mapping to an FPGA, you may need to remove this or use a memory init file (.mem).
            for (i = 0; i < 16384; i = i + 1) memory[i] <= 32'b0;
        end
        else if (MemWrite) begin
            case (funct3)
                // SB (Store Byte)
                // We do a "masked write", updating only 8 bits of the 32-bit word.
                3'b000: begin
                    case(byte_offset)
                        2'b00: memory[word_addr][7:0]   <= write_data[7:0];
                        2'b01: memory[word_addr][15:8]  <= write_data[7:0];
                        2'b10: memory[word_addr][23:16] <= write_data[7:0];
                        2'b11: memory[word_addr][31:24] <= write_data[7:0];
                    endcase
                end
                
                // SH (Store Halfword)
                3'b001: begin
                    case(byte_offset[1])
                        1'b0: memory[word_addr][15:0]  <= write_data[15:0];
                        1'b1: memory[word_addr][31:16] <= write_data[15:0];
                    endcase
                end
                
                // SW (Store Word)
                3'b010: memory[word_addr] <= write_data;
            endcase
        end
    end

endmodule
