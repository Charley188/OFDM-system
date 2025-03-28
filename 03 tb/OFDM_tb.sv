`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:19:08 12/19/2012 
// Design Name: 
// Module Name:    OFDM_TX_tb 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module OFDM_tb(
    );

parameter    NSAM  = 384;
reg [5:0] 	 datin [NSAM - 1:0];
reg [0:0] 	 dat_vld [NSAM - 1:0];
reg [0:0] 	 dat_last [NSAM - 1:0];
reg [0:0] 	 symb_last [NSAM - 1:0];
integer  Len, NLOP, para_fin;
integer flag1,flag2;

reg 	rst, clk;
integer 	ii, lop_cnt;
reg m_axis_tready;

initial 	begin
		rst 		= 1'b1;
		clk 		= 1'b0;	
		m_axis_tready = 1'd0;		
		para_fin = $fopen("../../../../../04 matlab/OFDM_TX_bit_symbols_Len.txt","r");
		flag1 = $fscanf(para_fin, "%d ", Len);
		flag2 = $fscanf(para_fin, "%d ", NLOP);
		$fclose(para_fin);
		#60;
		$readmemh("../../../../../04 matlab/RTL_OFDM_TX_bit_symbols.txt", datin);
		$readmemh("../../../../../04 matlab/RTL_OFDM_TX_bit_symbols_vld.txt", dat_vld);
		$readmemh("../../../../../04 matlab/RTL_OFDM_TX_bit_symbols_last.txt", symb_last);
		$readmemh("../../../../../04 matlab/RTL_OFDM_TX_bit_slot_last.txt", dat_last);
	
	#250;
	rst		= 1'b0;

	#400
	m_axis_tready = 1'd1;
end

reg  		s_axis_tvalid;
reg  [5:0]  s_axis_tdata;
reg  		s_axis_tlast;
wire  		s_axis_tready;
reg         s_bit_symb_last;

wire 		mod_m_axis_tvalid;
wire [31:0] mod_m_axis_tdata;
wire 		mod_m_axis_tlast;
wire		mod_m_axis_tready;
wire		m_bit_symb_last; 

wire 		insert_m_axis_tvalid;
wire [31:0] insert_m_axis_tdata;
wire 		insert_m_axis_tlast;
wire		insert_m_axis_tready;
wire		insert_m_axis_symb_tlast;   

// assign m_axis_tready = 1'd1;

/***********************************mod qpsk************************************/

QPSK_Mod_AXI_Stream inst_QPSK_Mod_AXI_Stream(
    .clk(clk),                     // 
    .rst(rst),                     // 

    .s_axis_tvalid(s_axis_tvalid), // 
    .s_axis_tdata(s_axis_tdata),   // 
    .s_axis_tlast(s_axis_tlast),   // 
    .s_axis_tready(s_axis_tready), // 
    .s_bit_symb_last(s_bit_symb_last),

    .m_axis_tvalid(mod_m_axis_tvalid), // 
    .m_axis_tdata(mod_m_axis_tdata),   // 
    .m_axis_tlast(mod_m_axis_tlast),   // 
    .m_axis_tready(mod_m_axis_tready), // 
    .m_bit_symb_last(m_bit_symb_last)
);

/*********************************pilot insert***********************************/
reg [7:0] s_weice_state;
always @(posedge clk) begin
   if(rst)begin
        s_weice_state = #1 8'd0;
   end
   else if(mod_m_axis_tlast&&mod_m_axis_tvalid&&mod_m_axis_tready)
   		s_weice_state = #1 8'd0;
   else if(mod_m_axis_tvalid&&mod_m_axis_tready) begin
        s_weice_state = #1 s_weice_state + 1;
   end
end

Pilots_Insert_AXI_Stream_3 #(
    // .PILOT_SEQ_FILE("../../../../../../src_axis/pilot_seq.mem"),
    .SYMBOL_POS(16'h7FFF),
    .SYMBOL_NEG(16'h8001)
)inst_Pilots_Insert_AXI_Stream(
    .clk(clk),
    .rst(rst),

    // AXI-Stream 输入接口
    .s_axis_tvalid(mod_m_axis_tvalid),
    .s_axis_tready(mod_m_axis_tready),
    .s_axis_tdata(mod_m_axis_tdata),
    .s_axis_tlast(mod_m_axis_tlast),   // 输入帧结束标??
    .s_mod_symb_last(m_bit_symb_last),

    // AXI-Stream 输出接口
    .m_axis_tvalid(insert_m_axis_tvalid),
    // .m_axis_tready(m_axis_tready),
	.m_axis_tready(insert_m_axis_tready),
    .m_axis_tdata(insert_m_axis_tdata),
    .m_axis_tlast(insert_m_axis_tlast),   // 输出帧结束标??
    .m_axis_symb_tlast(insert_m_axis_symb_tlast)
);

/***********************************IFFT**************************************/

wire 		fft_m_tvalid;
wire [31:0] fft_m_tdata;
wire 		fft_m_tlast;
wire		fft_m_tready;  

IFFT inst_IFFT(
	.aclk(clk), 											// input aclk
	//.aclken(aclken), 									// input aclken
	.aresetn(~rst), 										// input aresetn
	.s_axis_config_tdata(16'h3610), 					// input [23 : 0] s_axis_config_tdata: [14:9] scale; [8]fwd_inv; [5:0]: cp_len
														// scale: shift right 6 bits : 0, 1, 2, 3, inv = 0 
														// config_tdata = 0000 0011 0110 0001 0000
	.s_axis_config_tvalid(1'b1), 						// input s_axis_config_tvalid
	.s_axis_config_tready(), 							// ouput s_axis_config_tready
	.s_axis_data_tdata(insert_m_axis_tdata), 			// input [31 : 0] s_axis_data_tdata
	.s_axis_data_tvalid(insert_m_axis_tvalid),			// input s_axis_data_tvalid
	.s_axis_data_tready(insert_m_axis_tready), 			// ouput s_axis_data_tready
	.s_axis_data_tlast(), 								// input s_axis_data_tlast
	// .s_axis_data_tlast(insert_m_axis_tlast), 					// input s_axis_data_tlast
	.m_axis_data_tdata(fft_m_tdata), 					// ouput [31 : 0] m_axis_data_tdata
	.m_axis_data_tvalid(fft_m_tvalid), 					// ouput m_axis_data_tvalid
	.m_axis_data_tready(m_axis_tready), 					// input m_axis_data_tready
	.m_axis_data_tlast(fft_m_tlast),					// ouput m_axis_data_tlast
	.event_frame_started(event_frame_started), 	// ouput event_frame_started
	.event_tlast_unexpected(), 						// ouput event_tlast_unexpected
	.event_tlast_missing(), 							// ouput event_tlast_missing
	.event_status_channel_halt(event_status_channel_halt), // ouput event_status_channel_halt
	.event_data_in_channel_halt(event_data_in_channel_halt), // ouput event_data_in_channel_halt
	.event_data_out_channel_halt(event_data_out_channel_halt)
	); // ouput event_data_out_channel_halt

always #10 	clk = ~clk;	

initial 	begin	
	lop_cnt  = 0;
	ii = 0;
	@(negedge rst);
	forever begin
		@(posedge clk);
		if (~(lop_cnt == NLOP)) begin
			@(s_axis_tlast && s_axis_tready);
			// #20;
			// ii <= 0;
			#600;
			lop_cnt = lop_cnt +1;
		end
	end
end		
// always @(posedge clk) begin	
// 	if(rst) 	begin
// 		ii <= 0;	
// 		s_axis_tdata = 6'd0;
// 		s_axis_tvalid = 1'd0;
// 		s_axis_tlast = 1'd0;
// 	end
// 	else if(ii == 125)
// 		ii=0;
// 	else if(s_axis_tready && (ii<=95))begin
// 		s_axis_tvalid = dat_vld[ii + lop_cnt*Len];
// 		s_axis_tdata = datin[ii + lop_cnt*Len];
// 		s_axis_tlast = dat_last[ii + lop_cnt*Len];
// 		ii=ii + 1;
// 	end
// 	else begin
// 		s_axis_tvalid = 0;
// 		s_axis_tdata = 0;
// 		s_axis_tlast = 0;
// 		ii=ii + 1;
// 	end
// end

always @(posedge clk) begin	
	if(rst) 	begin
		ii <= 0;	
		s_axis_tdata = 6'd0;
		s_axis_tvalid = 1'd0;
		s_axis_tlast = 1'd0;
		s_bit_symb_last = 1'd0;
	end
	else if(~s_axis_tready && (ii<=95)) begin
		s_axis_tvalid = 0;
		s_axis_tdata = 0;
		s_axis_tlast = 0;
		s_bit_symb_last = 1'd0;
		ii = ii;
	end
	else if(s_axis_tready && (ii<=95) && (lop_cnt<4)) begin
		s_axis_tvalid = dat_vld[ii + lop_cnt*Len];
		s_axis_tdata = datin[ii + lop_cnt*Len];
		s_axis_tlast = dat_last[ii + lop_cnt*Len];
		s_bit_symb_last = symb_last[ii + lop_cnt*Len];
		ii = ii + 1;
	end
	else if(ii == 600)begin
		ii = 0;
	end
	else begin
		s_axis_tvalid = 0;
		s_axis_tdata = 0;
		s_axis_tlast = 0;
		s_bit_symb_last = 1'd0;
		ii = ii + 1;
	end
end

//========================probe============================//
wire [31:0] 	QPSK_Mod_data_out 		= mod_m_axis_tdata;	
wire			QPSK_Mod_tvalid_out		= mod_m_axis_tvalid;
wire			QPSK_Mod_tlast_out		= mod_m_axis_tlast;
wire 			QPSK_Mod_tready_out		= mod_m_axis_tready;

wire [31:0] 	IFFT_Mod_data_out 		= fft_m_tdata;	
wire			IFFT_Mod_tvalid_out		= fft_m_tvalid;
wire			IFFT_Mod_tlast_out		= fft_m_tlast;
wire 			IFFT_Mod_tready_out		= m_axis_tready;

wire [31:0] 	pilot_Mod_data_out 		= insert_m_axis_tdata;	
wire			pilot_Mod_tvalid_out	= insert_m_axis_tvalid;
wire			pilot_Mod_tlast_out		= insert_m_axis_tlast;
wire 			pilot_Mod_tready_out	= insert_m_axis_tready;

integer datout_cnt_0,datout_cnt_1,datout_cnt_2;
integer qpsk_Mod_Re_fo, qpsk_Mod_Im_fo,qpsk_cnt_fo;
integer pilot_Mod_Re_fo, pilot_Mod_Im_fo,pilot_cnt_fo;
integer IFFT_Mod_Re_fo, IFFT_Mod_Im_fo,IFFT_cnt_fo;
initial begin
	datout_cnt_0 = 0;
	datout_cnt_1 = 0;
	datout_cnt_2 = 0;	
	qpsk_Mod_Re_fo = $fopen("../../../../../04 matlab/RTL_OFDM_TX_QPSK_Mod_Re.txt");		
	qpsk_Mod_Im_fo = $fopen("../../../../../04 matlab/RTL_OFDM_TX_QPSK_Mod_Im.txt");
	qpsk_cnt_fo = $fopen("../../../../../04 matlab/RTL_OFDM_TX_QPSK_Mod_cnt.txt");

	pilot_Mod_Re_fo = $fopen("../../../../../04 matlab/RTL_OFDM_TX_pilot_Mod_Re.txt");		
	pilot_Mod_Im_fo = $fopen("../../../../../04 matlab/RTL_OFDM_TX_pilot_Mod_Im.txt");
	pilot_cnt_fo = $fopen("../../../../../04 matlab/RTL_OFDM_TX_pilot_Mod_cnt.txt");

	IFFT_Mod_Re_fo = $fopen("../../../../../04 matlab/RTL_OFDM_TX_IFFT_Mod_Re.txt");		
	IFFT_Mod_Im_fo = $fopen("../../../../../04 matlab/RTL_OFDM_TX_IFFT_Mod_Im.txt");
	IFFT_cnt_fo = $fopen("../../../../../04 matlab/RTL_OFDM_TX_IFFT_Mod_cnt.txt");
	forever begin
		@(posedge clk);
		if (QPSK_Mod_tvalid_out && QPSK_Mod_tready_out) begin
			$fwrite(qpsk_Mod_Re_fo,"%d\n",$signed(QPSK_Mod_data_out[15:0]));
			$fwrite(qpsk_Mod_Im_fo,"%d\n",$signed(QPSK_Mod_data_out[31:16]));
			$fwrite(qpsk_cnt_fo,"%d\n",datout_cnt_0);
			datout_cnt_0 = datout_cnt_0 + 1;			
			end
		if (pilot_Mod_tvalid_out && pilot_Mod_tready_out) begin
			$fwrite(pilot_Mod_Re_fo,"%d\n",$signed(pilot_Mod_data_out[15:0]));
			$fwrite(pilot_Mod_Im_fo,"%d\n",$signed(pilot_Mod_data_out[31:16]));
			$fwrite(pilot_cnt_fo,"%d\n",datout_cnt_1);
			datout_cnt_1 = datout_cnt_1 + 1;			
			end
		if (IFFT_Mod_tvalid_out && IFFT_Mod_tready_out) begin
			$fwrite(IFFT_Mod_Re_fo,"%d\n",$signed(IFFT_Mod_data_out[15:0]));
			$fwrite(IFFT_Mod_Im_fo,"%d\n",$signed(IFFT_Mod_data_out[31:16]));
			$fwrite(IFFT_cnt_fo,"%d\n",datout_cnt_2);
			datout_cnt_2 = datout_cnt_2 + 1;			
			end
	end
end

//=========================stop=============================//
initial begin
    wait(lop_cnt == NLOP);      // 
    #20000;                      //
	$fclose(pilot_Mod_Re_fo);
	$fclose(pilot_Mod_Im_fo); 
	$fclose(pilot_cnt_fo);
	$fclose(IFFT_Mod_Re_fo);
	$fclose(IFFT_Mod_Im_fo);
	$fclose(IFFT_cnt_fo);
	$fclose(qpsk_Mod_Re_fo);
	$fclose(qpsk_Mod_Im_fo);
	$fclose(qpsk_cnt_fo);
    $stop;
end

endmodule
