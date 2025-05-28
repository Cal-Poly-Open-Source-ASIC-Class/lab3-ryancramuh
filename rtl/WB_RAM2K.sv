`timescale 1ns/1ps
// Module: WB_RAM2K
// Author: Ryan C Cramer

module WB_RAM2K(
    input clk_i,
    input rst_i,

    input pA_wb_stb_i,
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
logic collision;
assign collision = (pA_wb_addr_i[8] == pB_wb_addr_i[8]) && (pA_wb_stb_i && pB_wb_stb_i);

// single RAM A & B signals
logic ram_1_en, ram_2_en;
logic [3:0] ram_1_we, ram_2_we;
logic [7:0] ram_1_addr, ram_2_addr;
logic [31:0] ram_1_data_i, ram_2_data_i;
logic [31:0] ram_1_data_o, ram_2_data_o;

logic pA_needs_ack, pB_needs_ack;
logic pA_needs_data1, pB_needs_data1, pA_needs_data2, pB_needs_data2;

logic priority_port;

logic ack_A, ack_B;
logic pA_grab_data1, pA_grab_data2, pB_grab_data1, pB_grab_data2;

logic pA_high_bit;
assign pA_high_bit = pA_wb_addr_i[8];
logic pB_high_bit;
assign pB_high_bit = pB_wb_addr_i[8];

logic [7:0] pA_addr;
logic [7:0] pB_addr;
assign pA_addr = pA_wb_addr_i[7:0];
assign pB_addr = pB_wb_addr_i[7:0];


logic PS, NS;



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

 logic [31:0] pA_data, pB_data;
// Main combinational logic
always_comb begin
    ram_1_en = 'b0; ram_1_we = 'b0; ram_1_addr = 'b0; ram_1_data_i = 'b0;
    ram_2_en = 'b0; ram_2_we = 'b0; ram_2_addr = 'b0; ram_2_data_i = 'b0;

    pA_wb_stall_o = (!priority_port && collision);
    pB_wb_stall_o = (priority_port && collision);

    pA_needs_ack = 'b0; pB_needs_ack = 'b0;
    pA_needs_data1 = 'b0; pB_needs_data1 = 'b0;
    pA_needs_data2 = 'b0; pB_needs_data2 = 'b0;

    pA_wb_data_o = 'b0;
    pB_wb_data_o = 'b0;

   
   

    if (collision) begin
        if (!pA_high_bit && priority_port && pB_wb_stall_o) begin
            pA_needs_ack = 'b1;
            ram_1_en = 'b1; ram_1_we = pA_wb_we_i; ram_1_addr = pA_wb_addr_i[7:0]; ram_1_data_i = pA_wb_data_i;
            if(pA_wb_we_i == 4'b0000) begin
                    pA_needs_data1 = 1'b1;
            end
        end
        if (pA_high_bit && priority_port && pB_wb_stall_o) begin
            pA_needs_ack = 'b1;
            ram_2_en = 'b1; ram_2_we = pA_wb_we_i; ram_2_addr = pA_addr; ram_2_data_i = pA_wb_data_i;
            if(pA_wb_we_i == 4'b0000) begin
                    pA_needs_data2 = 1'b1;
            end
        end
        if (!pB_high_bit && !priority_port && pA_wb_stall_o) begin
            pB_needs_ack = 'b1;
            ram_1_en = 'b1; ram_1_we = pB_wb_we_i; ram_1_addr = pB_addr; ram_1_data_i = pB_wb_data_i;
            if(pB_wb_we_i == 4'b0000) begin
                    pB_needs_data1 = 1'b1;
            end
        end
        if (pB_high_bit && !priority_port && pA_wb_stall_o) begin
            pB_needs_ack = 'b1;
            ram_2_en = 'b1; ram_2_we = pB_wb_we_i; ram_2_addr = pB_addr; ram_2_data_i = pB_wb_data_i;
            if(pB_wb_we_i == 4'b0000) begin
                    pB_needs_data2 = 1'b1;
            end
        end
    end else begin
        if (!pA_high_bit && pA_wb_stb_i && !pA_wb_stall_o) begin
            pA_needs_ack = 'b1;
            ram_1_en = 'b1; ram_1_we = pA_wb_we_i; ram_1_addr = pA_addr; ram_1_data_i = pA_wb_data_i;
            if(pA_wb_we_i == 4'b0000) begin
                    pA_needs_data1 = 1'b1;
            end
        end
        if (pA_high_bit && pA_wb_stb_i && !pA_wb_stall_o) begin
            pA_needs_ack = 'b1;
            ram_2_en = 'b1; ram_2_we = pA_wb_we_i; ram_2_addr = pA_addr; ram_2_data_i = pA_wb_data_i;
            if(pA_wb_we_i == 4'b0000) begin
                    pA_needs_data2 = 1'b1;
            end
        end
        if (!pB_high_bit && pB_wb_stb_i && !pB_wb_stall_o) begin
            pB_needs_ack = 'b1;
            ram_1_en = 'b1; ram_1_we = pB_wb_we_i; ram_1_addr = pB_addr; ram_1_data_i = pB_wb_data_i;
            if(pB_wb_we_i == 4'b0000) begin
                    pB_needs_data1 = 1'b1;
            end
        end
        if (pB_high_bit && pB_wb_stb_i && !pB_wb_stall_o) begin
            pB_needs_ack = 'b1;
            ram_2_en = 'b1; ram_2_we = pB_wb_we_i; ram_2_addr = pB_addr; ram_2_data_i = pB_wb_data_i;
            if(pB_wb_we_i == 4'b0000) begin
                    pB_needs_data2 = 1'b1;
            end
        end
    end
    if(pA_grab_data1) begin
        pA_wb_data_o = ram_1_data_o;
    end
    else if (pA_grab_data2) begin
        pA_wb_data_o = ram_2_data_o;
    end
    if (pB_grab_data1) begin
        pB_wb_data_o = ram_1_data_o;
    end
    else if (pB_grab_data2) begin
        pB_wb_data_o = ram_2_data_o;
    end

end

// Priority port round-robin
always_comb begin
    case (PS)
        1'b0: begin priority_port = 'b0; NS = collision ? 'b1 : 'b0; end
        1'b1: begin priority_port = 'b1; NS = collision ? 'b0 : 'b1; end
        default: NS = 'b0;
    endcase
end

// Latched ack + priority

always_ff @(posedge clk_i) begin
    if(rst_i) begin
        PS <= 1'b0;
        pA_wb_ack_o <=  1'b0;
        pB_wb_ack_o <=  1'b0;

        pA_grab_data1 <= 1'b0;
        pA_grab_data2 <= 1'b0;
        pB_grab_data1 <= 1'b0;
        pB_grab_data2 <= 1'b0;
    end

    PS <= NS;
    pA_wb_ack_o <=  pA_needs_ack;
    pB_wb_ack_o <=  pB_needs_ack;

    pA_grab_data1 <= pA_needs_data1;
    pA_grab_data2 <= pA_needs_data2;
    pB_grab_data1 <= pB_needs_data1;
    pB_grab_data2 <= pB_needs_data2;

end

endmodule
