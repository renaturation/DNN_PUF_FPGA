
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/08/11
// Design Name: 
// Module Name: lenet_top
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


module lenet_top(
    input clk,
    input rstn,
    output reg led1,
    output reg led2
	);

    reg         [31:0]  time_cnt;
    reg                go;
    reg                flag_go;
    wire		[3:0]	digit;
	wire				ready;

    
	always @(`CLK_RST_EDGE)
        if (`RST) begin
            go <= 0;
            time_cnt <= 32'd0;
            flag_go <= 0;
        end
        else if (time_cnt >= 32'd4_999_999) begin // wait 1s
            go <= 1;
            time_cnt <= 32'd0;
            flag_go <= 1;
        end
        else if (!flag_go) begin
            go <= go;
            time_cnt <= time_cnt + 1;
        end
        else begin
            go <= 0;
            time_cnt <= 32'd0;
        end

    wire	[9:0]			aa_src_rom;
	wire                    cena_src_rom;
	wire	[`WD:0]			qa_src_rom;

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


    always @(`CLK_RST_EDGE)
		if (`RST) begin
            led1 <= 0;
            led2 <= 0;
        end
		else if (ready)begin
            led1 <= ~(digit[3] & digit[2]);
            led2 <= ~(digit[1] & digit[0]);
        end

ila_0 ila_inst(
    .clk(clk),
    .probe0(go),
    .probe1(ready),
    .probe2(digit),
    .probe3(led1),
    .probe4(led2),
    .probe5(time_cnt)
);

endmodule
