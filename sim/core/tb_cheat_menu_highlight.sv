// SPDX-License-Identifier: GPL-3.0-or-later
// Check the exact highlight geometry used by video_adapter.
`timescale 1ns/1ps
module tb_cheat_menu_highlight;
    reg menu_show=0, osd_active=0;
    reg [4:0] menu_selected=0;
    reg [7:0] v_count=0;
    wire [5:0] menu_row = ({1'b0, menu_selected} >= 6'd18) ?
        6'd17 : {1'b0, menu_selected};
    wire [7:0] menu_y_start = 8'd16 + {menu_row, 3'b000};
    wire menu_highlight = menu_show && osd_active &&
        (v_count >= menu_y_start) &&
        (v_count < menu_y_start + 8'd8);
    task check(input condition, input [255:0] label);
        begin if (!condition) begin $display("FAIL %s", label); $fatal(1); end end
    endtask
    integer i;
    initial begin
        menu_show=1; osd_active=1;
        for (i=0;i<32;i=i+1) begin
            menu_selected=i;
            v_count=16+((i<18)?i:17)*8;
            #1; check(menu_highlight, "selected row first pixel");
            v_count=v_count+7;
            #1; check(menu_highlight, "selected row last pixel");
            v_count=v_count+1;
            #1; check(!menu_highlight, "highlight stops after row");
        end
        menu_selected=18; v_count=152;
        menu_show=0; #1; check(!menu_highlight, "hidden menu has no highlight");
        menu_show=1; osd_active=0; #1; check(!menu_highlight, "inactive overlay has no highlight");
        $display("PASS cheat highlight geometry: all 32 selections and row boundaries");
        $finish;
    end
endmodule
