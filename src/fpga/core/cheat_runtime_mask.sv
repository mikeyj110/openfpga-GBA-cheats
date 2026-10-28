// SPDX-License-Identifier: GPL-3.0-or-later
// Runtime-only per-group selections. Does not rewrite loaded cheat data.
// On loading a new cheat file, all declared groups default to enabled.
module cheat_runtime_mask (
    input wire clk,
    input wire reset,
    input wire [5:0] group_count,
    input wire toggle,
    input wire [4:0] selected,
    output reg [31:0] enable_mask
);
    wire [31:0] valid_mask = (group_count >= 6'd32) ? 32'hffffffff :
                              ((32'h00000001 << group_count) - 32'h00000001);
    always @(posedge clk) begin
        if (reset)
            enable_mask <= 32'hffffffff;
        else if (toggle && {1'b0, selected} < group_count)
            enable_mask <= enable_mask ^ (32'h00000001 << selected);
    end
endmodule
