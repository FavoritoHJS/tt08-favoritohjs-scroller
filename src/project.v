/*
 * Copyright (c) 2024 FavoritoHJS
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

/*IDEA: Parallax scrolling city, 4 layers*/
module tt_um_favoritohjs_scroller (
	input  wire [7:0] ui_in,    // Dedicated inputs
	output wire [7:0] uo_out,   // Dedicated outputs
	input  wire [7:0] uio_in,   // IOs: Input path
	output wire [7:0] uio_out,  // IOs: Output path
	output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
	input  wire       ena,      // always 1 when the design is powered, so you can ignore it
	input  wire       clk,      // clock
	input  wire       rst_n     // reset_n - low to reset
);

	// All output pins must be assigned. If not used, assign to 0.
	// assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
	assign uio_out = 0;
	assign uio_oe  = 0;
	reg[8:0] lfsr1;
	reg[8:0] lfsr1b;
	reg[2:0] count1;
	reg[2:0] count1b;
	reg[4:0] cutoff1;
	reg[3:0] framecount;
	wire     visible;

	wire[3:0] l1 = lfsr1[3:0];
	//https://github.com/algofoogle/tt05-vga-spi-rom/blob/main/src/test/tb.v
	reg[1:0]  r, g, b;
	wire      hsync;
	wire      vsync;
	wire[9:0] hcount;
	wire[9:0] vcount;
	reg      carry;
	assign uo_out[7] = hsync;
	assign uo_out[3] = vsync;
	assign {uo_out[0], uo_out[4]} = r;
	assign {uo_out[1], uo_out[5]} = g;
	assign {uo_out[2], uo_out[6]} = b;


	vga_sync vga_sync(
		.hcount(hcount),
		.vcount(vcount),
		.hsync(hsync),
		.vsync(vsync),
		.visible(visible),
		.clk(clk),
		.rst_n(rst_n)
	);
	always @(posedge clk) begin
		if (~rst_n) begin
			lfsr1 <= 9'h1ff;
			lfsr1b <= 9'h1ff;
			count1 <= 3'd7;
			count1b <= 3'd7;
			cutoff1 <= 5'd0;
			r <= 2'b00;
			g <= 2'b00;
			b <= 2'b00;
		end else begin
			// TODO: Read multiple bits out at the same time.
			// https://zipcpu.com/dsp/2017/11/13/lfsr-multi.html
			if (visible) begin
				count1 <= count1 + 1;
				if (count1 == 0) begin
					lfsr1[0] <= lfsr1[8] ^ lfsr1[4];
					lfsr1[8:1] <= lfsr1[7:0];
				end
			end
			//This is executed once per scanline
			if (hcount == 656) begin
				if (vcount == 1)   cutoff1 = 0;
				if (vcount == 128) cutoff1 = 1;
				if (vcount == 144) cutoff1 = 2;
				if (vcount == 160) cutoff1 = 3;
				if (vcount == 176) cutoff1 = 4;
				if (vcount == 192) cutoff1 = 5;
				if (vcount == 208) cutoff1 = 6;
				if (vcount == 224) cutoff1 = 7;
				if (vcount == 240) cutoff1 = 8;
				if (vcount == 256) cutoff1 = 9;
				if (vcount == 272) cutoff1 = 10;
				if (vcount == 288) cutoff1 = 11;
				if (vcount == 304) cutoff1 = 12;
				if (vcount == 320) cutoff1 = 13;
				if (vcount == 336) cutoff1 = 14;
				if (vcount == 352) cutoff1 = 15;
				if (vcount == 368) cutoff1 = 16;
				//and this once per frame
				if (vcount == 481) begin
					count1b <= count1b  + 1;
					if (count1b == 0) begin
						lfsr1b[0] <= lfsr1b[8] ^ lfsr1b[4];
						lfsr1b[8:1] <= lfsr1b[7:0];
					end
				end
				lfsr1 <= lfsr1b;
				count1 <= count1b;
			end
		end
	end
	always @(posedge clk) begin
		if (visible) begin
			if (l1 < cutoff1) begin
				r <= 2'b11;
				g <= 2'b10;
				b <= 2'b00;
			end else begin
				r <= 2'b01;
				g <= 2'b10;
				b <= 2'b11;
			end
		end else begin
			r <= 2'b00;
			g <= 2'b00;
			b <= 2'b00;
		end
	end
	// List all unused inputs to prevent warnings
	wire _unused = &{ena, 1'b0};

endmodule

//https://github.com/algofoogle/tt05-vga-spi-rom/blob/main/src/vga_sync.v
/*TODO: Optimize by doing LFSR shenanigans?*/
module vga_sync(
	input wire clk,
	input wire rst_n,
	output wire[9:0] hcount,
	output wire[9:0] vcount,
	output wire visible,
	output wire vsync,
	output wire hsync
);
	reg[9:0] vga_xpos;
	reg[9:0] vga_ypos;
	reg      vga_vsync, vga_hsync;
	assign vsync = vga_vsync;
	assign hsync = vga_hsync;
	assign hcount = vga_xpos;
	assign vcount = vga_ypos;
	always @(posedge clk) begin
		if (~rst_n) begin
			vga_xpos <= 10'd1;
			vga_ypos <= 10'd1;
		end else begin
			//This code seems very odd, but apparently it works in real hardware?
			//TODO: This can be optimized by only reading the top few bits.
			if (vga_xpos == 10'd800) begin
				vga_xpos <= 1;
				if (vga_ypos == 10'd525) vga_ypos <= 1;
				else vga_ypos <= vga_ypos + 1;
			end
			else vga_xpos <= vga_xpos + 1;
		end

	end

	wire xvisible, yvisible;
	assign xvisible = (vga_xpos < 10'd640);
	assign yvisible = (vga_ypos < 10'd480);
	assign visible = xvisible && yvisible;
	always @(posedge clk) begin
		if (~rst_n) begin
			vga_hsync <= 1'b1;
			vga_vsync <= 1'b1;
		end else begin
			if      (vga_xpos == 10'd656) vga_hsync <= 1'b0;
			else if (vga_xpos == 10'd752) vga_hsync <= 1'b1;
			if      (vga_ypos == 10'd490) vga_vsync <= 1'b0;
			else if (vga_ypos == 10'd492) vga_vsync <= 1'b1;
		end
	end
endmodule
