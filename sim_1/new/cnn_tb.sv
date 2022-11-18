`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/09/14 17:49:50
// Design Name: 
// Module Name: cnn_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "global.vh"

`define	MAX_PATH			256


module tb();

	parameter  FRAME_WIDTH = 112;
	parameter  FRAME_HEIGHT = 48;
	parameter  SIM_FRAMES = 2;
	reg						rstn;
	reg						clk;
	reg						ee_clk;
	
	wire		rstn_ee = rstn;
	initial begin
		rstn = 1'b0;
		#1000; 
		$display("T%d rstn done#############################", $time);
		rstn = 1'b1;
	end
	
	initial begin
		clk = 1;
		forever begin
			clk = ~clk;
			#2.5;
		end
	end
	
	initial begin
		ee_clk = 1;
		forever begin
			ee_clk = ~ee_clk;
			#1.67;
		end
	end
	
	reg			[15:0]			frame_width_0;
	reg			[15:0]			frame_height_0;
	reg			[31:0]			pic_to_sim;
	reg		[`MAX_PATH*8-1:0]	sequence_name_0;
		
	
	wire		[3:0]	digit;
	wire				ready;
	itf_frame_feed 		itf(clk);
	wire				go =  itf.go;
	assign 				itf.ready = ready;
	
	initial begin
		#1000
		#1000
		itf.drive_frame(900);
//		#(100000* `TIME_COEFF)
//		$finish();
	end	
	
	
	wire	[9:0]			aa_src_rom;
	wire                    cena_src_rom;
	wire	[`WD:0]			qa_src_rom;
	wire	[9:0]			aa_weight;
	src_rom src_rom(
		.clk			(clk),
		.rstn			(rstn),
		.aa				(aa_src_rom),
		.cena			(cena_src_rom),
		.qa				(qa_src_rom)
		);
	lenet lenet(
		.clk				(clk),
		.rstn				(rstn),
		.go					(go),				
		.cena_src			(cena_src_rom),
		.aa_src				(aa_src_rom),
		.qa_src				(qa_src_rom),
		.digit				(digit),		
		.ready				(ready)
		);
	
	reg		[31:0]	digit_cnt;
	always @(`CLK_RST_EDGE)
		if (`RST)			digit_cnt <= 0;
		else if (ready)	begin
			$display("T%d==process a frame %d, digit %d =============", $time, digit_cnt, digit);
			digit_cnt <= digit_cnt + 1;
		end

	
	
`ifdef DUMP_FSDB 
	initial begin
	$fsdbDumpfile("fsdb/xx.fsdb");
	$fsdbDumpvars();
	end
`endif

endmodule


interface itf_frame_feed(input clk);
	logic			go;
	logic			ready;
	
	clocking cb@( `CLK_EDGE);
		output	go;
		input 	ready;
	endclocking	
	
	//task drive_frame(logic [`MAX_PATH*8-1:0]	sequence_name; , int nframe);
	task drive_frame(int nframe);
		integer						fd;
		integer						errno;
		reg			[640-1:0]		errinfo;
		logic [`MAX_PATH*8-1:0]	sequence_name = "D:/backup/test_1000f.yuv";
		go		 <= 0;
		@cb;
		@cb;
		
		fd = $fopen(sequence_name, "rb");
		if (fd == 0) begin
			errno = $ferror(fd, errinfo);
			$display("sensor Failed to open file %0s for read.", sequence_name);
			$display("errno: %0d", errno);
			$display("reason: %0s", errinfo);
			$finish();
		end
		
		for(int f = 0; f<nframe; f=f+1 ) begin
			@cb;
			@cb;
			for(int i = 0; i< 32*32; i=i+1 ) begin
				$root.tb.src_rom.mem[i] <= $fgetc(fd);
			end
			@cb;
			@cb;
			go		 <= 1;
			@cb;
			go		 <= 0;
			@cb.ready;
			@cb;
			@cb;
		end
	endtask

endinterface
