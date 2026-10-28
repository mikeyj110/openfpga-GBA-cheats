// SPDX-License-Identifier: GPL-3.0-or-later
// Standalone, clock-domain-local input controller for a future cheat editor.
// This module does not render pixels or alter the cheat engine.
module cheat_menu_input #(
    parameter integer DEBOUNCE_CYCLES = 500000
) (
    input wire clk,
    input wire reset,
    input wire [31:0] keys,
    output reg menu_open,
    output reg [4:0] selected,
    output wire consume_game_keys,
    output reg toggle_selected
);
    // Pocket: Up=0 Down=1 A=4 B=5 L=8 R=9 Select=14 Start=15.
    // Open/close: L+R+Select, with a rising edge on the complete chord.
    wire chord = keys[8] && keys[9] && keys[14];
    reg chord_prev;
    reg [31:0] cooldown;
    reg up_prev, down_prev, a_prev, b_prev;
    wire ready = cooldown == 0;
    assign consume_game_keys = menu_open || chord;

    always @(posedge clk) begin
        if (reset) begin
            menu_open <= 1'b0;
            selected <= 5'd0;
            toggle_selected <= 1'b0;
            chord_prev <= 1'b0;
            up_prev <= 1'b0;
            down_prev <= 1'b0;
            a_prev <= 1'b0;
            b_prev <= 1'b0;
            cooldown <= 0;
        end else begin
            chord_prev <= chord;
            up_prev <= keys[0];
            down_prev <= keys[1];
            a_prev <= keys[4];
            b_prev <= keys[5];
            toggle_selected <= 1'b0;
            if (!ready)
                cooldown <= cooldown - 1'b1;
            if (chord && !chord_prev && ready) begin
                menu_open <= ~menu_open;
                cooldown <= DEBOUNCE_CYCLES;
            end else if (menu_open && !chord) begin
                if (keys[5] && !b_prev)
                    menu_open <= 1'b0;
                else if (keys[0] && !up_prev)
                    selected <= selected - 5'd1;
                else if (keys[1] && !down_prev)
                    selected <= selected + 5'd1;
                else if (keys[4] && !a_prev)
                    toggle_selected <= 1'b1;
            end
        end
    end
endmodule
