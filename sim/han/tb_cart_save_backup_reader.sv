`timescale 1ns/1ps
module tb_cart_save_backup_reader;
    reg clk=0;
    always #5 clk=~clk;
    reg reset_n=0, start=0, exclusive_grant=0, save_done=0;
    reg [16:0] byte_count=0;
    reg [7:0] save_dout=0;
    wire save_req, save_rnw, byte_valid, busy, done, error;
    wire [16:0] save_addr, byte_offset;
    wire [7:0] byte_data;
    integer seen=0, cycles=0;
    cart_save_backup_reader dut(
        .clk(clk), .reset_n(reset_n), .start(start),
        .exclusive_grant(exclusive_grant), .byte_count(byte_count),
        .save_req(save_req), .save_addr(save_addr), .save_rnw(save_rnw),
        .save_dout(save_dout), .save_done(save_done),
        .byte_valid(byte_valid), .byte_offset(byte_offset), .byte_data(byte_data),
        .busy(busy), .done(done), .error(error)
    );
    // Simulated read-only cartridge: acknowledge each request one cycle later.
    always @(posedge clk) begin
        save_done <= save_req;
        if (save_req) begin
            if (!save_rnw) $fatal(1,"write attempted");
            save_dout <= save_addr[7:0] ^ 8'h5a;
        end
    end
    always @(negedge clk) begin
        if (byte_valid) begin
            if (byte_offset !== seen || byte_data !== ((seen & 255) ^ 8'h5a))
                $fatal(1,"bad stream at %0d: offset=%0d data=%h",seen,byte_offset,byte_data);
            seen=seen+1;
        end
    end
    initial begin
        repeat(3) @(negedge clk);
        reset_n=1;
        exclusive_grant=1;
        byte_count=4;
        start=1;
        @(negedge clk); start=0;
        while (!done && cycles<100) begin @(negedge clk); cycles=cycles+1; end
        if (!done || error || seen!=4 || busy) $fatal(1,"read test failed");
        @(negedge clk);
        exclusive_grant=0; start=1;
        @(negedge clk); start=0;
        @(negedge clk);
        if (!error || busy) $fatal(1,"grant rejection failed");
        $display("PASS cart_save_backup_reader");
        $finish;
    end
endmodule
