// SPDX-License-Identifier: GPL-3.0-or-later
`timescale 1ns/1ps
module tb_cheat_runtime_mask;
    reg clk=0; always #5 clk=~clk;
    reg reset=1, toggle=0;
    reg [5:0] group_count=3;
    reg [4:0] selected=0;
    wire [31:0] enable_mask;
    cheat_runtime_mask dut(.clk(clk),.reset(reset),.group_count(group_count),
        .toggle(toggle),.selected(selected),.enable_mask(enable_mask));
    task tick; begin @(posedge clk); #1; end endtask
    task check(input condition, input [255:0] message);
        begin if (!condition) begin $display("FAIL %s",message); $fatal(1); end end
    endtask
    initial begin
        tick(); reset=0; tick();
        check(enable_mask==32'hffffffff,"all groups initially enabled");
        selected=1; toggle=1; tick(); toggle=0; tick();
        check(!enable_mask[1] && enable_mask[0] && enable_mask[2],"selected group toggles independently");
        selected=2; toggle=1; tick(); toggle=0; tick();
        check(!enable_mask[1] && !enable_mask[2],"selection state persists");
        selected=1; toggle=1; tick(); toggle=0; tick();
        check(enable_mask[1] && !enable_mask[2],"second toggle restores group");
        selected=3; toggle=1; tick(); toggle=0; tick();
        check(enable_mask[3],"out-of-range group cannot toggle");
        reset=1; tick(); reset=0; tick();
        check(enable_mask==32'hffffffff,"new cheat file resets runtime selections");
        group_count=32; selected=31; toggle=1; tick(); toggle=0; tick();
        check(!enable_mask[31],"last of 32 groups toggles");
        $display("PASS cheat runtime mask: toggles, bounds, persistence and reload");
        $finish;
    end
endmodule
