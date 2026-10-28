// SPDX-License-Identifier: GPL-3.0-or-later
// Integrated RGB test through the real video_adapter and cheat_osd pipeline.
`timescale 1ns/1ps
module tb_cheat_video_rgb;
    reg clk=0; always #5 clk=~clk;
    reg reset=1, menu_show=1;
    reg [4:0] menu_selected=18;
    reg [15:0] pixel_addr=0;
    reg [17:0] pixel_data=18'h3ffff;
    reg pixel_we=0;
    wire [23:0] video_rgb;
    wire video_de, video_vs, video_hs, video_skip;
    video_adapter dut (
        .clk_sys(clk), .clk_vid(clk), .reset(reset),
        .osd_show(1'b1), .menu_show(menu_show),
        .menu_selected(menu_selected), .osd_cart(1'b0),
        .osd_mask(32'h00000001), .osd_groups(6'd32), .osd_codes(6'd1),
        .title_clk(clk), .title_reset(reset), .title_wr(1'b0),
        .title_group(5'd0), .title_col(5'd0), .title_char(6'd0), .title_end(1'b0),
        .pixel_addr(pixel_addr), .pixel_data(pixel_data), .pixel_we(pixel_we),
        .video_rgb(video_rgb), .video_de(video_de),
        .video_vs(video_vs), .video_hs(video_hs), .video_skip(video_skip)
    );
    task check_pixel(input [7:0] y, input [23:0] expected, input [255:0] label);
        begin
            // Sample well inside the row, away from glyphs and timing edges.
            @(negedge clk);
            while (!(dut.v_count == y && dut.h_count == 9'd210 && dut.vid_ce))
                @(negedge clk);
            @(posedge clk); #1;
            if (video_rgb !== expected || !video_de) begin
                $display("FAIL %s: y=%0d RGB=%h expected=%h de=%b",
                         label,y,video_rgb,expected,video_de);
                $fatal(1);
            end
        end
    endtask
    integer i;
    initial begin
        // Populate entire framebuffer white, so dimmed overlay is 3f3f3f.
        for(i=0;i<38400;i=i+1) begin
            @(negedge clk);
            pixel_we=1; pixel_addr=i;
        end
        @(negedge clk); pixel_we=0; reset=0;
        // Wait two full frames for OSD list to rebuild during vblank.
        repeat(2*308*228*2) @(negedge clk);
        check_pixel(8'd152,24'h205080,"scrolled selection 18 blue");
        check_pixel(8'd144,24'h3f3f3f,"row above selection dimmed");
        menu_selected=0;
        check_pixel(8'd16,24'h205080,"first selection blue");
        check_pixel(8'd24,24'h3f3f3f,"second row dimmed");
        menu_show=0;
        // Existing OSD is independently visible while interactive menu closes.
        // Only group zero is enabled, so rows below it are normal game pixels.
        check_pixel(8'd32,24'hffffff,"legacy enabled-only overlay restored");
        $display("PASS cheat video RGB: actual adapter highlight, scrolling and legacy pixels");
        $finish;
    end
endmodule
