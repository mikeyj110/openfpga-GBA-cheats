// SPDX-License-Identifier: GPL-3.0-or-later
`timescale 1ns/1ps
module tb_cheat_menu_input;
    reg clk = 0, reset = 1;
    reg [31:0] keys = 0;
    reg [5:0] group_count = 3;
    wire menu_open, consume_game_keys, toggle_selected;
    wire [4:0] selected;
    always #5 clk = ~clk;
    cheat_menu_input #(.DEBOUNCE_CYCLES(2)) dut (
        .clk(clk), .reset(reset), .keys(keys), .group_count(group_count), .menu_open(menu_open),
        .selected(selected), .consume_game_keys(consume_game_keys),
        .toggle_selected(toggle_selected)
    );
    task tick; begin @(posedge clk); #1; end endtask
    task check(input condition, input [255:0] message);
        begin if (!condition) begin $display("FAIL: %s", message); $fatal(1); end end
    endtask
    initial begin
        tick(); reset=0; tick();
        check(!menu_open, "starts closed");
        keys[8]=1; keys[9]=1; keys[14]=1; tick();
        check(menu_open && consume_game_keys, "chord opens and captures input");
        tick(); tick(); tick();
        check(menu_open, "held chord does not retrigger");
        keys=0; tick();
        keys[1]=1; tick();
        check(selected==1, "down selects next");
        tick(); check(selected==1, "held down moves once");
        keys=0; tick(); keys[1]=1; tick();
        check(selected==2, "down selects last group");
        keys=0; tick(); keys[1]=1; tick();
        check(selected==2, "down clamps at last group");
        keys=0; tick(); keys[0]=1; tick();
        check(selected==1, "up moves back");
        group_count=1; keys=0; tick();
        check(selected==0, "selection clamps when group count shrinks");
        keys=0; tick();
        keys[4]=1; tick();
        check(toggle_selected, "A generates toggle pulse");
        tick(); check(!toggle_selected, "toggle pulse is one cycle");
        keys=0; tick();
        keys[5]=1; tick();
        check(!menu_open, "B closes");
        keys=0; tick();
        check(!consume_game_keys, "game input released");
        $display("PASS: cheat menu input");
        $finish;
    end
endmodule
