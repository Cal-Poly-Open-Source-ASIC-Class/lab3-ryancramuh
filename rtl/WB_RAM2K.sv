`timescale 1ns/1ps
// Module: WB_RAM2K
// Author: Ryan C Cramer
// 
// Design: 
// WB_RAM2K is a 2 port 2KB RAM comprised of two individual
// 256x32 RAMS that can be accessed using wishbone interface.
// Since the ports can't both write or read the same RAM at 
// the same time, we do pipelined stalls and round-robin priority
// for each individual port.
//
// inputs end with "_i"
// outputs end with "_o"

module WB_RAM2K(

    input clk_i, // input clock

    input pA_wb_stb_i, //
    input pB_wb_stb_i,

    input pA_wb_cyc_i,
    input pB_wb_cyc_i,

    input [3:0] pA_wb_we_i,
    input [3:0] pB_wb_we_i,

    input [8:0] pA_wb_addr_i,
    input [8:0] pB_wb_addr_i,

    input [31:0] pA_wb_data_i,
    input [31:0] pB_wb_data_i,

    output logic pA_wb_ack_o,
    output logic pB_wb_ack_o,
 
    output logic pA_wb_stall_o,
    output logic pB_wb_stall_o,
 
    output logic [31:0] pA_wb_data_o,
    output logic [31:0] pB_wb_data_o
);

// collision is both ports talking to same RAM, with strobe on
logic collision = (pA_wb_addr_i[8] == pB_wb_addr_i[8]) && ((pA_wb_stb_i) && pB_wb_stb_i);

// single RAM A & B signals
logic ram_1_en, ram_2_en;
logic [3:0] ram_1_we, ram_2_we;
logic [7:0] ram_1_addr, ram_2_addr;
logic [31:0] ram_1_data_i, ram_2_data_i;
logic [31:0] ram_1_data_o, ram_2_data_o;

logic pA_needs_ack, pB_needs_ack;
logic pA_needs_data1, pB_needs_data1, pA_needs_data2, pB_needs_data2;

logic priority_port;

// RAM A
DFFRAM256x32 RAM_1(
        .CLK(clk_i),
        .WE0(ram_1_we),
        .EN0(ram_1_en),
        .Di0(ram_1_data_i),
        .Do0(ram_1_data_o),
        .A0(ram_1_addr)
);

// RAM B
DFFRAM256x32 RAM_2(
        .CLK(clk_i),
        .WE0(ram_2_we),
        .EN0(ram_2_en),
        .Di0(ram_2_data_i),
        .Do0(ram_2_data_o),
        .A0(ram_2_addr)
);


always_comb begin
        
    ram_1_en = 1'b0;
    ram_1_we = 4'h0;
    ram_1_addr = 8'h00;
    ram_1_data_i = 32'h00;
    
    ram_2_en = 1'b0;
    ram_2_we = 4'h0;
    ram_2_addr = 8'h00;
    ram_2_data_i = 32'h00;

    pA_wb_stall_o = (!priority_port && collision);
    pB_wb_stall_o = (priority_port && collision);

    pA_needs_ack = 1'b0;
    pB_needs_ack = 1'b0;
    pA_needs_data1 = 1'b0;
    pB_needs_data1 = 1'b0;
    pA_needs_data2 = 1'b0;
    pB_needs_data2 = 1'b0;
    
    if (collision) begin
        if(!pA_wb_addr_i[8] && !priority_port) begin
            pA_needs_ack = 1'b1;
            pA_needs_data1 = 1'b1;
            ram_1_en     = 1'b1;
            ram_1_we     = pA_wb_we_i;
            ram_1_addr   = pA_wb_addr_i[7:0];
            ram_1_data_i = pA_wb_data_i;
        end 
        if(pA_wb_addr_i[8] && !priority_port) begin
            pA_needs_ack = 1'b1;
            pA_needs_data2 = 1'b1;
            ram_2_en     = 1'b1;
            ram_2_we     = pA_wb_we_i;
            ram_2_addr   = pA_wb_addr_i[7:0];
            ram_2_data_i = pA_wb_data_i;
        end
        if(!pB_wb_addr_i[8] && priority_port) begin
            pB_needs_ack = 1'b1;
            pB_needs_data1 = 1'b1;
            ram_1_en     = 1'b1;
            ram_1_we     = pB_wb_we_i;
            ram_1_addr   = pB_wb_addr_i[7:0];
            ram_1_data_i = pB_wb_data_i;
        end
        if(pB_wb_addr_i[8] && priority_port) begin
            pB_needs_ack = 1'b1;
            pB_needs_data2 = 1'b1; 
            ram_2_en     = 1'b1;
            ram_2_we     = pB_wb_we_i;
            ram_2_addr   = pB_wb_addr_i[7:0];
            ram_2_data_i = pB_wb_data_i;
        end
    end    
    else begin
        if(!pA_wb_addr_i[8] && pA_wb_stb_i) begin
            pA_needs_ack = 1'b1;
            pA_needs_data1 = 1'b1;
            ram_1_en     = 1'b1;
            ram_1_we     = pA_wb_we_i;
            ram_1_addr   = pA_wb_addr_i[7:0];
            ram_1_data_i = pA_wb_data_i;
        end 
        if(pA_wb_addr_i[8]  && pA_wb_stb_i) begin
            pA_needs_ack = 1'b1;
            pA_needs_data2 = 1'b1;
            ram_2_en     = 1'b1;
            ram_2_we     = pA_wb_we_i;
            ram_2_addr   = pA_wb_addr_i[7:0];
            ram_2_data_i = pA_wb_data_i;
        end
        if(!pB_wb_addr_i[8]  && pB_wb_stb_i) begin
            pB_needs_ack = 1'b1;
            pB_needs_data1 = 1'b1;
            ram_1_en     = 1'b1;
            ram_1_we     = pB_wb_we_i;
            ram_1_addr   = pB_wb_addr_i[7:0];
            ram_1_data_i = pB_wb_data_i;
        end 
        if(pB_wb_addr_i[8] && pB_wb_stb_i) begin
            pB_needs_ack = 1'b1;
            pB_needs_data2 = 1'b1;
            ram_2_en     = 1'b1;
            ram_2_we     = pB_wb_we_i;
            ram_2_addr   = pB_wb_addr_i[7:0];
            ram_2_data_i = pB_wb_data_i;
        end
    end
end



logic PS, NS;
logic ack_A, ack_B;
//priority port logic
always_comb begin
    case(PS)
        1'b0: begin
            priority_port = 1'b0;
            if(collision) begin
                NS = 1'b1;
            end
            else 
                NS = 1'b0;
        end 
        1'b1: begin
            priority_port = 1'b1;
            if(collision) begin
                NS = 1'b0;
            end
            else 
                NS = 1'b1;
        end
    default: begin NS = 1'b0; end
    endcase
end


logic pA_grab_data1;
logic pA_grab_data2;

logic pB_grab_data1;
logic pB_grab_data2;

always_ff@(posedge clk_i) begin
    PS <= NS;
    // add once cycle latency;
    ack_A <= pA_needs_ack;
    ack_B <= pB_needs_ack;
    pA_wb_ack_o <= ack_A;
    pB_wb_ack_o <= ack_B;
    pA_grab_data1 <= pA_needs_data1;
    pA_grab_data2 <= pA_needs_data2;
    pB_grab_data1 <= pB_needs_data1;
    pB_grab_data2 <= pB_needs_data2;
    
    if (pA_grab_data1)
        pA_wb_data_o <= ram_1_data_o;
    else if (pA_grab_data2)
        pA_wb_data_o <= ram_2_data_o;
    if (pB_grab_data1)
        pB_wb_data_o <= ram_1_data_o;
    else if (pB_grab_data2)
        pB_wb_data_o <= ram_2_data_o;

end
endmodule
