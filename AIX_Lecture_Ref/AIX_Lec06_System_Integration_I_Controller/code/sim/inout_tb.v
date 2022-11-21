`timescale 1ns / 1ps

module inout_tb;
parameter WIDTH 	= 128;
parameter HEIGHT 	= 128;
parameter INFILE    = "C:/AIX2022/aix2022/sim/input_data/butterfly_08bit.hex";
parameter OUTFILE    = "C:/AIX2022/aix2022/sim/output/butterfly.bmp";
parameter VSYNC_DELAY = 200;
parameter HSYNC_DELAY = 160;
parameter WI = 8;
localparam FRAME_SIZE = WIDTH * HEIGHT;
localparam FRAME_SIZE_W = $clog2(FRAME_SIZE);
reg [7:0] in_img [0:FRAME_SIZE-1];	// Input image
reg clk;
reg rstn;
reg vld;
reg [7:0] din;
wire frame_done;

//-------------------------------------------
// DUT: bmp_image_writer.v
//-------------------------------------------
bmp_image_writer #(.OUTFILE(OUTFILE))
u_bmp_image_writer(
./*input 	 */clk(clk),
./*input 	 */rstn(rstn),
./*input[7:0]*/din(din),
./*input 	 */vld(vld),
./*output    */frame_done(frame_done)
);
// Clock
parameter CLK_PERIOD = 10;	//100MHz
initial begin
	clk = 1'b1;
	forever #(CLK_PERIOD/2) clk = ~clk;
end
integer row, col;

//------------------------------------------------------------------------------------------------------
// Test cases
//------------------------------------------------------------------------------------------------------
// Read the input file to memory
initial begin
	$readmemh(INFILE, in_img ,0,FRAME_SIZE-1);
end

initial begin
	rstn = 1'b0;			// Reset, low active	
	vld = 0;
	din = 0;
	row = 0;
	col = 0;
	
    // Reset 
	repeat(100) @(posedge clk);
	#(4*CLK_PERIOD) rstn = 1'b1;
	
	// Frame/layer sync	 
	repeat(VSYNC_DELAY)@(posedge clk);
	for(row = 0; row < HEIGHT; row = row + 1) begin
	    // Line sync	    
		repeat(HSYNC_DELAY)@(posedge clk) vld = 1'b0;
		// Pixel data
		for(col = 0; col < WIDTH; col = col + 1) begin
		  @(posedge clk) vld = 1'b1;		  	
		   din = in_img[row * WIDTH + col]; 		
		end
	end
	
	// Layer don
	@(posedge clk) vld = 0;
	$display("Layer done!");
end

endmodule

