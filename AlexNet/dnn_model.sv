
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/08/11
// Design Name: 
// Module Name: dnn module
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


module dnn_model(
	input					clk,
	input					rstn,
	input					go,
	output					cena_src,
	output		[9:0]		aa_src,
	input		[`WD:0]		qa_src,
	output reg	[3:0]		digit,
	output 					ready
	);
	

	//=============================================================================
	//  CONV 1
	//  224*224*1 -> 54*54*64, kernel_size = 11*11, stride=4
	wire		[`W_AA:0]							aa_weight_conv1;
	wire		[`WDP*`OUTPUT_NUM_CONV1-1:0]		qa_weight_conv1;
	
	wire		[`W_AA:0]							aa_bias_conv1;
	wire		[`WDP_BIAS*`OUTPUT_NUM_CONV1 -1:0]	qa_bias_conv1;

	weight_conv1_rom weight_conv1_rom(
		.clk			(clk),
		.rstn			(rstn),
		.aa				(aa_weight_conv1),
		.cena			(cena_src),
		.qa				(qa_weight_conv1)
	);

	bias_conv1_rom bias_conv1_rom(
		.clk			(clk),
		.rstn			(rstn),
		.aa				(aa_bias_conv1),
		.cena			(cena_src),
		.qa				(qa_bias_conv1)
	);

	wire	conv1_go = go;
    wire    first_data, last_data, conv1_ready;

	iterator  #(
		.OUTPUT_BATCH	(`OUTPUT_BATCH_CONV1),
		.KERNEL_SIZEX	(`KERNEL_SIZEX_CONV1),
		.KERNEL_SIZEY	(`KERNEL_SIZEY_CONV1),
		.STEP			(1),
		.INPUT_WIDTH	(`INPUT_WIDTH),
		.INPUT_HEIGHT	(`INPUT_HEIGHT)
		)iterator_conv1(
		.clk				(clk),
		.rstn				(rstn),
		.go					(conv1_go),
		.first_data			(first_data),
		.last_data			(last_data),
		.aa_bias			(aa_bias_conv1),
		.aa_data			(aa_src),
		.aa_weight			(aa_weight_conv1),
		.cena				(cena_src),
		.ready          	(conv1_ready)
	); 
	
	reg		[15:0]	first_data_d;
	always @(*)	first_data_d[0] = first_data;
	always @(`CLK_RST_EDGE)
		if (`RST)	first_data_d[15:1] <= 0;
		else 		first_data_d[15:1] <= first_data_d;

	reg		[15:0]	last_data_d;
	always @(*)	last_data_d[0] = last_data;
	always @(`CLK_RST_EDGE)
		if (`RST)	last_data_d[15:1] <= 0;
		else 		last_data_d[15:1] <= last_data_d;
		
	reg		[15:0]	cena_src_d;
	always @(*)	cena_src_d[0] = cena_src;
	always @(`CLK_RST_EDGE)
		if (`RST)	cena_src_d[15:1] <= 0;
		else 		cena_src_d[15:1] <= cena_src_d;

	wire	[`WDP*`OUTPUT_NUM_CONV1 -1:0] qa_conv1;	
	wire    qa_conv1_en;
	conv #(
		.INPUT_NUM		(`INPUT_NUM),
		.OUTPUT_NUM		(`OUTPUT_NUM),
		.WIGHT_SHIFT	(`WIGHT_SHIFT)
		)conv1(
		.clk			(clk),
		.rstn			(rstn),
		.en				(~cena_src_d[1]),
		.first_data		(first_data_d[1]),
		.last_data		(last_data_d[1]),
		.data_i			(qa_src),
		.bias			(qa_bias_conv1),
		.weight			(qa_weight_conv1),
		.q              (qa_conv1),
		.q_en           (qa_conv1_en)
	);
	
	reg		[`W_AA:0]	aa_conv1_buf;
	reg				cena_conv1_buf;
	reg		[`W_AA:0]	ab_conv1_buf;
	reg		[`OUTPUT_NUM_CONV1*16-1:0]	db_conv1_buf;  // a value 16bit, 64 channels is 1024 bits
	reg				cenb_conv1_buf;
	wire	[`OUTPUT_NUM_CONV1*16-1:0]	qa_conv1_buf;
	
	rfdp4096x1024 conv1_buf(
		.CLKA   (clk),
		.CENA   (cena_conv1_buf),
		.AA     (aa_conv1_buf),
		.QA     (qa_conv1_buf),
		.CLKB   (clk),
		.CENB   (cenb_conv1_buf),
		.AB     (ab_conv1_buf),
		.DB     (db_conv1_buf)
	);
	
	always @(`CLK_RST_EDGE)
		if (`ZST)	db_conv1_buf <= 0;
		else 		db_conv1_buf <= qa_conv1;
	
	always @(`CLK_RST_EDGE)
		if (`RST)	cenb_conv1_buf <= 1;
		else 		cenb_conv1_buf <= ~qa_conv1_en;
	always @(`CLK_RST_EDGE)
		if (`RST)					ab_conv1_buf <= 0;
		else if (conv1_go)			ab_conv1_buf <= 0;
		else if (!cenb_conv1_buf)	ab_conv1_buf <= ab_conv1_buf + 1;
	
	//  POOLING1
	// 54*54*64 -> 26*26*64
    // kernel_size = 3*3, stride=2
	wire	pooling1_go = conv1_ready;
	wire    first_data_pooling1, last_data_pooling1, pooling1_ready;

	iterator #(
		.OUTPUT_BATCH		(1),
		.KERNEL_SIZEX		(2),
		.KERNEL_SIZEY		(2),
		.STEP				(2),
		.INPUT_WIDTH		(`INPUT_WIDTH - `KERNEL_SIZE_CONV1 + 1),
		.INPUT_HEIGHT		(`INPUT_HEIGHT - `KERNEL_SIZE_CONV1 + 1)
	) iterator_pooling1(
		.clk				(clk),
		.rstn				(rstn),
		.go					(pooling1_go),
		.aa_data			(aa_conv1_buf),
		.cena				(cena_conv1_buf),
		.first_data			(first_data_pooling1),
		.last_data			(last_data_pooling1),
		.ready				(pooling1_ready)
	); 
	
	reg		[15:0]	cena_conv1_buf_d;
	always @(*)	cena_conv1_buf_d[0] = cena_conv1_buf;
	always @(`CLK_RST_EDGE)
		if (`RST)	cena_conv1_buf_d[15:1] <= 0;
		else 		cena_conv1_buf_d[15:1] <= cena_conv1_buf_d;

	reg		[15:0]	first_data_pooling1_d;
	always @(*)	first_data_pooling1_d[0] = first_data_pooling1;
	always @(`CLK_RST_EDGE)
		if (`RST)	first_data_pooling1_d[15:1] <= 0;
		else 		first_data_pooling1_d[15:1] <= first_data_pooling1_d;
	
	reg		[15:0]	last_data_pooling1_d;
	always @(*)	last_data_pooling1_d[0] = last_data_pooling1;
	always @(`CLK_RST_EDGE)
		if (`RST)	last_data_pooling1_d[15:1] <= 0;
		else 		last_data_pooling1_d[15:1] <= last_data_pooling1_d;
		
	wire	[`WDP*`OUTPUT_NUM_CONV1 -1:0] qa_pooling1;		
	wire								  qa_pooling1_en;

	max_pool #(
		.INPUT_NUM (`OUTPUT_NUM_CONV1)   // input plane_num
	) max_pooling1(
		.clk				(clk),
		.rstn				(rstn),
		.en					(!cena_conv1_buf_d[1]),
		.first_data			(first_data_pooling1_d[1]),
		.last_data			(last_data_pooling1_d[1]),
		.data_i				(qa_conv1_buf),
		.q_en				(qa_pooling1_en),
		.q					(qa_pooling1)
	);

	//  RELU1
	wire	[`WDP*`OUTPUT_NUM_CONV1 -1:0] qa_relu1;	
	wire    qa_relu1_en;	
	relu #(
		.INPUT_NUM (`OUTPUT_NUM_CONV1)   // input plane_num
	) relu1(
		.clk				(clk),
		.rstn				(rstn),
		.en					(qa_pooling1_en),
		.data_i				(qa_pooling1),
		
		.q_en				(qa_relu1_en),
		.q					(qa_relu1)
		
	);
	
	reg		[7:0]	aa_relu1_buf;
	reg				cena_relu1_buf;
	reg		[7:0]	ab_relu1_buf;
	reg		[`OUTPUT_NUM_CONV1*16-1:0]	db_relu1_buf; // 1024bits
	reg				cenb_relu1_buf;
	wire	[`OUTPUT_NUM_CONV1*16-1:0]	qa_relu1_buf;
	
	rfdp1024x1024 relu1_buf(
		.CLKA   (clk),
		.CENA   (cena_relu1_buf),
		.AA     (aa_relu1_buf),
		.QA     (qa_relu1_buf),
		.CLKB   (clk),
		.CENB   (cenb_relu1_buf),
		.AB     (ab_relu1_buf),
		.DB     (db_relu1_buf)
	);
	
	always @(`CLK_RST_EDGE)
		if (`ZST)	db_relu1_buf <= 0;
		else 		db_relu1_buf <= qa_relu1;
	
	always @(`CLK_RST_EDGE)
		if (`RST)	cenb_relu1_buf <= 1;
		else 		cenb_relu1_buf <= ~qa_relu1_en;
	always @(`CLK_RST_EDGE)
		if (`RST)					ab_relu1_buf <= 0;
		else if (pooling1_go)		ab_relu1_buf <= 0;
		else if (!cenb_relu1_buf)	ab_relu1_buf <= ab_relu1_buf + 1;
	
	//=============================================================================
	//  CONV2
	//  26*26*64 -> 22*22*192, kernel_size = 5*5, stride = 1
	//  26*26*64 -> 22*22*64, kernel_size = 5*5, stride = 1
	// wire		[`W_AA:0]										aa_weight_conv2;
	// wire		[`WDP*`OUTPUT_NUM_CONV1*`OUTPUT_NUM_CONV2 -1:0]	qa_weight_conv2;

	// wire		[`W_AA:0]							aa_bias_conv2;
	// wire		[`WDP_BIAS*`OUTPUT_NUM_CONV2 -1:0]	qa_bias_conv2;

	// weight_conv2_rom weight_conv2_rom(
	// 	.clk			(clk),
	// 	.rstn			(rstn),
	// 	.aa				(aa_weight_conv2),
	// 	.cena			(cena_relu1_buf),
	// 	.qa				(qa_weight_conv2)
	// 	);
		
	// bias_conv2_rom bias_conv2_rom(
	// 	.clk			(clk),
	// 	.rstn			(rstn),
	// 	.aa				(aa_bias_conv2),
	// 	.cena			(cena_relu1_buf),
	// 	.qa				(qa_bias_conv2)
	// 	);
	
	// wire	conv2_go = pooling1_ready;
	// wire    first_data_conv2, last_data_conv2, conv2_ready;

	// iterator  #(
	// 	.OUTPUT_BATCH	(`OUTPUT_BATCH_CONV2),
	// 	.KERNEL_SIZEX	(`KERNEL_SIZEX_CONV2),
	// 	.KERNEL_SIZEY	(`KERNEL_SIZEY_CONV2),
	// 	.STEP			(1),
	// 	.INPUT_WIDTH	(`INPUT_WIDTH_CONV2),
	// 	.INPUT_HEIGHT	(`INPUT_HEIGHT_CONV2)
	// 	)iterator_conv2(
	// 	.clk				(clk),
	// 	.rstn				(rstn),
	// 	.go					(conv2_go),
	// 	.first_data			(first_data_conv2),
	// 	.last_data			(last_data_conv2),
	// 	.aa_bias			(aa_bias_conv2),
	// 	.aa_data			(aa_relu1_buf),
	// 	.aa_weight			(aa_weight_conv2),
	// 	.cena				(cena_relu1_buf),
	// 	.ready          	(conv2_ready)
	// ); 
	
	// reg		[15:0]	cena_relu1_buf_d;  // equal first_data_d
	// always @(*)	cena_relu1_buf_d[0] = cena_relu1_buf;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	cena_relu1_buf_d[15:1] <= 0;
	// 	else 		cena_relu1_buf_d[15:1] <= cena_relu1_buf_d;

	// reg		[15:0]	last_data_conv2_d;  //  equal to last_data_d
	// always @(*)	last_data_conv2_d[0] = last_data_conv2;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	last_data_conv2_d[15:1] <= 0;
	// 	else 		last_data_conv2_d[15:1] <= last_data_conv2_d;

	// reg		[15:0]	first_data_conv2_d;
	// always @(*)	first_data_conv2_d[0] = first_data_conv2;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	first_data_conv2_d[15:1] <= 0;
	// 	else 		first_data_conv2_d[15:1] <= first_data_conv2_d;

	// wire	[`WDP*`OUTPUT_NUM_CONV2 -1:0] qa_conv2;	
	// wire 								  qa_conv2_en;
	// conv #(
	// 	.INPUT_NUM		(`OUTPUT_NUM_CONV1),
	// 	.OUTPUT_NUM		(`OUTPUT_NUM_CONV2),
	// 	.WIGHT_SHIFT	(`WIGHT_SHIFT)
	// 	)conv2(
	// 	.clk			(clk),
	// 	.rstn			(rstn),
	// 	.en				(~cena_relu1_buf_d[1]),
	// 	.first_data		(first_data_conv2_d[1]),
	// 	.last_data		(last_data_conv2_d[1]),
	// 	.data_i			(qa_relu1_buf),
	// 	.bias			(qa_bias_conv2),
	// 	.weight			(qa_weight_conv2),
	// 	.q              (qa_conv2),
	// 	.q_en           (qa_conv2_en)
	// );
	
	// reg		[`W_AA:0]	aa_conv2_buf;
	// reg				cena_conv2_buf;
	// reg		[`W_AA:0]	ab_conv2_buf;
	// reg		[`OUTPUT_NUM_CONV2*16-1:0]	db_conv2_buf;  // a value 16bit, 192 channels is 3072 bits
	// reg				cenb_conv2_buf;
	// wire	[`OUTPUT_NUM_CONV2*16-1:0]	qa_conv2_buf;
	
	// rfdp1024x1024 conv2_buf(
	// 	.CLKA   (clk),
	// 	.CENA   (cena_conv2_buf),
	// 	.AA     (aa_conv2_buf),
	// 	.QA     (qa_conv2_buf),
	// 	.CLKB   (clk),
	// 	.CENB   (cenb_conv2_buf),
	// 	.AB     (ab_conv2_buf),
	// 	.DB     (db_conv2_buf)
	// );
	
	// always @(`CLK_RST_EDGE)
	// 	if (`ZST)	db_conv2_buf <= 0;
	// 	else 		db_conv2_buf <= qa_conv2;

	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	cenb_conv2_buf <= 1;
	// 	else 		cenb_conv2_buf <= ~qa_conv2_en;

	// always @(`CLK_RST_EDGE)
	// 	if (`RST)					ab_conv2_buf <= 0;
	// 	else if (conv2_go)			ab_conv2_buf <= 0;
	// 	else if (!cenb_conv2_buf)	ab_conv2_buf <= ab_conv2_buf + 1;
	
	// //  POOLING2
	// // 22*22*192 -> 20*20*192
	// // kernel_size = 3*2, stride = 2
	// wire	pooling2_go = conv2_ready;
	// wire    first_data_pooling2, last_data_pooling2, pooling2_ready;

	// iterator #(
	// 	.OUTPUT_BATCH		(1),
	// 	.KERNEL_SIZEX		(2),
	// 	.KERNEL_SIZEY		(2),
	// 	.STEP				(2),
	// 	.INPUT_WIDTH		(`INPUT_WIDTH_CONV2 - `KERNEL_SIZE_CONV2 + 1),
	// 	.INPUT_HEIGHT		(`INPUT_HEIGHT_CONV2 - `KERNEL_SIZE_CONV2 + 1)
	// ) iterator_pooling2(
	// 	.clk				(clk),
	// 	.rstn				(rstn),
	// 	.go					(pooling2_go),
	// 	.aa_data			(aa_conv2_buf),
	// 	.cena				(cena_conv2_buf),
	// 	.first_data			(first_data_pooling2),
	// 	.last_data			(last_data_pooling2),
	// 	.ready				(pooling2_ready)
	// ); 
	
	// reg		[15:0]	cena_conv2_buf_d;
	// always @(*)	cena_conv2_buf_d[0] = cena_conv2_buf;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	cena_conv2_buf_d[15:1] <= 0;
	// 	else 		cena_conv2_buf_d[15:1] <= cena_conv2_buf_d;

	// reg		[15:0]	first_data_pooling2_d;
	// always @(*)	first_data_pooling2_d[0] = first_data_pooling2;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	first_data_pooling2_d[15:1] <= 0;
	// 	else 		first_data_pooling2_d[15:1] <= first_data_pooling2_d;
	
	// reg		[15:0]	last_data_pooling2_d;
	// always @(*)	last_data_pooling2_d[0] = last_data_pooling2;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	last_data_pooling2_d[15:1] <= 0;
	// 	else 		last_data_pooling2_d[15:1] <= last_data_pooling2_d;

	// wire	[`WDP*`OUTPUT_NUM_CONV2 -1:0] qa_pooling2;	
	// wire								  qa_pooling2_en;
	
	// max_pool #(
	// 	.INPUT_NUM (`OUTPUT_NUM_CONV2)   // input plane_num
	// ) max_pooling2(
	// 	.clk				(clk),
	// 	.rstn				(rstn),
	// 	.en					(!cena_conv2_buf_d[1]),
	// 	.first_data			(first_data_pooling2_d[1]),
	// 	.last_data			(last_data_pooling2_d[1]),
	// 	.data_i				(qa_conv2_buf),
	// 	.q_en				(qa_pooling2_en),
	// 	.q					(qa_pooling2)
	// );

	// //  RELU2	
	// wire	[`WDP*`OUTPUT_NUM_CONV2 -1:0] qa_relu2;	
	// wire    qa_relu2_en;		
	// relu #(
	// 	.INPUT_NUM (`OUTPUT_NUM_CONV2)   // input plane_num
	// ) relu2(
	// 	.clk				(clk),
	// 	.rstn				(rstn),
	// 	.en					(qa_pooling2_en),
	// 	.data_i				(qa_pooling2),
		
	// 	.q_en				(qa_relu2_en),
	// 	.q					(qa_relu2)
	// );
	
	// reg		[`W_AA:0]	aa_relu2_buf;
	// reg				cena_relu2_buf;
	// reg		[`W_AA:0]	ab_relu2_buf;
	// reg		[`OUTPUT_NUM_CONV2*16-1:0]	db_relu2_buf;
	// reg				cenb_relu2_buf;
	// wire	[`OUTPUT_NUM_CONV2*16-1:0]	qa_relu2_buf;
	
	// rfdp1024x1024 relu2_buf(
	// 	.CLKA   (clk),
	// 	.CENA   (cena_relu2_buf),
	// 	.AA     (aa_relu2_buf),
	// 	.QA     (qa_relu2_buf),
	// 	.CLKB   (clk),
	// 	.CENB   (cenb_relu2_buf),
	// 	.AB     (ab_relu2_buf),
	// 	.DB     (db_relu2_buf)
	// );
	
	
	// always @(`CLK_RST_EDGE)
	// 	if (`ZST)	db_relu2_buf <= 0;
	// 	else 		db_relu2_buf <= qa_relu2;
	
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	cenb_relu2_buf <= 1;
	// 	else 		cenb_relu2_buf <= ~qa_relu2_en;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)					ab_relu2_buf <= 0;
	// 	else if (pooling2_go)		ab_relu2_buf <= 0;
	// 	else if (!cenb_relu2_buf)	ab_relu2_buf <= ab_relu2_buf + 1;


	// //=============================================================================
	// //  CONV3
	// //  20*20*192 -> 18*18*384, kernel_size = 3*3, stride = 1
	// //  20*20*64 -> 18*18*64, kernel_size = 3*3, stride = 1
	// wire		[`W_AA:0]										aa_weight_conv3;
	// wire		[`WDP*`OUTPUT_NUM_CONV2*`OUTPUT_NUM_CONV3 -1:0]	qa_weight_conv3;

	// wire		[`W_AA:0]							aa_bias_conv3;
	// wire		[`WDP_BIAS*`OUTPUT_NUM_CONV3 -1:0]	qa_bias_conv3;

	// weight_conv3_rom weight_conv3_rom(
	// 	.clk			(clk),
	// 	.rstn			(rstn),
	// 	.aa				(aa_weight_conv3),
	// 	.cena			(cena_relu2_buf),
	// 	.qa				(qa_weight_conv3)
	// 	);
		
	// bias_conv3_rom bias_conv3_rom(
	// 	.clk			(clk),
	// 	.rstn			(rstn),
	// 	.aa				(aa_bias_conv3),
	// 	.cena			(cena_relu2_buf),
	// 	.qa				(qa_bias_conv3)
	// 	);
	
	// wire	conv3_go = pooling2_ready;
	// wire    first_data_conv3, last_data_conv3, conv3_ready;

	// iterator  #(
	// 	.OUTPUT_BATCH	(`OUTPUT_BATCH_CONV3),
	// 	.KERNEL_SIZEX	(`KERNEL_SIZEX_CONV3),
	// 	.KERNEL_SIZEY	(`KERNEL_SIZEY_CONV3),
	// 	.STEP			(1),
	// 	.INPUT_WIDTH	(`INPUT_WIDTH_CONV3),
	// 	.INPUT_HEIGHT	(`INPUT_HEIGHT_CONV3)
	// 	)iterator_conv3(
	// 	.clk				(clk),
	// 	.rstn				(rstn),
	// 	.go					(conv3_go),
	// 	.first_data			(first_data_conv3),
	// 	.last_data			(last_data_conv3),
	// 	.aa_bias			(aa_bias_conv3),
	// 	.aa_data			(aa_relu2_buf),
	// 	.aa_weight			(aa_weight_conv3),
	// 	.cena				(cena_relu2_buf),
	// 	.ready          	(conv3_ready)
	// ); 
	
	// reg		[15:0]	cena_relu2_buf_d;  // equal first_data_d
	// always @(*)	cena_relu2_buf_d[0] = cena_relu2_buf;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	cena_relu2_buf_d[15:1] <= 0;
	// 	else 		cena_relu2_buf_d[15:1] <= cena_relu2_buf_d;

	// reg		[15:0]	last_data_conv3_d;  //  equal to last_data_d
	// always @(*)	last_data_conv3_d[0] = last_data_conv3;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	last_data_conv3_d[15:1] <= 0;
	// 	else 		last_data_conv3_d[15:1] <= last_data_conv3_d;

	// reg		[15:0]	first_data_conv3_d;
	// always @(*)	first_data_conv3_d[0] = first_data_conv3;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	first_data_conv3_d[15:1] <= 0;
	// 	else 		first_data_conv3_d[15:1] <= first_data_conv3_d;

	// wire	[`WDP*`OUTPUT_NUM_CONV3 -1:0] qa_conv3;	
	// wire 								  qa_conv3_en;
	// conv #(
	// 	.INPUT_NUM		(`OUTPUT_NUM_CONV2),
	// 	.OUTPUT_NUM		(`OUTPUT_NUM_CONV3),
	// 	.WIGHT_SHIFT	(`WIGHT_SHIFT)
	// 	)conv3(
	// 	.clk			(clk),
	// 	.rstn			(rstn),
	// 	.en				(~cena_relu2_buf_d[1]),
	// 	.first_data		(first_data_conv3_d[1]),
	// 	.last_data		(last_data_conv3_d[1]),
	// 	.data_i			(qa_relu2_buf),
	// 	.bias			(qa_bias_conv3),
	// 	.weight			(qa_weight_conv3),
	// 	.q              (qa_conv3),
	// 	.q_en           (qa_conv3_en)
	// );
	
	// reg		[`W_AA:0]	aa_conv3_buf;
	// reg				cena_conv3_buf;
	// reg		[`W_AA:0]	ab_conv3_buf;
	// reg		[`OUTPUT_NUM_CONV3*16-1:0]	db_conv3_buf;  // a value 16bit, 384 channels is 6144 bits
	// reg				cenb_conv3_buf;
	// wire	[`OUTPUT_NUM_CONV3*16-1:0]	qa_conv3_buf;
	
	// rfdp1024x1024 conv3_buf(
	// 	.CLKA   (clk),
	// 	.CENA   (cena_conv3_buf),
	// 	.AA     (aa_conv3_buf),
	// 	.QA     (qa_conv3_buf),
	// 	.CLKB   (clk),
	// 	.CENB   (cenb_conv3_buf),
	// 	.AB     (ab_conv3_buf),
	// 	.DB     (db_conv3_buf)
	// );
	
	// always @(`CLK_RST_EDGE)
	// 	if (`ZST)	db_conv3_buf <= 0;
	// 	else 		db_conv3_buf <= qa_conv3;

	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	cenb_conv3_buf <= 1;
	// 	else 		cenb_conv3_buf <= ~qa_conv3_en;

	// always @(`CLK_RST_EDGE)
	// 	if (`RST)					ab_conv3_buf <= 0;
	// 	else if (conv3_go)			ab_conv3_buf <= 0;
	// 	else if (!cenb_conv3_buf)	ab_conv3_buf <= ab_conv3_buf + 1;
	
	
	// reg		[15:0]	cena_conv3_buf_d;
	// always @(*)	cena_conv3_buf_d[0] = cena_conv3_buf;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	cena_conv3_buf_d[15:1] <= 0;
	// 	else 		cena_conv3_buf_d[15:1] <= cena_conv3_buf_d;

	// //  RELU3	
	// wire	[`WDP*`OUTPUT_NUM_CONV3 -1:0] qa_relu3;	
	// wire    qa_relu3_en;		
	// relu #(
	// 	.INPUT_NUM (`OUTPUT_NUM_CONV3)   // input plane_num
	// ) relu3(
	// 	.clk				(clk),
	// 	.rstn				(rstn),
	// 	.en					(qa_conv3_en),
	// 	.data_i				(qa_conv3),
		
	// 	.q_en				(qa_relu3_en),
	// 	.q					(qa_relu3)
	// );
	
	// reg		[`W_AA:0]	aa_relu3_buf;
	// reg				cena_relu3_buf;
	// reg		[`W_AA:0]	ab_relu3_buf;
	// reg		[`OUTPUT_NUM_CONV3*16-1:0]	db_relu3_buf;
	// reg				cenb_relu3_buf;
	// wire	[`OUTPUT_NUM_CONV3*16-1:0]	qa_relu3_buf;
	
	// rfdp1024x1024 relu3_buf(
	// 	.CLKA   (clk),
	// 	.CENA   (cena_relu3_buf),
	// 	.AA     (aa_relu3_buf),
	// 	.QA     (qa_relu3_buf),
	// 	.CLKB   (clk),
	// 	.CENB   (cenb_relu3_buf),
	// 	.AB     (ab_relu3_buf),
	// 	.DB     (db_relu3_buf)
	// );
	
	
	// always @(`CLK_RST_EDGE)
	// 	if (`ZST)	db_relu3_buf <= 0;
	// 	else 		db_relu3_buf <= qa_relu3;
	
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	cenb_relu3_buf <= 1;
	// 	else 		cenb_relu3_buf <= ~qa_relu3_en;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)					ab_relu3_buf <= 0;
	// 	else if (conv3_go)			ab_relu3_buf <= 0;
	// 	else if (!cenb_relu3_buf)	ab_relu3_buf <= ab_relu3_buf + 1;


	// //=============================================================================
	// //  CONV4
	// //  18*18*384 -> 16*16*256, kernel_size = 3*3, stride = 1
	// //  18*18*64 -> 16*16*64, kernel_size = 3*3, stride = 1
	// wire		[`W_AA:0]										aa_weight_conv4;
	// wire		[`WDP*`OUTPUT_NUM_CONV3*`OUTPUT_NUM_CONV4 -1:0]	qa_weight_conv4;

	// wire		[`W_AA:0]							aa_bias_conv4;
	// wire		[`WDP_BIAS*`OUTPUT_NUM_CONV4 -1:0]	qa_bias_conv4;

	// weight_conv4_rom weight_conv4_rom(
	// 	.clk			(clk),
	// 	.rstn			(rstn),
	// 	.aa				(aa_weight_conv4),
	// 	.cena			(cena_relu3_buf),
	// 	.qa				(qa_weight_conv4)
	// 	);
		
	// bias_conv4_rom bias_conv4_rom(
	// 	.clk			(clk),
	// 	.rstn			(rstn),
	// 	.aa				(aa_bias_conv4),
	// 	.cena			(cena_relu3_buf),
	// 	.qa				(qa_bias_conv4)
	// 	);
	
	// wire	conv4_go = conv3_ready;
	// wire    first_data_conv4, last_data_conv4, conv4_ready;

	// iterator  #(
	// 	.OUTPUT_BATCH	(`OUTPUT_BATCH_CONV4),
	// 	.KERNEL_SIZEX	(`KERNEL_SIZEX_CONV4),
	// 	.KERNEL_SIZEY	(`KERNEL_SIZEY_CONV4),
	// 	.STEP			(1),
	// 	.INPUT_WIDTH	(`INPUT_WIDTH_CONV4),
	// 	.INPUT_HEIGHT	(`INPUT_HEIGHT_CONV4)
	// 	)iterator_conv4(
	// 	.clk				(clk),
	// 	.rstn				(rstn),
	// 	.go					(conv4_go),
	// 	.first_data			(first_data_conv4),
	// 	.last_data			(last_data_conv4),
	// 	.aa_bias			(aa_bias_conv4),
	// 	.aa_data			(aa_relu3_buf),
	// 	.aa_weight			(aa_weight_conv4),
	// 	.cena				(cena_relu3_buf),
	// 	.ready          	(conv4_ready)
	// ); 
	
	// reg		[15:0]	cena_relu3_buf_d;  // equal first_data_d
	// always @(*)	cena_relu3_buf_d[0] = cena_relu3_buf;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	cena_relu3_buf_d[15:1] <= 0;
	// 	else 		cena_relu3_buf_d[15:1] <= cena_relu3_buf_d;

	// reg		[15:0]	last_data_conv4_d;  //  equal to last_data_d
	// always @(*)	last_data_conv4_d[0] = last_data_conv4;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	last_data_conv4_d[15:1] <= 0;
	// 	else 		last_data_conv4_d[15:1] <= last_data_conv4_d;

	// reg		[15:0]	first_data_conv4_d;
	// always @(*)	first_data_conv4_d[0] = first_data_conv4;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	first_data_conv4_d[15:1] <= 0;
	// 	else 		first_data_conv4_d[15:1] <= first_data_conv4_d;

	// wire	[`WDP*`OUTPUT_NUM_CONV4 -1:0] qa_conv4;	
	// wire 								  qa_conv4_en;
	// conv #(
	// 	.INPUT_NUM		(`OUTPUT_NUM_CONV3),
	// 	.OUTPUT_NUM		(`OUTPUT_NUM_CONV4),
	// 	.WIGHT_SHIFT	(`WIGHT_SHIFT)
	// 	)conv4(
	// 	.clk			(clk),
	// 	.rstn			(rstn),
	// 	.en				(~cena_relu3_buf_d[1]),
	// 	.first_data		(first_data_conv4_d[1]),
	// 	.last_data		(last_data_conv4_d[1]),
	// 	.data_i			(qa_relu3_buf),
	// 	.bias			(qa_bias_conv4),
	// 	.weight			(qa_weight_conv4),
	// 	.q              (qa_conv4),
	// 	.q_en           (qa_conv4_en)
	// );
	
	// reg		[`W_AA:0]	aa_conv4_buf;
	// reg				cena_conv4_buf;
	// reg		[`W_AA:0]	ab_conv4_buf;
	// reg		[`OUTPUT_NUM_CONV4*16-1:0]	db_conv4_buf;  // a value 16bit, 256 channels is 4096 bits
	// reg				cenb_conv4_buf;
	// wire	[`OUTPUT_NUM_CONV4*16-1:0]	qa_conv4_buf;
	
	// rfdp256x1024 conv4_buf(
	// 	.CLKA   (clk),
	// 	.CENA   (cena_conv4_buf),
	// 	.AA     (aa_conv4_buf),
	// 	.QA     (qa_conv4_buf),
	// 	.CLKB   (clk),
	// 	.CENB   (cenb_conv4_buf),
	// 	.AB     (ab_conv4_buf),
	// 	.DB     (db_conv4_buf)
	// );
	
	// always @(`CLK_RST_EDGE)
	// 	if (`ZST)	db_conv4_buf <= 0;
	// 	else 		db_conv4_buf <= qa_conv4;

	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	cenb_conv4_buf <= 1;
	// 	else 		cenb_conv4_buf <= ~qa_conv4_en;

	// always @(`CLK_RST_EDGE)
	// 	if (`RST)					ab_conv4_buf <= 0;
	// 	else if (conv4_go)			ab_conv4_buf <= 0;
	// 	else if (!cenb_conv4_buf)	ab_conv4_buf <= ab_conv4_buf + 1;
	
	
	// reg		[15:0]	cena_conv4_buf_d;
	// always @(*)	cena_conv4_buf_d[0] = cena_conv4_buf;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	cena_conv4_buf_d[15:1] <= 0;
	// 	else 		cena_conv4_buf_d[15:1] <= cena_conv4_buf_d;

	// //  RELU4	
	// wire	[`WDP*`OUTPUT_NUM_CONV4 -1:0] qa_relu4;	
	// wire    qa_relu4_en;		
	// relu #(
	// 	.INPUT_NUM (`OUTPUT_NUM_CONV4)   // input plane_num
	// ) relu4(
	// 	.clk				(clk),
	// 	.rstn				(rstn),
	// 	.en					(qa_conv4_en),
	// 	.data_i				(qa_conv4),
		
	// 	.q_en				(qa_relu4_en),
	// 	.q					(qa_relu4)
	// );
	
	// reg		[`W_AA:0]	aa_relu4_buf;
	// reg				cena_relu4_buf;
	// reg		[`W_AA:0]	ab_relu4_buf;
	// reg		[`OUTPUT_NUM_CONV4*16-1:0]	db_relu4_buf;
	// reg				cenb_relu4_buf;
	// wire	[`OUTPUT_NUM_CONV4*16-1:0]	qa_relu4_buf;
	
	// rfdp256x1024 relu4_buf(
	// 	.CLKA   (clk),
	// 	.CENA   (cena_relu4_buf),
	// 	.AA     (aa_relu4_buf),
	// 	.QA     (qa_relu4_buf),
	// 	.CLKB   (clk),
	// 	.CENB   (cenb_relu4_buf),
	// 	.AB     (ab_relu4_buf),
	// 	.DB     (db_relu4_buf)
	// );
	
	
	// always @(`CLK_RST_EDGE)
	// 	if (`ZST)	db_relu4_buf <= 0;
	// 	else 		db_relu4_buf <= qa_relu4;
	
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	cenb_relu4_buf <= 1;
	// 	else 		cenb_relu4_buf <= ~qa_relu4_en;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)					ab_relu4_buf <= 0;
	// 	else if (conv4_go)			ab_relu4_buf <= 0;
	// 	else if (!cenb_relu4_buf)	ab_relu4_buf <= ab_relu4_buf + 1;


	// //=============================================================================
	// //  CONV5
	// //  16*16*256 -> 14*14*256, kernel_size = 3*3, stride = 1
	// //  16*16*64 -> 14*14*64, kernel_size = 3*3, stride = 1
	// wire		[`W_AA:0]										aa_weight_conv5;
	// wire		[`WDP*`OUTPUT_NUM_CONV4*`OUTPUT_NUM_CONV5 -1:0]	qa_weight_conv5;

	// wire		[`W_AA:0]							aa_bias_conv5;
	// wire		[`WDP_BIAS*`OUTPUT_NUM_CONV5 -1:0]	qa_bias_conv5;

	// weight_conv5_rom weight_conv5_rom(
	// 	.clk			(clk),
	// 	.rstn			(rstn),
	// 	.aa				(aa_weight_conv5),
	// 	.cena			(cena_relu1_buf),
	// 	.qa				(qa_weight_conv5)
	// 	);
		
	// bias_conv5_rom bias_conv5_rom(
	// 	.clk			(clk),
	// 	.rstn			(rstn),
	// 	.aa				(aa_bias_conv5),
	// 	.cena			(cena_relu1_buf),
	// 	.qa				(qa_bias_conv5)
	// 	);
	
	// wire	conv5_go = conv4_ready;
	// wire    first_data_conv5, last_data_conv5, conv5_ready;

	// iterator  #(
	// 	.OUTPUT_BATCH	(`OUTPUT_BATCH_CONV5),
	// 	.KERNEL_SIZEX	(`KERNEL_SIZEX_CONV5),
	// 	.KERNEL_SIZEY	(`KERNEL_SIZEY_CONV5),
	// 	.STEP			(1),
	// 	.INPUT_WIDTH	(`INPUT_WIDTH_CONV5),
	// 	.INPUT_HEIGHT	(`INPUT_HEIGHT_CONV5)
	// 	)iterator_conv5(
	// 	.clk				(clk),
	// 	.rstn				(rstn),
	// 	.go					(conv5_go),
	// 	.first_data			(first_data_conv5),
	// 	.last_data			(last_data_conv5),
	// 	.aa_bias			(aa_bias_conv5),
	// 	.aa_data			(aa_relu4_buf),
	// 	.aa_weight			(aa_weight_conv5),
	// 	.cena				(cena_relu4_buf),
	// 	.ready          	(conv5_ready)
	// ); 
	
	// reg		[15:0]	cena_relu4_buf_d;  // equal first_data_d
	// always @(*)	cena_relu4_buf_d[0] = cena_relu4_buf;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	cena_relu4_buf_d[15:1] <= 0;
	// 	else 		cena_relu4_buf_d[15:1] <= cena_relu4_buf_d;

	// reg		[15:0]	last_data_conv5_d;  //  equal to last_data_d
	// always @(*)	last_data_conv5_d[0] = last_data_conv5;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	last_data_conv5_d[15:1] <= 0;
	// 	else 		last_data_conv5_d[15:1] <= last_data_conv5_d;

	// reg		[15:0]	first_data_conv5_d;
	// always @(*)	first_data_conv5_d[0] = first_data_conv5;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	first_data_conv5_d[15:1] <= 0;
	// 	else 		first_data_conv5_d[15:1] <= first_data_conv5_d;

	// wire	[`WDP*`OUTPUT_NUM_CONV5 -1:0] qa_conv5;	
	// wire 								  qa_conv5_en;
	// conv #(
	// 	.INPUT_NUM		(`OUTPUT_NUM_CONV4),
	// 	.OUTPUT_NUM		(`OUTPUT_NUM_CONV5),
	// 	.WIGHT_SHIFT	(`WIGHT_SHIFT)
	// 	)conv5(
	// 	.clk			(clk),
	// 	.rstn			(rstn),
	// 	.en				(~cena_relu4_buf_d[1]),
	// 	.first_data		(first_data_conv5_d[1]),
	// 	.last_data		(last_data_conv5_d[1]),
	// 	.data_i			(qa_relu4_buf),
	// 	.bias			(qa_bias_conv5),
	// 	.weight			(qa_weight_conv5),
	// 	.q              (qa_conv5),
	// 	.q_en           (qa_conv5_en)
	// );
	
	// reg		[`W_AA:0]	aa_conv5_buf;
	// reg				cena_conv5_buf;
	// reg		[`W_AA:0]	ab_conv5_buf;
	// reg		[`OUTPUT_NUM_CONV5*16-1:0]	db_conv5_buf;  // a value 16bit, 256 channels is 4096 bits
	// reg				cenb_conv5_buf;
	// wire	[`OUTPUT_NUM_CONV5*16-1:0]	qa_conv5_buf;
	
	// rfdp256x1024 conv5_buf(
	// 	.CLKA   (clk),
	// 	.CENA   (cena_conv5_buf),
	// 	.AA     (aa_conv5_buf),
	// 	.QA     (qa_conv5_buf),
	// 	.CLKB   (clk),
	// 	.CENB   (cenb_conv5_buf),
	// 	.AB     (ab_conv5_buf),
	// 	.DB     (db_conv5_buf)
	// );
	
	// always @(`CLK_RST_EDGE)
	// 	if (`ZST)	db_conv5_buf <= 0;
	// 	else 		db_conv5_buf <= qa_conv5;

	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	cenb_conv5_buf <= 1;
	// 	else 		cenb_conv5_buf <= ~qa_conv5_en;

	// always @(`CLK_RST_EDGE)
	// 	if (`RST)					ab_conv5_buf <= 0;
	// 	else if (conv5_go)			ab_conv5_buf <= 0;
	// 	else if (!cenb_conv5_buf)	ab_conv5_buf <= ab_conv5_buf + 1;
	
	// //  POOLING5
	// // 14*14*256 -> 6*6*256
	// // kernel_size = 3*3, stride = 2
	// wire	pooling5_go = conv5_ready;
	// wire    first_data_pooling5, last_data_pooling5, pooling5_ready;

	// iterator #(
	// 	.OUTPUT_BATCH		(1),
	// 	.KERNEL_SIZEX		(2),
	// 	.KERNEL_SIZEY		(2),
	// 	.STEP				(2),
	// 	.INPUT_WIDTH		(`INPUT_WIDTH_CONV5 - `KERNEL_SIZE_CONV5 + 1),
	// 	.INPUT_HEIGHT		(`INPUT_HEIGHT_CONV5 - `KERNEL_SIZE_CONV5 + 1)
	// ) iterator_pooling5(
	// 	.clk				(clk),
	// 	.rstn				(rstn),
	// 	.go					(pooling5_go),
	// 	.aa_data			(aa_conv5_buf),
	// 	.cena				(cena_conv5_buf),
	// 	.first_data			(first_data_pooling5),
	// 	.last_data			(last_data_pooling5),
	// 	.ready				(pooling5_ready)
	// ); 
	
	// reg		[15:0]	cena_conv5_buf_d;
	// always @(*)	cena_conv5_buf_d[0] = cena_conv5_buf;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	cena_conv5_buf_d[15:1] <= 0;
	// 	else 		cena_conv5_buf_d[15:1] <= cena_conv5_buf_d;

	// reg		[15:0]	first_data_pooling5_d;
	// always @(*)	first_data_pooling5_d[0] = first_data_pooling5;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	first_data_pooling5_d[15:1] <= 0;
	// 	else 		first_data_pooling5_d[15:1] <= first_data_pooling5_d;
	
	// reg		[15:0]	last_data_pooling5_d;
	// always @(*)	last_data_pooling5_d[0] = last_data_pooling5;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	last_data_pooling5_d[15:1] <= 0;
	// 	else 		last_data_pooling5_d[15:1] <= last_data_pooling5_d;

	// wire	[`WDP*`OUTPUT_NUM_CONV5 -1:0] qa_pooling5;	
	// wire								  qa_pooling5_en;
	
	// max_pool #(
	// 	.INPUT_NUM (`OUTPUT_NUM_CONV5)   // input plane_num
	// ) max_pooling5(
	// 	.clk				(clk),
	// 	.rstn				(rstn),
	// 	.en					(!cena_conv5_buf_d[1]),
	// 	.first_data			(first_data_pooling5_d[1]),
	// 	.last_data			(last_data_pooling5_d[1]),
	// 	.data_i				(qa_conv5_buf),
	// 	.q_en				(qa_pooling5_en),
	// 	.q					(qa_pooling5)
	// );

	// //  RELU5	
	// wire	[`WDP*`OUTPUT_NUM_CONV5 -1:0] qa_relu5;	
	// wire    qa_relu5_en;		
	// relu #(
	// 	.INPUT_NUM (`OUTPUT_NUM_CONV5)   // input plane_num
	// ) relu5(
	// 	.clk				(clk),
	// 	.rstn				(rstn),
	// 	.en					(qa_pooling5_en),
	// 	.data_i				(qa_pooling5),
		
	// 	.q_en				(qa_relu5_en),
	// 	.q					(qa_relu5)
	// );
	
	// reg		[`W_AA:0]	aa_relu5_buf;
	// reg				cena_relu5_buf;
	// reg		[`W_AA:0]	ab_relu5_buf;
	// reg		[`OUTPUT_NUM_CONV5*16-1:0]	db_relu5_buf;
	// reg				cenb_relu5_buf;
	// wire	[`OUTPUT_NUM_CONV5*16-1:0]	qa_relu5_buf;
	
	// rfdp64x1024 relu5_buf(
	// 	.CLKA   (clk),
	// 	.CENA   (cena_relu5_buf),
	// 	.AA     (aa_relu5_buf),
	// 	.QA     (qa_relu5_buf),
	// 	.CLKB   (clk),
	// 	.CENB   (cenb_relu5_buf),
	// 	.AB     (ab_relu5_buf),
	// 	.DB     (db_relu5_buf)
	// );
	
	
	// always @(`CLK_RST_EDGE)
	// 	if (`ZST)	db_relu5_buf <= 0;
	// 	else 		db_relu5_buf <= qa_relu5;
	
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	cenb_relu5_buf <= 1;
	// 	else 		cenb_relu5_buf <= ~qa_relu5_en;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)					ab_relu5_buf <= 0;
	// 	else if (pooling5_go)		ab_relu5_buf <= 0;
	// 	else if (!cenb_relu5_buf)	ab_relu5_buf <= ab_relu5_buf + 1;
		
