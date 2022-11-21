`timescale 1ns / 1ps

module cnv_tb;
parameter W_SIZE  = 12;					// Max 4K QHD (3840x1920).
parameter W_FRAME_SIZE  = 2 * W_SIZE + 1;	// Max 4K QHD (3840x1920).
parameter W_DELAY = 12;
parameter WIDTH 	= 128;
parameter HEIGHT 	= 128;
parameter INFILE    = "C:/AIX2022/aix2022/sim/input_data/butterfly_08bit.hex";
parameter OUTFILE0  = "C:/AIX2022/aix2022/sim/output/fmap00.bmp";
parameter OUTFILE1  = "C:/AIX2022/aix2022/sim/output/fmap01.bmp";
parameter OUTFILE2  = "C:/AIX2022/aix2022/sim/output/fmap02.bmp";
parameter OUTFILE3  = "C:/AIX2022/aix2022/sim/output/fmap03.bmp";
parameter FRAME_SIZE = WIDTH * HEIGHT;
parameter VSYNC_DELAY = 200;
parameter HSYNC_DELAY = 160;
localparam FRAME_SIZE_W = $clog2(FRAME_SIZE);
reg [7:0] in_img [0:FRAME_SIZE-1];	// Input image
reg clk;
reg rstn;
// MACs, Conv kernels
reg vld_i;
reg [127:0] win[0:3];
reg [127:0] din;
wire[ 19:0] acc_o[0:3];
wire        vld_o[0:3];
wire frame_done[0:3];

// CNN Controller
reg [W_SIZE-1 :0] q_width;
reg [W_SIZE-1 :0] q_height;
reg [W_DELAY-1:0] q_vsync_delay;
reg [W_DELAY-1:0] q_hsync_delay;
reg [W_FRAME_SIZE-1:0] q_frame_size;
reg q_start;
wire 			     ctrl_vsync_run;
wire [W_DELAY-1:0]	 ctrl_vsync_cnt;
wire 				 ctrl_hsync_run;
wire [W_DELAY-1:0]	 ctrl_hsync_cnt;
wire 				 ctrl_data_run;
wire [W_SIZE-1:0] 	 row;
wire [W_SIZE-1:0] 	 col;
wire [W_FRAME_SIZE-1:0]data_count;
wire end_frame;
//-------------------------------------------
// DUT: MACs
//-------------------------------------------
mac u_mac_00(
./*input 		 */clk(clk), 
./*input 		 */rstn(rstn), 
./*input 		 */vld_i(vld_i), 
./*input [127:0] */win(win[0]), 
./*input [127:0] */din(din),
./*output[ 19:0] */acc_o(acc_o[0]), 
./*output        */vld_o(vld_o[0])
);
mac u_mac_01(
./*input 		 */clk(clk), 
./*input 		 */rstn(rstn), 
./*input 		 */vld_i(vld_i), 
./*input [127:0] */win(win[1]), 
./*input [127:0] */din(din),
./*output[ 19:0] */acc_o(acc_o[1]), 
./*output        */vld_o(vld_o[1])
);
mac u_mac_02(
./*input 		 */clk(clk), 
./*input 		 */rstn(rstn), 
./*input 		 */vld_i(vld_i), 
./*input [127:0] */win(win[2]), 
./*input [127:0] */din(din),
./*output[ 19:0] */acc_o(acc_o[2]), 
./*output        */vld_o(vld_o[2])
);
mac u_mac_03(
./*input 		 */clk(clk), 
./*input 		 */rstn(rstn), 
./*input 		 */vld_i(vld_i), 
./*input [127:0] */win(win[3]), 
./*input [127:0] */din(din),
./*output[ 19:0] */acc_o(acc_o[3]), 
./*output        */vld_o(vld_o[3])
);
//-------------------------------------------------
// Controller (FSM)
//-------------------------------------------------
cnn_ctrl u_cnn_ctrl (
.clk(clk),
.rstn(rstn),
// Inputs
.q_width(q_width),
.q_height(q_height),
.q_vsync_delay(q_vsync_delay),
.q_hsync_delay(q_hsync_delay),
.q_frame_size(q_frame_size),
.q_start(q_start),
//output
.o_ctrl_vsync_run(ctrl_vsync_run),
.o_ctrl_vsync_cnt(ctrl_vsync_cnt),
.o_ctrl_hsync_run(ctrl_hsync_run),
.o_ctrl_hsync_cnt(ctrl_hsync_cnt),
.o_ctrl_data_run(ctrl_data_run),
.o_row(row),
.o_col(col),
.o_data_count(data_count),
.o_end_frame(end_frame)
);
//-------------------------------------------
// DUT: bmp_image_writer.v
//-------------------------------------------
bmp_image_writer #(.OUTFILE(OUTFILE0))
u_out_fmap00(
./*input 	 */clk(clk),
./*input 	 */rstn(rstn),
./*input[7:0]*/din(acc_o[0][19:12]),
./*input 	 */vld(vld_o[0]),
./*output    */frame_done(frame_done[0])
);

bmp_image_writer #(.OUTFILE(OUTFILE1))
u_out_fmap01(
./*input 	 */clk(clk),
./*input 	 */rstn(rstn),
./*input[7:0]*/din(acc_o[1][19:12]),
./*input 	 */vld(vld_o[1]),
./*output    */frame_done(frame_done[1])
);

bmp_image_writer #(.OUTFILE(OUTFILE2))
u_out_fmap02(
./*input 	 */clk(clk),
./*input 	 */rstn(rstn),
./*input[7:0]*/din(acc_o[2][19:12]),
./*input 	 */vld(vld_o[2]),
./*output    */frame_done(frame_done[2])
);

bmp_image_writer #(.OUTFILE(OUTFILE3))
u_out_fmap03(
./*input 	 */clk(clk),
./*input 	 */rstn(rstn),
./*input[7:0]*/din(acc_o[3][19:12]),
./*input 	 */vld(vld_o[3]),
./*output    */frame_done(frame_done[3])
);
// Clock
parameter CLK_PERIOD = 10;	//100MHz
initial begin
	clk = 1'b1;
	forever #(CLK_PERIOD/2) clk = ~clk;
end
integer i;

//------------------------------------------------------------------------------------------------------
// Test cases
//------------------------------------------------------------------------------------------------------
// Read the input file to memory
initial begin
	$readmemh(INFILE, in_img ,0,FRAME_SIZE-1);
end
initial begin
	rstn = 1'b0;			// Reset, low active	
	q_width 		= WIDTH;
	q_height 		= HEIGHT;
	q_vsync_delay 	= VSYNC_DELAY;
	q_hsync_delay 	= HSYNC_DELAY;		
	q_frame_size 	= FRAME_SIZE;
	q_start 		= 1'b0;	
	vld_i= 0;
	din = 0;
	i = 0; 
	
	// CNN filters of four output channels
	win[0][  7:  0] = 8'd142; win[1][  7:  0] = 8'd69 ; win[2][  7:  0] = 8'd13 ; win[3][  7:  0] = 8'd69 ;
	win[0][ 15:  8] = 8'd151; win[1][ 15:  8] = 8'd181; win[2][ 15:  8] = 8'd244; win[3][ 15:  8] = 8'd135;
	win[0][ 23: 16] = 8'd215; win[1][ 23: 16] = 8'd209; win[2][ 23: 16] = 8'd255; win[3][ 23: 16] = 8'd235;
	win[0][ 31: 24] = 8'd127; win[1][ 31: 24] = 8'd19 ; win[2][ 31: 24] = 8'd241; win[3][ 31: 24] = 8'd128;
	win[0][ 39: 32] = 8'd163; win[1][ 39: 32] = 8'd128; win[2][ 39: 32] = 8'd127; win[3][ 39: 32] = 8'd32 ;
	win[0][ 47: 40] = 8'd205; win[1][ 47: 40] = 8'd95 ; win[2][ 47: 40] = 8'd240; win[3][ 47: 40] = 8'd90 ;
	win[0][ 55: 48] = 8'd229; win[1][ 55: 48] = 8'd221; win[2][ 55: 48] = 8'd252; win[3][ 55: 48] = 8'd48 ;
	win[0][ 63: 56] = 8'd255; win[1][ 63: 56] = 8'd121; win[2][ 63: 56] = 8'd237; win[3][ 63: 56] = 8'd52 ;
	win[0][ 71: 64] = 8'd113; win[1][ 71: 64] = 8'd8  ; win[2][ 71: 64] = 8'd1  ; win[3][ 71: 64] = 8'd211;
	win[0][ 79: 72] = 8'd0  ; win[1][ 79: 72] = 8'd0  ; win[2][ 79: 72] = 8'd0  ; win[3][ 79: 72] = 8'd0  ;
	win[0][ 87: 80] = 8'd0  ; win[1][ 87: 80] = 8'd0  ; win[2][ 87: 80] = 8'd0  ; win[3][ 87: 80] = 8'd0  ;
	win[0][ 95: 88] = 8'd0  ; win[1][ 95: 88] = 8'd0  ; win[2][ 95: 88] = 8'd0  ; win[3][ 95: 88] = 8'd0  ;
	win[0][103: 96] = 8'd0  ; win[1][103: 96] = 8'd0  ; win[2][103: 96] = 8'd0  ; win[3][103: 96] = 8'd0  ;
	win[0][111:104] = 8'd0  ; win[1][111:104] = 8'd0  ; win[2][111:104] = 8'd0  ; win[3][111:104] = 8'd0  ;
	win[0][119:112] = 8'd0  ; win[1][119:112] = 8'd0  ; win[2][119:112] = 8'd0  ; win[3][119:112] = 8'd0  ;
	win[0][127:120] = 8'd0  ; win[1][127:120] = 8'd0  ; win[2][127:120] = 8'd0  ; win[3][127:120] = 8'd0  ;		
	
	#(4*CLK_PERIOD) rstn = 1'b1;
	
	#(100*CLK_PERIOD) 
        @(posedge clk)
            q_start = 1'b1;
	#(4*CLK_PERIOD) 
        @(posedge clk)
            q_start = 1'b0;
end

// Generate din
wire is_first_row = (row == 0) ? 1'b1: 1'b0;
wire is_last_row  = (row == HEIGHT-1) ? 1'b1: 1'b0;
wire is_first_col = (col == 0) ? 1'b1: 1'b0;
wire is_last_col  = (col == WIDTH-1) ? 1'b1 : 1'b0;

always@(*) begin
    din = 128'd0;
    vld_i = 1'b0;
    if(ctrl_data_run) begin
        vld_i = 1'b1;
        din[ 7: 0] = (is_first_row | is_first_col) ? 8'd0 : in_img[(row-1) * WIDTH + (col-1)];
        din[15: 8] = (is_first_row               ) ? 8'd0 : in_img[(row-1) * WIDTH +  col   ];
        din[23:16] = (is_first_row | is_last_col ) ? 8'd0 : in_img[(row-1) * WIDTH + (col+1)];
        din[31:24] = (               is_first_col) ? 8'd0 : in_img[ row    * WIDTH + (col-1)];
        din[39:32] =                                        in_img[ row    * WIDTH +  col   ];
        din[47:40] = (               is_last_col ) ? 8'd0 : in_img[ row    * WIDTH + (col+1)];
        din[55:48] = (is_last_row | is_first_col ) ? 8'd0 : in_img[(row+1) * WIDTH + (col-1)];
        din[63:56] = (is_last_row | is_first_col ) ? 8'd0 : in_img[(row+1) * WIDTH + (col-1)];
        din[71:64] = (is_last_row | is_first_col ) ? 8'd0 : in_img[(row+1) * WIDTH + (col+1)];
    end    
end 
endmodule

