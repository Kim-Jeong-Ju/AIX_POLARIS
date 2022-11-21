`timescale 1ns / 1ps

module cnv_tb;

parameter WIDTH 	= 128;
parameter HEIGHT 	= 128;
parameter Ti = 16;	// Each CONV kernel do 16 multipliers at the same time	
parameter To = 4;	// Run 4 CONV kernels at the same time
parameter WI = 8;
parameter PARAM_BITS 	= 16;
parameter ACT_BITS		= 8;

// Block ram for weights
parameter N_DELAY 	    = 1;	
parameter N_CELL  		= 16;
parameter N_CELL_PARAM	= 16;
parameter W_CELL 		= $clog2(N_CELL);
parameter W_CELL_PARAM 	= $clog2(N_CELL_PARAM);	

parameter INFILE    = " */butterfly_08bit.hex"; // check your file path
localparam FRAME_SIZE = WIDTH * HEIGHT;
localparam FRAME_SIZE_W = $clog2(FRAME_SIZE);
wire [7:0] in_img [0:FRAME_SIZE-1];	// Input image
//reg [8*(WIDTH+2)-1:0] fmap_buffer [0:2]; // considering padding
wire [8*WIDTH*HEIGHT-1:0] img;
reg [Ti*WI-1:0] win[0:To-1];			// Weight
reg [PARAM_BITS-1:0] scale[0:To-1];		// Scales (Batch normalization)
reg [PARAM_BITS-1:0] bias[0:To-1];		// Biases
reg load_start;
wire load_done;
reg clk;
reg rstn;
reg vld_i;
//reg [127:0] win[0:3];
reg [127:0] din;
wire[ 19:0] acc_o[0:3];
wire        vld_o[0:3];

localparam MEM_ADDRW = 22;
localparam MEM_DW = 8;
localparam A = 32;
localparam D = 32;
localparam I = 4;
localparam L = 8;
localparam M = D/8;

//AXI Master IF0 for input/out access
wire  [I-1:0]     i_AWID;       // Address ID
wire  [A-1:0]     i_AWADDR;     // Address Write
wire  [L-1:0]     i_AWLEN;      // Transfer length
wire  [2:0]       i_AWSIZE;     // Transfer width
wire  [1:0]       i_AWBURST;    // Burst type
wire  [1:0]       i_AWLOCK;     // Atomic access information
wire  [3:0]       i_AWCACHE;    // Cachable/bufferable infor
wire  [2:0]       i_AWPROT;     // Protection info
wire              i_AWVALID;    // address/control valid handshake
wire              i_AWREADY;
wire  [I-1:0]     i_WID;        // Write ID
wire  [D-1:0]     i_WDATA;      // Write Data bus
wire  [M-1:0]     i_WSTRB;      // Write Data byte lane strobes
wire              i_WLAST;      // Last beat of a burst transfer
wire              i_WVALID;     // Write data valid
wire              i_WREADY;     // Write data ready
wire [I-1:0]      i_BID;        // buffered response ID
wire [1:0]        i_BRESP;      // Buffered write response
wire              i_BVALID;     // Response info valid
wire              i_BREADY;     // Response info ready (to slave)
wire  [I-1:0]     i_ARID;       // Read addr ID
wire  [A-1:0]     i_ARADDR;     // Address Read 
wire  [L-1:0]     i_ARLEN;      // Transfer length
wire  [2:0]       i_ARSIZE;     // Transfer width
wire  [1:0]       i_ARBURST;    // Burst type
wire  [1:0]       i_ARLOCK;     // Atomic access information
wire  [3:0]       i_ARCACHE;    // Cachable/bufferable infor
wire  [2:0]       i_ARPROT;     // Protection info
wire              i_ARVALID;    // address/control valid handshake
wire              i_ARREADY;
wire  [I-1:0]     i_RID;        // Read ID
wire  [D-1:0]     i_RDATA;      // Read data bus
wire  [1:0]       i_RRESP;      // Read response
wire              i_RLAST;      // Last beat of a burst transfer
wire              i_RVALID;     // Read data valid 
wire              i_RREADY;     // Read data ready (to Slave)

// Memory ports for input (activation)
wire [MEM_ADDRW-1:0]   mem_addr;
wire                   mem_we;
wire [MEM_DW-1:0]      mem_di;
wire [MEM_DW-1:0]      mem_do;

//--------------------------------------------------------------------------------
//AXI Slave External Memory: Input
//--------------------------------------------------------------------------------
axi_sram_if #(  //New
   .MEM_ADDRW(MEM_ADDRW), .MEM_DW(MEM_DW),
   .A(A), .I(I), .L(L), .D(D), .M(M))
u_axi_ext_mem_if_input(
   .ACLK(clk), .ARESETn(rstn),

   //AXI Slave IF
   .ARID    (i_ARID),   // Read addr ID
   .ARADDR  (i_ARADDR),   // Address Read 
   .ARLEN   (i_ARLEN),   // Transfer length
   .ARSIZE  (i_ARSIZE),   // Transfer width
   .ARBURST (i_ARBURST),   // Burst type
   .ARLOCK  (i_ARLOCK),   // Atomic access information
   .ARCACHE (i_ARCACHE),   // Cachable/bufferable infor
   .ARPROT  (i_ARPROT),   // Protection info
   .ARVALID (i_ARVALID),   // address/control valid handshake
   .ARREADY (i_ARREADY),
   .RID     (i_RID),   // Read ID
   .RDATA   (i_RDATA),   // Read data bus
   .RRESP   (i_RRESP),   // Read response
   .RLAST   (i_RLAST),   // Last beat of a burst transfer
   .RVALID  (i_RVALID),   // Read data valid 
   .RREADY  (i_RREADY),   // Read data ready (to Slave)

   //Interface to SRAM 
   .mem_addr   (mem_addr),
   .mem_we     (mem_we),
   .mem_di     (mem_di),
   .mem_do     (mem_do)
);

//------------------------------------------------------------------------------------
// Input
//IMEM for SIM
// Inputs
sram #(
   .FILE_NAME(INFILE),
   .SIZE(2**MEM_ADDRW),
   .WL_ADDR(MEM_ADDRW),
   .WL_DATA(MEM_DW))
u_ext_mem_input (
   .clk   (clk),
   .rst   (rstn),
   .addr  (mem_addr),
   .wdata (mem_di),
   .rdata (mem_do),
   .ena   (1'b0)     // Read only
   );
   
//--------------------------------------------------------------------------------
//AXI Slave External Memory: Output
//--------------------------------------------------------------------------------
axi_sram_if #(  //New
   .MEM_ADDRW(MEM_ADDRW), .MEM_DW(MEM_DW),
   .A(A), .I(I), .L(L), .D(D), .M(M))
u_axi_ext_mem_if_output (
   .ACLK(clk), .ARESETn(resetn),

   //AXI Slave IF
   .AWID    (i_AWID),       // Address ID
   .AWADDR  (i_AWADDR),     // Address Write
   .AWLEN   (i_AWLEN),      // Transfer length
   .AWSIZE  (i_AWSIZE),    // Transfer width
   .AWBURST (i_AWBURST),   // Burst type
   .AWLOCK  (i_AWLOCK),   // Atomic access information
   .AWCACHE (i_AWCACHE),   // Cachable/bufferable infor
   .AWPROT  (i_AWPROT),   // Protection info
   .AWVALID (i_AWVALID),   // address/control valid handshake
   .AWREADY (i_AWREADY),
   .WID     (i_WID),   // Write ID
   .WDATA   (i_WDATA),   // Write Data bus
   .WSTRB   (i_WSTRB),   // Write Data byte lane strobes
   .WLAST   (i_WLAST),   // Last beat of a burst transfer
   .WVALID  (i_WVALID),   // Write data valid
   .WREADY  (i_WREADY),    // Write data ready
   .BID     (i_BID),   // buffered response ID
   .BRESP   (i_BRESP),   // Buffered write response
   .BVALID  (i_BVALID),   // Response info valid
   .BREADY  (i_BREADY),   // Response info ready (to slave)

   //Interface to SRAM 
   .mem_addr   (mem_w_addr),
   .mem_we     (mem_w_we),
   .mem_di     (mem_w_di),
   .mem_do     (mem_w_do)
);

// Outputs
sram #(
   .SIZE(2**MEM_ADDRW),
   .WL_ADDR(MEM_ADDRW),
   .WL_DATA(MEM_DW))
u_ext_mem_output (
   .clk   (clk),
   .rst   (resetn),
   .addr  (mem_w_addr),
   .wdata (mem_w_di),
   .rdata (mem_w_do),
   .ena   (mem_w_we)
   );
   
line_loader #(
    .AXI_WIDTH_AD(A),
    .AXI_WIDTH_ID(4),
    .AXI_WIDTH_DA(D),
    .AXI_WIDTH_DS(M),
    .AXI_LITE_WIDTH_AD(8),        // axi lite address width
    .AXI_LITE_WIDTH_DA(32),        // axi lite data width
    .AXI_LITE_WIDTH_DS(4) // data strobe width
)
u_line_loader
 (
    .ap_clk(clk),
    .ap_rst_n(rstn),
    // AXI MASTER 
    .m_axi_memory_bus_AWVALID(i_AWVALID),
    .m_axi_memory_bus_AWREADY(i_AWREADY),
    .m_axi_memory_bus_AWADDR(i_AWADDR),
    .m_axi_memory_bus_AWID(i_AWID),
    .m_axi_memory_bus_AWLEN(i_AWLEN),
    .m_axi_memory_bus_AWSIZE(i_AWSIZE),
    .m_axi_memory_bus_AWBURST(i_AWBURST),
    .m_axi_memory_bus_AWLOCK(i_AWLOCK),
    .m_axi_memory_bus_AWCACHE(i_AWCACHE),
    .m_axi_memory_bus_AWPROT(i_AWPROT),
    .m_axi_memory_bus_AWQOS(), // AWQOS unused
    .m_axi_memory_bus_AWREGION(), // AWREGION unused
    .m_axi_memory_bus_AWUSER(), // AWUSER unused
    .m_axi_memory_bus_WVALID(i_WVALID),
    .m_axi_memory_bus_WREADY(i_WREADY),
    .m_axi_memory_bus_WDATA(i_WDATA),
    .m_axi_memory_bus_WSTRB(i_WSTRB),
    .m_axi_memory_bus_WLAST(i_WLAST),
    .m_axi_memory_bus_WID(i_WID),
    .m_axi_memory_bus_WUSER(), // WUSER unused
    .m_axi_memory_bus_ARVALID(i_ARVALID),
    .m_axi_memory_bus_ARREADY(i_ARREADY),
    .m_axi_memory_bus_ARADDR(i_ARADDR),
    .m_axi_memory_bus_ARID(i_ARID),
    .m_axi_memory_bus_ARLEN(i_ARLEN),
    .m_axi_memory_bus_ARSIZE(i_ARSIZE),
    .m_axi_memory_bus_ARBURST(i_ARBURST),
    .m_axi_memory_bus_ARLOCK(i_ARLOCK),
    .m_axi_memory_bus_ARCACHE(i_ARCACHE),
    .m_axi_memory_bus_ARPROT(i_ARPROT),
    .m_axi_memory_bus_ARQOS(), // ARQOS unused
    .m_axi_memory_bus_ARREGION(), // ARREGION unused
    .m_axi_memory_bus_ARUSER(), // ARUSER unused
    .m_axi_memory_bus_RVALID(i_RVALID),
    .m_axi_memory_bus_RREADY(i_RREADY),
    .m_axi_memory_bus_RDATA(i_RDATA),
    .m_axi_memory_bus_RLAST(i_RLAST),
    .m_axi_memory_bus_RID(i_RID),
    .m_axi_memory_bus_RUSER(), // RUSER unused
    .m_axi_memory_bus_RRESP(i_RRESP),
    .m_axi_memory_bus_BVALID(i_BVALID),
    .m_axi_memory_bus_BREADY(i_BREADY),
    .m_axi_memory_bus_BRESP(i_BRESP),
    .m_axi_memory_bus_BID(i_BID),
    .m_axi_memory_bus_BUSER(), // BUSER unused
    
    .o_ctrl_vsync_run(ctrl_vsync_run),
    .o_ctrl_hsync_run(ctrl_hsync_run),
    .img(img),
    .load_start(load_start),
    .load_done(load_done)
);


//-------------------------------------------
// DUT: Controller
//-------------------------------------------

parameter W_SIZE  = 12;					// Max 4K QHD (3840x1920).
parameter W_FRAME_SIZE  = 2 * W_SIZE + 1;	// Max 4K QHD (3840x1920).
parameter W_DELAY = 12;
parameter VSYNC_DELAY = 150;
parameter HSYNC_DELAY = 150;

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


cnn_ctrl u_cnn_ctrl(
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

// Weight/bias/scale buffer's signals
// weight
reg 			     weight_buf_en; 	   // primary enable
reg 			     weight_buf_en_d; 	   // primary enable
reg 			     weight_buf_en_2d; 	   // primary enable
reg 			     weight_buf_we; 	   // primary synchronous write enable
reg [W_CELL-1:0]     weight_buf_addr;      // address for read/write
reg [W_CELL-1:0]     weight_buf_addr_d;	   // 1-cycle delay address
reg [W_CELL-1:0]     weight_buf_addr_2d;   // 2-cycle delay address
wire[Ti*WI-1:0]      weight_buf_dout;      // Output for weights
// bias/scale
reg 			       param_buf_en; 	     // primary enable
reg 			       param_buf_en_d; 	     // primary enable
reg 			       param_buf_en_2d; 	     // primary enable
reg 			       param_buf_we; 	     // primary synchronous write enable
reg [W_CELL_PARAM-1:0] param_buf_addr;   	 // address for read/write
reg [W_CELL_PARAM-1:0] param_buf_addr_d;	 // 1-cycle delay address
reg [W_CELL_PARAM-1:0] param_buf_addr_2d;	 // 2-cycle delay address
wire[PARAM_BITS-1:0]   param_buf_dout_bias;  // Output for biases
wire[PARAM_BITS-1:0]   param_buf_dout_scale; // Output for scales

wire frame_done[0:To-1];
integer ch_idx;

// fmap buffer
reg [FRAME_SIZE_W-1:0] pixel_count;
reg layer_done;

// Weight
always@(*) begin
    weight_buf_en   = 1'b0;
    weight_buf_we   = 1'b0;
    weight_buf_addr = {W_CELL{1'b0}};
    if(ctrl_vsync_run) begin
        if(ctrl_vsync_cnt < To + 1) begin // 2 cycle delay spram : To + 1, 1 cycle delay spram : To
            weight_buf_en   = 1'b1;
            weight_buf_we   = 1'b0;
            weight_buf_addr = ctrl_vsync_cnt[W_CELL-1:0];
        end
    end
end

// Scale/bias
always@(*) begin
    param_buf_en   = 1'b0;
    param_buf_we   = 1'b0;
    param_buf_addr = {W_CELL{1'b0}};
    if(ctrl_vsync_run) begin
        if(ctrl_vsync_cnt < To + 1) begin // 2 cycle delay spram : To + 1, 1 cycle delay spram : To
            param_buf_en   = 1'b1;
            param_buf_we   = 1'b0;
            param_buf_addr = ctrl_vsync_cnt[W_CELL-1:0];
        end
    end
end

// one-cycle, two_cycle delay
always@(posedge clk, negedge rstn)begin
    if(~rstn) begin
        weight_buf_en_d   <= 1'b0;
        weight_buf_en_2d   <= 1'b0;
        weight_buf_addr_d <= {W_CELL{1'b0}};	
        weight_buf_addr_2d <= {W_CELL{1'b0}};	
        param_buf_en_d 	  <= 1'b0;
        param_buf_en_2d 	  <= 1'b0;
        param_buf_addr_d  <= {W_CELL{1'b0}};
        param_buf_addr_2d  <= {W_CELL{1'b0}};
    end
    else begin		
        weight_buf_en_d   <= weight_buf_en; 
        weight_buf_en_2d   <= weight_buf_en_d; 
        weight_buf_addr_d <= weight_buf_addr;
        weight_buf_addr_2d <= weight_buf_addr_d;
        param_buf_en_d 	  <= param_buf_en;	 
        param_buf_en_2d 	  <= param_buf_en_d;	 
        param_buf_addr_d  <= param_buf_addr;
        param_buf_addr_2d  <= param_buf_addr_d;
    end
end


 // two_cycle delay
always@(posedge clk, negedge rstn)begin
    if(~rstn) begin
        for(ch_idx = 0; ch_idx <To; ch_idx=ch_idx+1) begin
            win[ch_idx]  <= {(Ti*WI){1'b0}};
            scale[ch_idx] <= {PARAM_BITS{1'b0}};
            bias[ch_idx] <= {PARAM_BITS{1'b0}};
        end
    end
    else begin
        // Weight
        if(weight_buf_en_2d)
            win[weight_buf_addr_2d] <= weight_buf_dout;
        // Scale/bias
        if(param_buf_en_2d) begin
            bias[param_buf_addr_2d] <= param_buf_dout_bias; 
            scale[param_buf_addr_2d] <= param_buf_dout_scale;
        end
    end
end

// Weight buffer
spram_wrapper_weight #(.DW(Ti*WI),.AW(W_CELL),.DEPTH(N_CELL))
u_buf_weight(
    .clk (clk            ), // Clock input
    .cs  (weight_buf_en  ), // RAM enable (select)
    .addr(weight_buf_addr), // Address input(word addressing)
    .wdata (/*unused*/     ), // Data input
    .we  (weight_buf_we  ), // Write enable
    .rdata (weight_buf_dout)  // Data output
);

// Bias buffer
spram_wrapper_bias #(.DW(PARAM_BITS),.AW(W_CELL),.DEPTH(N_CELL))
u_buf_bias(
    .clk (clk            ), // Clock input
    .cs  (param_buf_en  ), // RAM enable (select)
    .addr(param_buf_addr), // Address input(word addressing)
    .wdata (/*unused*/     ), // Data input
    .we  (param_buf_we  ), // Write enable
    .rdata (param_buf_dout_bias)  // Data output
);

// Scale buffer
spram_wrapper_scale #(.DW(PARAM_BITS),.AW(W_CELL),.DEPTH(N_CELL))
u_buf_scale(
    .clk (clk            ), // Clock input
    .cs  (param_buf_en  ), // RAM enable (select)
    .addr(param_buf_addr), // Address input(word addressing)
    .wdata (/*unused*/     ), // Data input
    .we  (param_buf_we  ), // Write enable
    .rdata (param_buf_dout_scale)  // Data output
);


//-------------------------------------------------
// Output buffers.
//-------------------------------------------------
wire [ACT_BITS*To-1:0] all_acc_o = {
    acc_o[3][19:12], acc_o[2][19:12], acc_o[1][19:12], acc_o[0][19:12]
};
// store the mac results
dpram_wrapper #(.DW(To*ACT_BITS), .AW(FRAME_SIZE_W),.DEPTH(FRAME_SIZE))
u_buf_fmap(
   .clk   (clk   ),
   .ena   (vld_o[0]), 
   .wea   (vld_o[0]), 
   .addra (pixel_count), 
   .enb   (layer_done),	// for read
   .addrb (addrb ),  // for read
   .dia   (all_acc_o), 
   .dob   (dob )   // for read
);


//-------------------------------------------------
// Update the output buffers.
//-------------------------------------------------
always@(posedge clk, negedge rstn) begin
    if(!rstn) begin
        pixel_count <= 0;
        layer_done <= 0;
    end else begin
        if(q_start) begin
            pixel_count <= 0;
            layer_done <= 0;			
        end
        else begin
            if(vld_o[0]) begin
                if(pixel_count == FRAME_SIZE-1) begin
                    pixel_count <= 0;
                    layer_done <= 1'b1;
                end
                else begin
                    pixel_count <= pixel_count + 1;
                end
            end
        end
    end
end

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
//initial begin
//	$readmemh(INFILE, in_img ,0,FRAME_SIZE-1);
//end
initial begin
	rstn = 1'b0;			// Reset, low active	
	din = 0;
	i = 0;
	q_width 		= WIDTH;
	q_height 		= HEIGHT;
	q_vsync_delay 	= VSYNC_DELAY;
	q_hsync_delay 	= HSYNC_DELAY;		
	q_frame_size 	= FRAME_SIZE;
	q_start <= 1'b0;
	load_start <= 1'b0;
	
//	// CNN filters of four output channels
//	win[0][  7:  0] = 8'd142; win[1][  7:  0] = 8'd69 ; win[2][  7:  0] = 8'd13 ; win[3][  7:  0] = 8'd69 ;
//	win[0][ 15:  8] = 8'd151; win[1][ 15:  8] = 8'd181; win[2][ 15:  8] = 8'd244; win[3][ 15:  8] = 8'd135;
//	win[0][ 23: 16] = 8'd215; win[1][ 23: 16] = 8'd209; win[2][ 23: 16] = 8'd255; win[3][ 23: 16] = 8'd235;
//	win[0][ 31: 24] = 8'd127; win[1][ 31: 24] = 8'd19 ; win[2][ 31: 24] = 8'd241; win[3][ 31: 24] = 8'd128;
//	win[0][ 39: 32] = 8'd163; win[1][ 39: 32] = 8'd128; win[2][ 39: 32] = 8'd127; win[3][ 39: 32] = 8'd32 ;
//	win[0][ 47: 40] = 8'd205; win[1][ 47: 40] = 8'd95 ; win[2][ 47: 40] = 8'd240; win[3][ 47: 40] = 8'd90 ;
//	win[0][ 55: 48] = 8'd229; win[1][ 55: 48] = 8'd221; win[2][ 55: 48] = 8'd252; win[3][ 55: 48] = 8'd48 ;
//	win[0][ 63: 56] = 8'd255; win[1][ 63: 56] = 8'd121; win[2][ 63: 56] = 8'd237; win[3][ 63: 56] = 8'd52 ;
//	win[0][ 71: 64] = 8'd113; win[1][ 71: 64] = 8'd8  ; win[2][ 71: 64] = 8'd1  ; win[3][ 71: 64] = 8'd211;
//	win[0][ 79: 72] = 8'd0  ; win[1][ 79: 72] = 8'd0  ; win[2][ 79: 72] = 8'd0  ; win[3][ 79: 72] = 8'd0  ;
//	win[0][ 87: 80] = 8'd0  ; win[1][ 87: 80] = 8'd0  ; win[2][ 87: 80] = 8'd0  ; win[3][ 87: 80] = 8'd0  ;
//	win[0][ 95: 88] = 8'd0  ; win[1][ 95: 88] = 8'd0  ; win[2][ 95: 88] = 8'd0  ; win[3][ 95: 88] = 8'd0  ;
//	win[0][103: 96] = 8'd0  ; win[1][103: 96] = 8'd0  ; win[2][103: 96] = 8'd0  ; win[3][103: 96] = 8'd0  ;
//	win[0][111:104] = 8'd0  ; win[1][111:104] = 8'd0  ; win[2][111:104] = 8'd0  ; win[3][111:104] = 8'd0  ;
//	win[0][119:112] = 8'd0  ; win[1][119:112] = 8'd0  ; win[2][119:112] = 8'd0  ; win[3][119:112] = 8'd0  ;
//	win[0][127:120] = 8'd0  ; win[1][127:120] = 8'd0  ; win[2][127:120] = 8'd0  ; win[3][127:120] = 8'd0  ;		
	
	#(4*CLK_PERIOD) rstn = 1'b1;
	load_start <= 1'b1;	 
	#(4*CLK_PERIOD) 
        @(posedge clk)
            load_start <= 1'b0;
    
end
always @(posedge clk) begin
    if (load_done == 1'b1) begin
        q_start <= 1'b1;	 
        #(4*CLK_PERIOD) 
            @(posedge clk)
                q_start <= 1'b0;
    end
end 

wire is_first_row = (row == 0) ? 1'b1 : 1'b0;
wire is_last_row = (row == HEIGHT-1) ? 1'b1 : 1'b0;
wire is_first_col = (col == 0) ? 1'b1 : 1'b0;
wire is_last_col = (col == WIDTH-1) ? 1'b1 : 1'b0;

generate 
    genvar j;
    for (j = 0; j < HEIGHT*WIDTH; j = j + 1) begin
        assign in_img[j] = img[8*(j+1)-1-:8];
    end
endgenerate


always(*) begin
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
        din[63:56] = (is_last_row                ) ? 8'd0 : in_img[(row+1) * WIDTH +  col   ];
        din[71:64] = (is_last_row | is_last_col  ) ? 8'd0 : in_img[(row+1) * WIDTH + (col+1)];
    end
end


//////////////////////////////////////////////
 // for checking : read fmap and check
reg [15:0] addrb;
wire [31:0] dob;
always@(posedge clk, negedge rstn) begin
    if(!rstn) addrb <= 0;
    else if(layer_done) begin
        if(addrb == 16'd16384) layer_done <= 0;
        else addrb <= addrb + 1;
    end
end
//////////////////////////////////////////////

endmodule

