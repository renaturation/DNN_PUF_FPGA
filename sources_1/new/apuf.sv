`timescale 1ns / 1ps

`include "global.vh"

module arbiterpuf (
	input					clk,
	input					rstn,
    input [`CHALLENGE_NUM-1:0]C,
    output [`RESPONSE_NUM-1:0]R,
    output ready
    );

    parameter   CLK_FRE = 50;//Mhz

    reg[31:0]   wait_cnt;
    reg signal;
    reg ready1;
    
    always @(`CLK_RST_EDGE)
    if (`RST) begin
        signal <= 0;
        wait_cnt <= 0;
        ready1 <= 0;
    end
    else begin
        wait_cnt <= wait_cnt + 1'b1;
        if (wait_cnt == CLK_FRE) // 1us
            signal <= 1;
        else if (wait_cnt == CLK_FRE*10) // 2us
            signal <= 0;
            ready1 <= 1;
    end	
    	
    genvar i;
	generate 
		for (i=0; i<`RESPONSE_NUM; i=i+1) begin : apuf
			arbiter A(signal, C, R[i]);
		end
	endgenerate
	
    assign ready = ready1;
    
endmodule


(* keep_hierarchy = "yes" *) module arbiter (
    input S,
    input [`CHALLENGE_NUM-1:0]C,
    output O
    );
        
    wire [`CHALLENGE_NUM:0]WA;
    wire [`CHALLENGE_NUM:0]WB;
    assign WA[0] = S;
    assign WB[0] = S;
    
    genvar i;
	generate 
		for (i=0; i<`CHALLENGE_NUM; i=i+1) begin : arbel
			arbel AA(WA[i], WB[i], C[i], WA[i+1], WB[i+1]);
		end
	endgenerate
	
    dflipflop DFF(WA[`CHALLENGE_NUM], WB[`CHALLENGE_NUM], O);
     
endmodule


(* keep_hierarchy = "yes" *) module arbel(
    input X,
    input Y,
    input C,
    output W,
    output Z
    );
        
    //wire W1,W2,Z1,Z2;
    wire W1,Z1;
    mux2x1 M1(X, Y, C, W1);
    mux2x1 M2(Y, X, C, Z1);
    
//    not N1(W2,W1);
//    not N2(W,W2);
//    not N3(Z2,Z1);
//    not N4(Z,Z2);
    notchain N1(W1,W);
    notchain N2(Z1,Z);
endmodule


module dflipflop(
    input D,
    input Clk,
    output reg R
    );
    
    always @ (posedge Clk)
        if (Clk)
        begin
            R <= D;
        end
    
endmodule


(* keep_hierarchy = "yes" *)module mux2x1(
    input A,
    input B,
    input S,
    output D
    );
    
    wire SN, SA, SB;
    
    not N1(SN, S);
    and A1(SA, A, S);
    and A2(SB, B, SN);
    or  O1(D, SA, SB);
endmodule

// can be unused
(* keep_hierarchy = "yes" *)module notchain(
    input A,
    output A1
    );
    (*dont_touch = "true"*)wire NA;
    assign NA = ~A;
    assign A1 = ~NA;
endmodule