//    reg 			[3:0]	digit;
    always @(`CLK_RST_EDGE)
        if (`RST)				digit <= 0;
        else if (conv1_go)		digit <= 0;
        else if (qa_conv1_en)	
        if (pooling1_ready)			digit <= qa_relu1_buf[3:0];	
	assign ready = 	pooling1_ready;

endmodule

	// //======================= FC ================================	
	
	// wire		[`WDP*`OUTPUT_NUM_CONV2*`OUTPUT_NUM_FC1 -1:0]	qa_weight_fc1_rom;
	// //	wire		[11:0]											aa_weight_fc1;
	// wire		[$clog2(`KERNEL_SIZE_FC1*`KERNEL_SIZE_FC1*`OUTPUT_BATCH_FC1)-1:0]	aa_weight_fc1;
	// wire		[`W_BIAS_AA:0]								aa_bias_fc1;
	// wire		[`WDP_BIAS*`OUTPUT_NUM_FC1 -1:0]				qa_bias_fc1;
	
	// weight_fc1_rom weight_fc1_rom(
	// 	.clk			(clk),
	// 	.rstn			(rstn),
	// 	.aa				(aa_weight_fc1),
	// 	.cena			(cena_relu2_buf),
	// 	.qa				(qa_weight_fc1_rom)
	// 	);
	// bias_fc1_rom bias_fc1_rom(
	// 	.clk			(clk),
	// 	.rstn			(rstn),
	// 	.aa				(aa_bias_fc1),
	// 	.cena			(cena_relu2_buf),
	// 	.qa				(qa_bias_fc1)
	// 	);
		
	// wire	fc1_go = pooling2_ready;
	// iterator  #(
	// 	.OUTPUT_BATCH	(`OUTPUT_BATCH_FC1),
	// 	.KERNEL_SIZEX	(`KERNEL_SIZEX_FC1),
	// 	.KERNEL_SIZEY	(`KERNEL_SIZEY_FC1),
	// 	.STEP			(1),
	// 	.INPUT_WIDTH	(`INPUT_WIDTH_FC1),
	// 	.INPUT_HEIGHT	(`INPUT_HEIGHT_FC1)
	// 	)iterator_FC1(
	// 	.clk				(clk),
	// 	.rstn				(rstn),
	// 	.go					(fc1_go),
	// 	.first_data			(first_data_fc1),
	// 	.last_data			(last_data_fc1),
	// 	.aa_bias			(aa_bias_fc1),
	// 	.aa_data			(aa_relu2_buf),
	// 	.aa_weight			(aa_weight_fc1),
	// 	.cena				(cena_relu2_buf),
	// 	.ready          	(fc1_ready)
	// ); 
	
	// reg		[15:0]	cena_relu2_buf_d;
	// always @(*)	cena_relu2_buf_d[0] = cena_relu2_buf;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	cena_relu2_buf_d[15:1] <= 0;
	// 	else 		cena_relu2_buf_d[15:1] <= cena_relu2_buf_d;
	
	// reg		[15:0]	first_data_fc1_d;
	// always @(*)	first_data_fc1_d[0] = first_data_fc1;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	first_data_fc1_d[15:1] <= 0;
	// 	else 		first_data_fc1_d[15:1] <= first_data_fc1_d;
		
	// reg		[15:0]	last_data_fc1_d;
	// always @(*)	last_data_fc1_d[0] = last_data_fc1;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	last_data_fc1_d[15:1] <= 0;
	// 	else 		last_data_fc1_d[15:1] <= last_data_fc1_d;
	
	// wire	[`WDP*`OUTPUT_NUM_FC1 -1:0] qa_fc1;
	// wire								qa_fc1_en;		
	// conv #(
	// 	.INPUT_NUM		(`OUTPUT_NUM_CONV2),
	// 	.OUTPUT_NUM		(`OUTPUT_NUM_FC1),
	// 	.WIGHT_SHIFT	(`WIGHT_SHIFT)
	// 	)conv_fc1(
	// 	.clk			(clk),
	// 	.rstn			(rstn),
	// 	.en				(~cena_relu2_buf_d[1]),
	// 	.first_data		(first_data_fc1_d[1]),
	// 	.last_data		(last_data_fc1_d[1]),
	// 	.data_i			(qa_relu2_buf),
	// 	.bias			(qa_bias_fc1),
	// 	.weight			(qa_weight_fc1_rom),
	// 	.q              (qa_fc1),
	// 	.q_en           (qa_fc1_en)
	// 	);
		
	// wire	[`WDP*`OUTPUT_NUM_FC1 -1:0] qa_relu_fc1;	
	// wire								qa_relu_fc1_en;	
	// relu #(
	// 	.INPUT_NUM (`OUTPUT_NUM_FC1)   // input plane_num
	// ) relu_fc1(
	// 	.clk				(clk),
	// 	.rstn				(rstn),
	// 	.en					(qa_fc1_en),
	// 	.data_i				(qa_fc1),
		
	// 	.q_en				(qa_relu_fc1_en),
	// 	.q					(qa_relu_fc1)
	// );	
	
    // // 5*5*16 -> 1*1*120 -> 12*10*1
    // //kernel_size = 5*5
	// reg		[6:0]	aa_relu_fc1_buf;
	// reg				cena_relu_fc1_buf;
	// reg		[6:0]	ab_relu_fc1_buf;
	// reg		[15:0]	db_relu_fc1_buf;
	// reg				cenb_relu_fc1_buf;
	// wire	[15:0]	qa_relu_fc1_buf;
	
	// rfdp128x16 relu_fc1_buf(
	// 	.CLKA   (clk),
	// 	.CENA   (cena_relu_fc1_buf),
	// 	.AA     (aa_relu_fc1_buf),
	// 	.QA     (qa_relu_fc1_buf),
	// 	.CLKB   (clk),
	// 	.CENB   (cenb_relu_fc1_buf),
	// 	.AB     (ab_relu_fc1_buf),
	// 	.DB     (db_relu_fc1_buf)
	// 	);

	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	db_relu_fc1_buf <= 0;
	// 	else 		db_relu_fc1_buf <= qa_relu_fc1;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	cenb_relu_fc1_buf <= 1;
	// 	else 		cenb_relu_fc1_buf <= ~qa_relu_fc1_en;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)						ab_relu_fc1_buf <= 0;
	// 	else if (fc1_go)				ab_relu_fc1_buf <= 0;
	// 	else if (!cenb_relu_fc1_buf)	ab_relu_fc1_buf <= ab_relu_fc1_buf + 1;
		
	// //=================FC2============================================================
	
	// wire		[`WDP*`OUTPUT_NUM_FC1*`OUTPUT_NUM_FC2 -1:0]		qa_weight_fc2_rom;
	// //	wire		[11:0]											aa_weight_fc2;
	// wire		[$clog2(`KERNEL_SIZEX_FC2*`KERNEL_SIZEY_FC2*`OUTPUT_BATCH_FC2)-1:0]	aa_weight_fc2;
	// wire		[`W_BIAS_AA:0]								aa_bias_fc2;
	// wire		[`WDP_BIAS*`OUTPUT_NUM_FC2 -1:0]				qa_bias_fc2;
	
	// weight_fc2_rom weight_fc2_rom(
	// 	.clk			(clk),
	// 	.rstn			(rstn),
	// 	.aa				(aa_weight_fc2),
	// 	.cena			(cena_relu_fc1_buf),
	// 	.qa				(qa_weight_fc2_rom)
	// );
	// bias_fc2_rom bias_fc2_rom(
	// 	.clk			(clk),
	// 	.rstn			(rstn),
	// 	.aa				(aa_bias_fc2),
	// 	.cena			(cena_relu_fc1_buf),
	// 	.qa				(qa_bias_fc2)
	// );
	
	// wire	fc2_go = fc1_ready;
	// iterator  #(
	// 	.OUTPUT_BATCH	(`OUTPUT_BATCH_FC2),
	// 	.KERNEL_SIZEX	(`KERNEL_SIZEX_FC2),
	// 	.KERNEL_SIZEY	(`KERNEL_SIZEY_FC2),
	// 	.STEP			(1),
	// 	.INPUT_WIDTH	(`INPUT_WIDTH_FC2),
	// 	.INPUT_HEIGHT	(`INPUT_HEIGHT_FC2)
	// 	)iterator_fc2(
	// 	.clk				(clk),
	// 	.rstn				(rstn),
	// 	.go					(fc2_go),
	// 	.first_data			(first_data_fc2),
	// 	.last_data			(last_data_fc2),
	// 	.aa_bias			(aa_bias_fc2),
	// 	.aa_data			(aa_relu_fc1_buf),
	// 	.aa_weight			(aa_weight_fc2),
	// 	.cena				(cena_relu_fc1_buf),
	// 	.ready          	(fc2_ready)
	// ); 
	
	// reg		[15:0]	cena_relu_fc1_buf_d;
	// always @(*)	cena_relu_fc1_buf_d[0] = cena_relu_fc1_buf;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	cena_relu_fc1_buf_d[15:1] <= 0;
	// 	else 		cena_relu_fc1_buf_d[15:1] <= cena_relu_fc1_buf_d;
	
	// reg		[15:0]	first_data_fc2_d;
	// always @(*)	first_data_fc2_d[0] = first_data_fc2;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	first_data_fc2_d[15:1] <= 0;
	// 	else 		first_data_fc2_d[15:1] <= first_data_fc2_d;
		
	// reg		[15:0]	last_data_fc2_d;
	// always @(*)	last_data_fc2_d[0] = last_data_fc2;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	last_data_fc2_d[15:1] <= 0;
	// 	else 		last_data_fc2_d[15:1] <= last_data_fc2_d;
	
	// wire	[`WDP*`OUTPUT_NUM_FC2 -1:0] qa_fc2;	
	// wire								qa_fc2_en;		
	// conv #(
	// 	.INPUT_NUM		(`OUTPUT_NUM_FC1),
	// 	.OUTPUT_NUM		(`OUTPUT_NUM_FC2),
	// 	.WIGHT_SHIFT	(`WIGHT_SHIFT)
	// 	)conv_fc2(
	// 	.clk			(clk),
	// 	.rstn			(rstn),
	// 	.en				(~cena_relu_fc1_buf_d[1]),
	// 	.first_data		(first_data_fc2_d[1]),
	// 	.last_data		(last_data_fc2_d[1]),
	// 	.data_i			(qa_relu_fc1_buf),
	// 	.bias			(qa_bias_fc2),
	// 	.weight			(qa_weight_fc2_rom),
	// 	.q              (qa_fc2),
	// 	.q_en           (qa_fc2_en)
	// 	);
		
	// wire	[`WDP*`OUTPUT_NUM_FC2 -1:0] qa_relu_fc2;
	// wire								qa_relu_fc2_en;
	// relu #(
	// 	.INPUT_NUM (`OUTPUT_NUM_FC2)   // input plane_num
	// ) relu_fc2(
	// 	.clk				(clk),
	// 	.rstn				(rstn),
	// 	.en					(qa_fc2_en),
	// 	.data_i				(qa_fc2),
		
	// 	.q_en				(qa_relu_fc2_en),
	// 	.q					(qa_relu_fc2)
	// );	
	
    // // 12*10*1 -> 1*1*84 -> 12*7*1
    // // kernel_size = 12*7
	// reg		[6:0]	aa_relu_fc2_buf;
	// reg				cena_relu_fc2_buf;
	// reg		[6:0]	ab_relu_fc2_buf;
	// reg		[15:0]	db_relu_fc2_buf;
	// reg				cenb_relu_fc2_buf;
	// wire	[15:0]	qa_relu_fc2_buf;
	
	// rfdp128x16 relu_fc2_buf(
	// 	.CLKA   (clk),
	// 	.CENA   (cena_relu_fc2_buf),
	// 	.AA     (aa_relu_fc2_buf),
	// 	.QA     (qa_relu_fc2_buf),
	// 	.CLKB   (clk),
	// 	.CENB   (cenb_relu_fc2_buf),
	// 	.AB     (ab_relu_fc2_buf),
	// 	.DB     (db_relu_fc2_buf)
	// 	);
	
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	db_relu_fc2_buf <= 0;
	// 	else 		db_relu_fc2_buf <= qa_relu_fc2;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	cenb_relu_fc2_buf <= 1;
	// 	else 		cenb_relu_fc2_buf <= ~qa_relu_fc2_en;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)						ab_relu_fc2_buf <= 0;
	// 	else if (fc2_go)				ab_relu_fc2_buf <= 0;
	// 	else if (!cenb_relu_fc2_buf)	ab_relu_fc2_buf <= ab_relu_fc2_buf + 1;
		
	// //=================FC3============================================================

	// wire		[`WDP*`OUTPUT_NUM_FC2*`OUTPUT_NUM_FC3 -1:0]		qa_weight_fc3_rom;
	// //	wire		[11:0]											aa_weight_fc3;
	// wire		[$clog2(`KERNEL_SIZEX_FC3*`KERNEL_SIZEY_FC3*`OUTPUT_BATCH_FC3)-1:0]	aa_weight_fc3;
	// wire		[`W_OUPTUT_BATCH:0]								aa_bias_fc3;
	// wire		[`WDP_BIAS*`OUTPUT_NUM_FC3 -1:0]				qa_bias_fc3;
	
	// weight_fc3_rom weight_fc3_rom(
	// 	.clk			(clk),
	// 	.rstn			(rstn),
	// 	.aa				(aa_weight_fc3),
	// 	.cena			(cena_relu_fc2_buf),
	// 	.qa				(qa_weight_fc3_rom)
	// );
	// bias_fc3_rom bias_fc3_rom(
	// 	.clk			(clk),
	// 	.rstn			(rstn),
	// 	.aa				(aa_bias_fc3),
	// 	.cena			(cena_relu_fc2_buf),
	// 	.qa				(qa_bias_fc3)
	// );
	
		
	// wire	fc3_go = fc2_ready;
	// iterator  #(
	// 	.OUTPUT_BATCH	(`OUTPUT_BATCH_FC3),
	// 	.KERNEL_SIZEX	(`KERNEL_SIZEX_FC3),
	// 	.KERNEL_SIZEY	(`KERNEL_SIZEY_FC3),
	// 	.STEP			(1),
	// 	.INPUT_WIDTH	(`INPUT_WIDTH_FC3),
	// 	.INPUT_HEIGHT	(`INPUT_HEIGHT_FC3)
	// 	)iterator_fc3(
	// 	.clk				(clk),
	// 	.rstn				(rstn),
	// 	.go					(fc3_go),
	// 	.first_data			(first_data_fc3),
	// 	.last_data			(last_data_fc3),
	// 	.aa_bias			(aa_bias_fc3),
	// 	.aa_data			(aa_relu_fc2_buf),
	// 	.aa_weight			(aa_weight_fc3),
	// 	.cena				(cena_relu_fc2_buf),
	// 	.ready          	(fc3_ready)
	// ); 
	
	// reg		[15:0]	cena_relu_fc2_buf_d;
	// always @(*)	cena_relu_fc2_buf_d[0] = cena_relu_fc2_buf;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	cena_relu_fc2_buf_d[15:1] <= 0;
	// 	else 		cena_relu_fc2_buf_d[15:1] <= cena_relu_fc2_buf_d;
	
	// reg		[15:0]	first_data_fc3_d;
	// always @(*)	first_data_fc3_d[0] = first_data_fc3;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	first_data_fc3_d[15:1] <= 0;
	// 	else 		first_data_fc3_d[15:1] <= first_data_fc3_d;
		
	// reg		[15:0]	last_data_fc3_d;
	// always @(*)	last_data_fc3_d[0] = last_data_fc3;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	last_data_fc3_d[15:1] <= 0;
	// 	else 		last_data_fc3_d[15:1] <= last_data_fc3_d;
	
	// wire	[`WDP*`OUTPUT_NUM_FC3 -1:0] qa_fc3;
	// wire								qa_fc3_en;		
	// conv #(
	// 	.INPUT_NUM		(`OUTPUT_NUM_FC2),
	// 	.OUTPUT_NUM		(`OUTPUT_NUM_FC3),
	// 	.WIGHT_SHIFT	(`WIGHT_SHIFT)
	// 	)conv_fc3(
	// 	.clk			(clk),
	// 	.rstn			(rstn),
	// 	.en				(~cena_relu_fc2_buf_d[1]),
	// 	.first_data		(first_data_fc3_d[1]),
	// 	.last_data		(last_data_fc3_d[1]),
	// 	.data_i			(qa_relu_fc2_buf),
	// 	.bias			(qa_bias_fc3),
	// 	.weight			(qa_weight_fc3_rom),
	// 	.q              (qa_fc3),
	// 	.q_en           (qa_fc3_en)
	// 	);

	// //  get max value
	// reg	signed	[`WD:0]	qa_fc_fc3_max;
	// reg			[3:0]	qa_fc3_index;
	// //reg			[3:0]	digit;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)				qa_fc3_index <= 0;
	// 	else if (fc3_go)		qa_fc3_index <= 0;
	// 	else if (qa_fc3_en)		qa_fc3_index <= qa_fc3_index + 1;
	
	// wire	gt_f = $signed(qa_fc3) > $signed(qa_fc_fc3_max);
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)				qa_fc_fc3_max <= 0;
	// 	else if (fc3_go)		qa_fc_fc3_max <= 1 << (`WD);
	// 	else if (qa_fc3_en)		
	// 		if (gt_f)			qa_fc_fc3_max <= qa_fc3;			
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)				digit <= 0;
	// 	else if (fc3_go)		digit <= 0;
	// 	else if (qa_fc3_en)	
	// 		if (gt_f)			digit <= qa_fc3_index;	
	
	// reg		[15:0]	fc3_ready_d;
	// always @(*)	fc3_ready_d[0] = fc3_ready;
	// always @(`CLK_RST_EDGE)
	// 	if (`RST)	fc3_ready_d[15:1] <= 0;
	// 	else 		fc3_ready_d[15:1] <= fc3_ready_d;
	
