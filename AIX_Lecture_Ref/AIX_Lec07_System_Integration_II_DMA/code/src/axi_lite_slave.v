//------------------------------------------------------------+
//------------------------------------------------------------+
// Project: Deep Learning Hardware Design Contest
// Module: axi_lite_slave
// Description:
//		slave for AXI-lite bus 
//		1. Decoder for CSRs
//
// History: 2021.09.01 by NXT (truongnx@capp.snu.ac.kr)
//------------------------------------------------------------+

`timescale 1ns/1ps
module axi_lite_slave
#(parameter
    C_S_AXI_ADDR_WIDTH = 32,
    C_S_AXI_DATA_WIDTH = 32
)(

    input  wire                          clk,
    input  wire                          reset,	// Warning: Active HIGH for Reset
    input  wire                          clk_en,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AWADDR,
    input  wire                          S_AWVALID,
    output wire                          S_AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1:0] S_WDATA,
    input  wire [C_S_AXI_DATA_WIDTH/8-1:0] S_WSTRB,
    input  wire                          S_WVALID,
    output wire                          S_WREADY,
    output wire [1:0]                    S_BRESP,
    output wire                          S_BVALID,
    input  wire                          S_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_ARADDR,
    input  wire                          S_ARVALID,
    output wire                          S_ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1:0] S_RDATA,
    output wire [1:0]                    S_RRESP,
    output wire                          S_RVALID,
    input  wire                          S_RREADY,
    output wire                          interrupt,

    output wire                          ap_start,
    input  wire                          ap_done,
    input  wire                          ap_ready,
    input  wire                          ap_idle,
    output wire [7:0]                    layer_num
);

//---------------------------------------------------------------------
// parameter definitions 
//---------------------------------------------------------------------
localparam
    ADDR_AP_CTRL          = 5'h00,
    ADDR_GIE              = 5'h04,
    ADDR_IER              = 5'h08,
    ADDR_ISR              = 5'h0c,
    ADDR_LAYER_NUM_DATA_0 = 5'h10,
    ADDR_LAYER_NUM_CTRL   = 5'h14;

//	
localparam	
    WRIDLE                = 2'd0,
    WRDATA                = 2'd1,
    WRRESP                = 2'd2,
    WRRESET               = 2'd3,
    RDIDLE                = 2'd0,
    RDDATA                = 2'd1,
    RDRESET               = 2'd2,
    ADDR_BITS         = 5;

//---------------------------------------------------------------------
// Internal signals 
//---------------------------------------------------------------------
    reg  [1:0]            wstate = WRRESET;
    reg  [1:0]            wnext;
    reg  [ADDR_BITS-1:0]  waddr;
    wire [31:0]           wmask;
    wire                  aw_hs;
    wire                  w_hs;
    reg  [1:0]            rstate = RDRESET;
    reg  [1:0]            rnext;
    reg  [31:0]           rdata;
    wire                  ar_hs;
    wire [ADDR_BITS-1:0]  raddr;


    reg                   int_ap_idle;
    reg                   int_ap_ready;
    reg                   int_ap_done = 1'b0;
    reg                   int_ap_start = 1'b0;
    reg                   int_auto_restart = 1'b0;
    reg                   int_gie = 1'b0;
    reg  [1:0]            int_ier = 2'b0;
    reg  [1:0]            int_isr = 2'b0;
    reg  [7:0]            int_layer_num = 'b0;


assign S_AWREADY = (wstate == WRIDLE);
assign S_WREADY  = (wstate == WRDATA);
assign S_BRESP   = 2'b00;  // OKAY
assign S_BVALID  = (wstate == WRRESP);
assign wmask   = { {8{S_WSTRB[3]}}, {8{S_WSTRB[2]}}, {8{S_WSTRB[1]}}, {8{S_WSTRB[0]}} };
assign aw_hs   = S_AWVALID & S_AWREADY;
assign w_hs    = S_WVALID & S_WREADY;

//------------------------------------------------------------+
//FSM For write
//------------------------------------------------------------+
always @(posedge clk) begin
    if (reset)
        wstate <= WRRESET;
    else if (clk_en)
        wstate <= wnext;
end


always @(*) begin
    case (wstate)
        WRIDLE:
            if (S_AWVALID)
                wnext = WRDATA;
            else
                wnext = WRIDLE;
        WRDATA:
            if (S_WVALID)
                wnext = WRRESP;
            else
                wnext = WRDATA;
        WRRESP:
            if (S_BREADY)
                wnext = WRIDLE;
            else
                wnext = WRRESP;
        default:
            wnext = WRIDLE;
    endcase
end

// Address phase
always @(posedge clk) begin
    if (clk_en) begin
        if (aw_hs)
            waddr <= S_AWADDR[ADDR_BITS-1:0];
    end
end

// Data phase
always @(posedge clk) begin
    if (reset) begin
		int_auto_restart <= 1'b0;
		int_gie <= 1'b0;
	end
	else if (clk_en) begin
		if(w_hs && S_WSTRB[0]) begin
			case(waddr)
				ADDR_AP_CTRL: int_auto_restart <=  S_WDATA[7];
				ADDR_GIE: int_gie <= S_WDATA[0];
				ADDR_IER: int_ier <= S_WDATA[1:0];
				ADDR_ISR: begin 
					int_isr[0] <= int_isr[0] ^ S_WDATA[0];
					int_isr[1] <= int_isr[1] ^ S_WDATA[1]; 
				end
				ADDR_LAYER_NUM_DATA_0: int_layer_num[7:0] <= (S_WDATA[31:0] & wmask) | (int_layer_num[7:0] & ~wmask);
				default:;
			endcase
		end
	end
end


//always @(posedge clk) begin
//    if (reset)
//        int_auto_restart <= 1'b0;
//    else if (clk_en) begin
//        if (w_hs && waddr == ADDR_AP_CTRL && S_WSTRB[0])
//            int_auto_restart <=  S_WDATA[7];
//    end
//end
//
//
//always @(posedge clk) begin
//    if (reset)
//        int_gie <= 1'b0;
//    else if (clk_en) begin
//        if (w_hs && waddr == ADDR_GIE && S_WSTRB[0])
//            int_gie <= S_WDATA[0];
//    end
//end
//
//
//always @(posedge clk) begin
//    if (reset)
//        int_ier <= 1'b0;
//    else if (clk_en) begin
//        if (w_hs && waddr == ADDR_IER && S_WSTRB[0])
//            int_ier <= S_WDATA[1:0];
//    end
//end
//
//
//always @(posedge clk) begin
//    if (reset)
//        int_isr[0] <= 1'b0;
//    else if (clk_en) begin
//        if (int_ier[0] & ap_done)
//            int_isr[0] <= 1'b1;
//        else if (w_hs && waddr == ADDR_ISR && S_WSTRB[0])
//            int_isr[0] <= int_isr[0] ^ S_WDATA[0];
//    end
//end
//
//
//always @(posedge clk) begin
//    if (reset)
//        int_isr[1] <= 1'b0;
//    else if (clk_en) begin
//        if (int_ier[1] & ap_ready)
//            int_isr[1] <= 1'b1;
//        else if (w_hs && waddr == ADDR_ISR && S_WSTRB[0])
//            int_isr[1] <= int_isr[1] ^ S_WDATA[1]; 
//    end
//end
//
//
//always @(posedge clk) begin
//    if (reset)
//        int_layer_num[7:0] <= 0;
//    else if (clk_en) begin
//        if (w_hs && waddr == ADDR_LAYER_NUM_DATA_0)
//            int_layer_num[7:0] <= (S_WDATA[31:0] & wmask) | (int_layer_num[7:0] & ~wmask);
//    end
//end

//------------------------------------------------------------+
//FSM for read
//------------------------------------------------------------+
assign S_ARREADY = (rstate == RDIDLE);
assign S_RDATA   = rdata;
assign S_RRESP   = 2'b00;  // OKAY
assign S_RVALID  = (rstate == RDDATA);
assign ar_hs   = S_ARVALID & S_ARREADY;
assign raddr   = S_ARADDR[ADDR_BITS-1:0];


always @(posedge clk) begin
    if (reset)
        rstate <= RDRESET;
    else if (clk_en)
        rstate <= rnext;
end


always @(*) begin
    case (rstate)
        RDIDLE:
            if (S_ARVALID)
                rnext = RDDATA;
            else
                rnext = RDIDLE;
        RDDATA:
            if (S_RREADY & S_RVALID)
                rnext = RDIDLE;
            else
                rnext = RDDATA;
        default:
            rnext = RDIDLE;
    endcase
end


always @(posedge clk) begin
    if (clk_en) begin
        if (ar_hs) begin
            rdata <= 1'b0;
            case (raddr)
                ADDR_AP_CTRL: begin
                    rdata[0] <= int_ap_start;
                    rdata[1] <= int_ap_done;
                    rdata[2] <= int_ap_idle;
                    rdata[3] <= int_ap_ready;
                    rdata[7] <= int_auto_restart;
                end
                ADDR_GIE: begin
                    rdata <= int_gie;
                end
                ADDR_IER: begin
                    rdata <= int_ier;
                end
                ADDR_ISR: begin
                    rdata <= int_isr;
                end
                ADDR_LAYER_NUM_DATA_0: begin
                    rdata <= int_layer_num[7:0];
                end
            endcase
        end
    end
end



assign interrupt = int_gie & (|int_isr);
assign ap_start  = int_ap_start;
assign layer_num = int_layer_num;

always @(posedge clk) begin
    if (reset)
        int_ap_start <= 1'b0;
    else if (clk_en) begin
        if (w_hs && waddr == ADDR_AP_CTRL && S_WSTRB[0] && S_WDATA[0])
            int_ap_start <= 1'b1;
        else if (ap_ready)
            int_ap_start <= int_auto_restart; 
    end
end


always @(posedge clk) begin
    if (reset)
        int_ap_done <= 1'b0;
    else if (clk_en) begin
        if (ap_done)
            int_ap_done <= 1'b1;
        else if (ar_hs && raddr == ADDR_AP_CTRL)
            int_ap_done <= 1'b0; 
    end
end


always @(posedge clk) begin
    if (reset)
        int_ap_idle <= 1'b0;
    else if (clk_en) begin
            int_ap_idle <= ap_idle;
    end
end


always @(posedge clk) begin
    if (reset)
        int_ap_ready <= 1'b0;
    else if (clk_en) begin
            int_ap_ready <= ap_ready;
    end
end
endmodule
