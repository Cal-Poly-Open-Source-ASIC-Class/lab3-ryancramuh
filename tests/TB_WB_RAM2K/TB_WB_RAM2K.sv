`timescale 10ns/1ps

module TB_WB_RAM2K;

    logic clk_o;
    logic pA_wb_stb_o, pB_wb_stb_o;
    logic pA_wb_cyc_o, pB_wb_cyc_o;
    logic [3:0] pA_wb_we_o, pB_wb_we_o;
    logic [8:0] pA_wb_addr_o, pB_wb_addr_o;
    logic [31:0] pA_wb_data_o, pB_wb_data_o;

    logic pA_wb_ack_i, pB_wb_ack_i;
    logic pA_wb_stall_i, pB_wb_stall_i;
    logic [31:0] pA_wb_data_i, pB_wb_data_i;

    WB_RAM2K dut (
        .clk_i(clk_o),
        .pA_wb_stb_i(pA_wb_stb_o),
        .pA_wb_cyc_i(pA_wb_cyc_o),
        .pA_wb_we_i(pA_wb_we_o),
        .pA_wb_addr_i(pA_wb_addr_o),
        .pA_wb_data_i(pA_wb_data_o),
        .pA_wb_ack_o(pA_wb_ack_i),
        .pA_wb_stall_o(pA_wb_stall_i),
        .pA_wb_data_o(pA_wb_data_i),
        .pB_wb_stb_i(pB_wb_stb_o),
        .pB_wb_cyc_i(pB_wb_cyc_o),
        .pB_wb_we_i(pB_wb_we_o),
        .pB_wb_addr_i(pB_wb_addr_o),
        .pB_wb_data_i(pB_wb_data_o),
        .pB_wb_ack_o(pB_wb_ack_i),
        .pB_wb_stall_o(pB_wb_stall_i),
        .pB_wb_data_o(pB_wb_data_i)
    );

    // Clock generation
    initial clk_o = 0;
    always #5 clk_o = ~clk_o;

    integer cycle_count = 0;
    logic done = 0;

    always @(posedge clk_o) begin
        cycle_count++;
        if (!done && cycle_count > 5000)
            $fatal(1, "Timeout: Simulation hung > 5000 cycles.");
    end

    initial begin
        $dumpfile("TB_WB_RAM2K.vcd");
        $dumpvars(2, TB_WB_RAM2K);
    end

    always begin
        pA_wb_stb_o <= 0; pA_wb_cyc_o <= 0; pA_wb_we_o <= 0;
        pA_wb_addr_o <= 0; pA_wb_data_o <= 0;
        pB_wb_stb_o <= 0; pB_wb_cyc_o <= 0; pB_wb_we_o <= 0;
        pB_wb_addr_o <= 0; pB_wb_data_o <= 0;

        #10;
        test_sequence();
        #100;
        done = 1;
        $display("PASS: All test cases completed.");
        $finish;
    end

    task automatic test_sequence;
        begin
            drive_wb_cycle_A(9'b0_0000_0100, 4'b1111, 32'hDEADBEEF);
            drive_wb_cycle_A(9'b0_0000_0100, 4'b0000, 32'h0);

            drive_wb_cycle_B(9'b1_0000_1000, 4'b1111, 32'hCAFEBABE);
            drive_wb_cycle_B(9'b1_0000_1000, 4'b0000, 32'h0);

            fork
                drive_wb_stall_A(9'b0_0000_1111, 4'b1111, 32'hAAAAAAAA);
                drive_wb_cycle_B(9'b0_0000_1111, 4'b1111, 32'hBBBBBBBB);
            join

            fork
                drive_wb_stall_A(9'b0_0000_1111, 4'b0000, 32'h0);
                drive_wb_stall_B(9'b0_0000_1111, 4'b0000, 32'h0);
            join
        end
    endtask

    task automatic drive_wb_cycle_A(input [8:0] addr, input [3:0] we, input [31:0] data);
        begin
            @(posedge clk_o);
            pA_wb_addr_o <= addr;
            pA_wb_data_o <= data;
            pA_wb_we_o   <= we;
            pA_wb_stb_o  <= 1;
            pA_wb_cyc_o  <= 1;

            wait (pA_wb_ack_i == 1);
            @(posedge clk_o);
            $display("A: ACK @ %t | addr = %h, we = %h, data_i = %h, data_o = %h",
                $time, addr, we, data, pA_wb_data_i);

            pA_wb_stb_o <= 0;
            pA_wb_we_o  <= 0;
            wait (pA_wb_ack_i == 0);
            pA_wb_cyc_o <= 0;
        end
    endtask

    task automatic drive_wb_cycle_B(input [8:0] addr, input [3:0] we, input [31:0] data);
        begin
            @(posedge clk_o);
            pB_wb_addr_o <= addr;
            pB_wb_data_o <= data;
            pB_wb_we_o   <= we;
            pB_wb_stb_o  <= 1;
            pB_wb_cyc_o  <= 1;

            wait (pB_wb_ack_i == 1);
            @(posedge clk_o);
            $display("B: ACK @ %t | addr = %h, we = %h, data_i = %h, data_o = %h",
                $time, addr, we, data, pB_wb_data_i);

            pB_wb_stb_o <= 0;
            pB_wb_we_o  <= 0;
            wait (pB_wb_ack_i == 0);
            pB_wb_cyc_o <= 0;
        end
    endtask

    task automatic drive_wb_stall_A(input [8:0] addr, input [3:0] we, input [31:0] data);
        integer timeout;
        begin
            @(posedge clk_o);
            pA_wb_addr_o <= addr;
            pA_wb_data_o <= data;
            pA_wb_we_o   <= we;
            pA_wb_stb_o  <= 1;
            pA_wb_cyc_o  <= 1;

            timeout = 0;
            while (pA_wb_stall_i && timeout < 1000) begin
                @(posedge clk_o);
                timeout++;
            end
            if (timeout == 1000)
                $fatal(1, "Timeout waiting for stall A to drop at addr %h", addr);

            timeout = 0;
            while (!pA_wb_ack_i && timeout < 1000) begin
                @(posedge clk_o);
                timeout++;
            end
            if (timeout == 1000)
                $fatal(1, "Timeout waiting for ack A at addr %h", addr);

            @(posedge clk_o);
            $display("A: ACK @ %t | addr = %h, we = %h, data_i = %h, data_o = %h",
                $time, addr, we, data, pA_wb_data_i);

            pA_wb_stb_o <= 0;
            pA_wb_we_o  <= 0;
            wait (pA_wb_ack_i == 0);
            pA_wb_cyc_o <= 0;
        end
    endtask

    task automatic drive_wb_stall_B(input [8:0] addr, input [3:0] we, input [31:0] data);
        integer timeout;
        begin
            @(posedge clk_o);
            pB_wb_addr_o <= addr;
            pB_wb_data_o <= data;
            pB_wb_we_o   <= we;
            pB_wb_stb_o  <= 1;
            pB_wb_cyc_o  <= 1;

            timeout = 0;
            while (pB_wb_stall_i && timeout < 1000) begin
                @(posedge clk_o);
                timeout++;
            end
            if (timeout == 1000)
                $fatal(1, "Timeout waiting for stall B to drop at addr %h", addr);

            timeout = 0;
            while (!pB_wb_ack_i && timeout < 1000) begin
                @(posedge clk_o);
                timeout++;
            end
            if (timeout == 1000)
                $fatal(1,"Timeout waiting for ack B at addr %h", addr);

            @(posedge clk_o);
            $display("B: ACK @ %t | addr = %h, we = %h, data_i = %h, data_o = %h",
                $time, addr, we, data, pB_wb_data_i);

            pB_wb_stb_o <= 0;
            pB_wb_we_o  <= 0;
            wait (pB_wb_ack_i == 0);
            pB_wb_cyc_o <= 0;
        end
    endtask


endmodule
