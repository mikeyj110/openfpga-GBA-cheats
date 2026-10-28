// SPDX-License-Identifier: GPL-3.0-or-later
// Checks interactive display-list membership, scrolling and legacy behavior.
// White-box test: the list is assembled during vertical blanking.
`timescale 1ns/1ps
module tb_cheat_osd_menu;
    reg clk=0;
    always #5 clk=~clk;
    reg reset=1, show=1, menu_show=0, vb=0;
    reg [4:0] menu_selected=0;
    reg [31:0] mask=32'h80000001;
    reg [5:0] groups=6'd32;
    wire [4:0] title_group, title_col;
    wire [5:0] font_ch;
    wire [2:0] font_row;
    wire active, ink;
    cheat_osd dut(
        .clk(clk), .reset(reset), .ce(1'b0), .show(show),
        .menu_show(menu_show), .menu_selected(menu_selected),
        .cart_mode(1'b0), .de(1'b0), .v_blank(vb),
        .enable_mask(mask), .group_count(groups), .code_count(6'd2),
        .title_group(title_group), .title_col(title_col),
        .title_char(6'd0), .title_len(5'd0),
        .font_ch(font_ch), .font_row(font_row), .font_bits(8'd0),
        .active(active), .ink(ink)
    );
    task rebuild;
        begin
            @(negedge clk); vb=1;
            repeat (3) @(negedge clk);
            vb=0;
            repeat (40) @(negedge clk);
        end
    endtask
    task check(input condition, input [255:0] message);
        begin
            if (!condition) begin
                $display("FAIL: %s", message);
                $fatal(1);
            end
        end
    endtask
    integer i;
    initial begin
        repeat(3) @(negedge clk); reset=0;
        rebuild();
        check(dut.list_n==2, "legacy mode shows only enabled groups");
        check(dut.list[0]==0 && dut.list[1]==31, "legacy groups preserve original indices");

        menu_show=1; menu_selected=0; rebuild();
        check(dut.list_n==18, "interactive mode fills 18 visible rows");
        for(i=0;i<18;i=i+1)
            check(dut.list[i]==i, "first viewport includes disabled groups in order");

        menu_selected=17; rebuild();
        check(dut.list[0]==0 && dut.list[17]==17, "selection 17 stays on first page");

        menu_selected=18; rebuild();
        check(dut.list[0]==1 && dut.list[17]==18, "selection 18 scrolls one row");

        menu_selected=31; rebuild();
        check(dut.list_n==18, "last viewport still fills screen");
        check(dut.list[0]==14 && dut.list[17]==31, "selection 31 scrolls to last group");

        menu_show=0; rebuild();
        check(dut.list_n==2 && dut.list[0]==0 && dut.list[1]==31,
              "closing menu restores enabled-only list");

        $display("PASS cheat interactive viewport: 32 groups, disabled rows, scrolling and legacy restoration");
        $finish;
    end
endmodule
