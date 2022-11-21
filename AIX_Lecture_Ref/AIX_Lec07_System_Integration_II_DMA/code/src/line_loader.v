//----------------------------------------------------------------+
//----------------------------------------------------------------+
// Project: Deep Learning Hardware Design Contest
// Module: line_loader
// Description:
//      Load input feature map from DRAM via AXI4
//
//----------------------------------------------------------------+

module line_loader #(
    parameter AXI_WIDTH_AD = 32,
    parameter AXI_WIDTH_ID = 4,
    parameter AXI_WIDTH_DA = 32,
    parameter AXI_WIDTH_DS = AXI_WIDTH_DA/8,
    parameter AXI_LITE_WIDTH_AD   =32,        // axi lite address width
    parameter AXI_LITE_WIDTH_DA   =32,        // axi lite data width
    parameter AXI_LITE_WIDTH_DS =(AXI_LITE_WIDTH_DA/8), // data strobe width
    parameter WIDTH = 128,
    parameter HEIGHT = 128,
    parameter KERNEL_SIZE = 3
)
(
       input                          ap_clk
     , input                          ap_rst_n
     // AXI MASTER 
     , output                         m_axi_memory_bus_AWVALID
     , input                          m_axi_memory_bus_AWREADY
     , output  [AXI_WIDTH_AD-1:0]     m_axi_memory_bus_AWADDR
     , output  [AXI_WIDTH_ID-1:0]     m_axi_memory_bus_AWID
     , output  [7:0]                  m_axi_memory_bus_AWLEN
     , output  [2:0]                  m_axi_memory_bus_AWSIZE
     , output  [1:0]                  m_axi_memory_bus_AWBURST
     , output  [1:0]                  m_axi_memory_bus_AWLOCK
     , output  [3:0]                  m_axi_memory_bus_AWCACHE
     , output  [2:0]                  m_axi_memory_bus_AWPROT
     , output  [3:0]                  m_axi_memory_bus_AWQOS
     , output  [3:0]                  m_axi_memory_bus_AWREGION
     , output  [3:0]                  m_axi_memory_bus_AWUSER
     , output                         m_axi_memory_bus_WVALID
     , input                          m_axi_memory_bus_WREADY
     , output  [AXI_WIDTH_DA-1:0]     m_axi_memory_bus_WDATA
     , output  [AXI_WIDTH_DS-1:0]     m_axi_memory_bus_WSTRB
     , output                         m_axi_memory_bus_WLAST
     , output  [AXI_WIDTH_ID-1:0]     m_axi_memory_bus_WID
     , output  [3:0]                  m_axi_memory_bus_WUSER
     , output                         m_axi_memory_bus_ARVALID
     , input                          m_axi_memory_bus_ARREADY
     , output  [AXI_WIDTH_AD-1:0]     m_axi_memory_bus_ARADDR
     , output  [AXI_WIDTH_ID-1:0]     m_axi_memory_bus_ARID
     , output  [7:0]                  m_axi_memory_bus_ARLEN
     , output  [2:0]                  m_axi_memory_bus_ARSIZE
     , output  [1:0]                  m_axi_memory_bus_ARBURST
     , output  [1:0]                  m_axi_memory_bus_ARLOCK
     , output  [3:0]                  m_axi_memory_bus_ARCACHE
     , output  [2:0]                  m_axi_memory_bus_ARPROT
     , output  [3:0]                  m_axi_memory_bus_ARQOS
     , output  [3:0]                  m_axi_memory_bus_ARREGION
     , output  [3:0]                  m_axi_memory_bus_ARUSER
     , input                          m_axi_memory_bus_RVALID
     , output                         m_axi_memory_bus_RREADY
     , input  [AXI_WIDTH_DA-1:0]      m_axi_memory_bus_RDATA
     , input                          m_axi_memory_bus_RLAST
     , input  [AXI_WIDTH_ID-1:0]      m_axi_memory_bus_RID
     , input  [3:0]                   m_axi_memory_bus_RUSER
     , input  [1:0]                   m_axi_memory_bus_RRESP
     , input                          m_axi_memory_bus_BVALID
     , output                         m_axi_memory_bus_BREADY
     , input  [1:0]                   m_axi_memory_bus_BRESP
     , input  [AXI_WIDTH_ID-1:0]      m_axi_memory_bus_BID
     , input                          m_axi_memory_bus_BUSER
     // AXI LITE SLAVE
     , input                          s_axi_axilite_AWVALID
     , output                         s_axi_axilite_AWREADY
     , input  [AXI_LITE_WIDTH_AD-1:0] s_axi_axilite_AWADDR
     , input                          s_axi_axilite_WVALID
     , output                         s_axi_axilite_WREADY
     , input  [AXI_LITE_WIDTH_DA-1:0] s_axi_axilite_WDATA
     , input  [AXI_LITE_WIDTH_DS-1:0] s_axi_axilite_WSTRB
     , input                          s_axi_axilite_ARVALID
     , output                         s_axi_axilite_ARREADY
     , input  [AXI_LITE_WIDTH_AD-1:0] s_axi_axilite_ARADDR
     , output                         s_axi_axilite_RVALID
     , input                          s_axi_axilite_RREADY
     , output [AXI_LITE_WIDTH_DA-1:0] s_axi_axilite_RDATA
     , output [1:0]                   s_axi_axilite_RRESP
     , output                         s_axi_axilite_BVALID
     , input                          s_axi_axilite_BREADY
     , output [1:0]                   s_axi_axilite_BRESP

     , output                         interrupt
     
     , input                          o_ctrl_vsync_run
     , input                          o_ctrl_hsync_run
     , input                          load_start
     , output [8*WIDTH*HEIGHT-1:0]    img
     , output                         load_done
);

reg ap_start;
reg start_dma_input_read;
reg [17:0] num_trans;
reg [AXI_WIDTH_AD-1:0] start_addr;
wire [AXI_WIDTH_DA-1:0] data_o;
wire data_vld_o;
wire [17:0] data_cnt_o;
wire done_o;
reg [8*WIDTH*HEIGHT-1:0] img_reg;
assign img = img_reg;
reg load_done;

axi_dma_rd #(
    .BITS_TRANS(18),
    .OUT_BITS_TRANS(13),
    .AXI_WIDTH_USER(1),
    .AXI_WIDTH_ID(AXI_WIDTH_ID),
    .AXI_WIDTH_AD(AXI_WIDTH_AD),
    .AXI_WIDTH_DA(AXI_WIDTH_DA),
    .AXI_WIDTH_DS(AXI_WIDTH_DS)
)
u_dma_rd (
    .M_ARVALID(m_axi_memory_bus_ARVALID),    // address/control valid handshake
    .M_ARREADY(m_axi_memory_bus_ARREADY),    // Read addr ready
    .M_ARADDR(m_axi_memory_bus_ARADDR),     // Address Read 
    .M_ARID(m_axi_memory_bus_ARID),       // Read addr ID
    .M_ARLEN(m_axi_memory_bus_ARLEN),      // Transfer length
    .M_ARSIZE(m_axi_memory_bus_ARSIZE),     // Transfer width
    .M_ARBURST(m_axi_memory_bus_ARBURST),    // Burst type
    .M_ARLOCK(m_axi_memory_bus_ARLOCK),     // Atomic access information
    .M_ARCACHE(m_axi_memory_bus_ARCACHE),    // Cachable/bufferable infor
    .M_ARPROT(m_axi_memory_bus_ARPROT),     // Protection info
    .M_ARQOS(m_axi_memory_bus_ARQOS),      // Quality of Service
    .M_ARREGION(m_axi_memory_bus_ARREGION),   // Region signaling
    .M_ARUSER(m_axi_memory_bus_ARUSER),     // User defined signal
 
    //Read data channel
    .M_RVALID(m_axi_memory_bus_RVALID),     // Read data valid 
    .M_RREADY(m_axi_memory_bus_RREADY),     // Read data ready (to Slave)
    .M_RDATA(m_axi_memory_bus_RDATA),      // Read data bus
    .M_RLAST(m_axi_memory_bus_RLAST),      // Last beat of a burst transfer
    .M_RID(m_axi_memory_bus_RID),        // Read ID
    .M_RUSER(m_axi_memory_bus_RUSER),      // User defined signal
    .M_RRESP(m_axi_memory_bus_RRESP),      // Read response
     
    //Functional Ports
    .start_dma(start_dma_input_read),
    .num_trans(num_trans), //Number of 32-bit words transferred
    .start_addr(start_addr),
    .data_o(data_o),
    .data_vld_o(data_vld_o),
    .data_cnt_o(data_cnt_o),
    .done_o(done_o),

    //Global signals
    .clk(ap_clk),
    .rstn(ap_rst_n)
);

wire [AXI_WIDTH_DA-1:0] data_tbw;
wire indata_req_o;
wire fail_check;

axi_dma_wr #(
    .BITS_TRANS(18),
    .OUT_BITS_TRANS(13),
    .AXI_WIDTH_USER(1),
    .AXI_WIDTH_ID(AXI_WIDTH_ID),
    .AXI_WIDTH_AD(AXI_WIDTH_AD),
    .AXI_WIDTH_DA(AXI_WIDTH_DA),
    .AXI_WIDTH_DS(AXI_WIDTH_DS)
)
u_dma_wr (
    .M_AWVALID(m_axi_memory_bus_AWVALID),    // address/control valid handshake
    .M_AWADDR(m_axi_memory_bus_AWADDR),     // Address Write
    .M_AWREADY(m_axi_memory_bus_AWREADY),
    .M_AWID(m_axi_memory_bus_AWID),       // Address ID
    .M_AWLEN(m_axi_memory_bus_AWLEN),      // Transfer length
    .M_AWSIZE(m_axi_memory_bus_AWSIZE),     // Transfer width
    .M_AWBURST(m_axi_memory_bus_AWBURST),    // Burst type
    .M_AWLOCK(m_axi_memory_bus_AWLOCK),     // Atomic access information
    .M_AWCACHE(m_axi_memory_bus_AWCACHE),    // Cachable/bufferable infor
    .M_AWPROT(m_axi_memory_bus_AWPROT),     // Protection info
    .M_AWQOS(m_axi_memory_bus_AWQOS),
    .M_AWREGION(m_axi_memory_bus_AWREGION),
    .M_AWUSER(m_axi_memory_bus_AWUSER),

    //Write data channel
    .M_WVALID(m_axi_memory_bus_WVALID),     // Write data valid
    .M_WREADY(m_axi_memory_bus_WREADY),     // Write data ready
    .M_WDATA(m_axi_memory_bus_WDATA),      // Write Data bus
    .M_WSTRB(m_axi_memory_bus_WSTRB),      // Write Data byte lane strobes
    .M_WLAST(m_axi_memory_bus_WLAST),      // Last beat of a burst transfer
    .M_WID(m_axi_memory_bus_WID),        // Write ID
    .M_WUSER(m_axi_memory_bus_WUSER),

    //Write response channel
    .M_BVALID(m_axi_memory_bus_BVALID),     // Response info valid
    .M_BREADY(m_axi_memory_bus_BREADY),     // Response info ready (to slave)
    .M_BRESP(m_axi_memory_bus_BRESP),      // Buffered write response
    .M_BID(m_axi_memory_bus_BID),        // buffered response ID
    .M_BUSER(m_axi_memory_bus_BUSER),

    //User interface
    .ap_start(ap_start),
    .ap_done(ap_done),
    .num_trans(num_trans),
    .mem_start_addr(start_addr),
    //buff_start_addr,
    .indata(data_tbw),
    .indata_req_o(indata_req_o),
    .buff_valid(1'b1),
    .fail_check(fail_check),
    //User signals
    .clk(ap_clk), 
    .rstn(ap_rst_n)
);

localparam DW = 32;
localparam AW = 8;
localparam IDLE = 0;
localparam READ_P1 = 1;
localparam READ_P2 = 2;
localparam WRITE_P1 = 3;
localparam WRITE_P2 = 4;

reg ena_reg;
reg [AW-1:0] addra_reg;
reg wea_reg;
reg enb_reg;
reg [AW-1:0] addrb_reg;
wire [AXI_WIDTH_DA-1:0] dia;
wire [AXI_WIDTH_DA-1:0] dob;
reg [7:0] state;

assign dia = data_o;
assign data_tbw = dob;

dpram_wrapper #(
    .DW(AXI_WIDTH_DA),            // data bit-width per word
    .AW(AW),            // address bit-width
    .DEPTH(256),        // depth, word length
    .N_DELAY(1)
)
input_buffer (
    .clk(ap_clk),       // clock 
    .ena(ena_reg),      // enable for write address
    .addra(addra_reg),      // input address for write
    .wea(wea_reg),      // input write enable
    .enb(enb_reg),      // enable for read address
    .addrb(addrb_reg),      // input address for read
    .dia(dia),      // input write data
    .dob(dob)           // output read-out data
);

reg seq_state;
reg prev_o_ctrl_vsync_run;
reg prev_o_ctrl_hsync_run;
reg [7:0] line_count;
reg sync_start_flag;

always @(posedge ap_clk) begin
    if ((!prev_o_ctrl_vsync_run && o_ctrl_vsync_run) || (!prev_o_ctrl_hsync_run && o_ctrl_hsync_run)) begin
        sync_start_flag <= 1'b1;
    end
    prev_o_ctrl_vsync_run <= o_ctrl_vsync_run;
    prev_o_ctrl_hsync_run <= o_ctrl_hsync_run;
end

always @(posedge ap_clk) begin
    if (!ap_rst_n) begin
        ena_reg <= 1'b0;
        wea_reg <= 1'b0;
        enb_reg <= 1'b0;
        start_dma_input_read <= 1'b0;
        line_count <= 0;
        sync_start_flag <= 1'b0;
        ap_start <= 1'b0;
        start_addr <= -WIDTH;
        num_trans <= 0;
        seq_state <= 1'b0;
        img_reg <= 0;
        load_done <= 1'b0;
        state <= IDLE;
    end
    else begin
        case (state)
            IDLE: begin
                start_dma_input_read <= 1'b0;
                ap_start <= 1'b0;
                num_trans <= 64;
                seq_state <= 1'b0;
                line_count <= 0;
                load_done <= 1'b0;
                if (load_start) state <= READ_P1;
            end
            READ_P1: begin
                start_dma_input_read <= 1'b1;
                line_count <= line_count + 1;
                start_addr <= start_addr + WIDTH;
                ena_reg <= 1'b1;
                wea_reg <= 1'b1;
                state <= READ_P2;
                if (line_count == HEIGHT) begin
                    load_done <= 1'b1;
                    state <= IDLE;
                end
            end
            READ_P2: begin
                start_dma_input_read <= 1'b0;
                if (data_vld_o) begin
                    img_reg = (img_reg >> 16);
                    img_reg[8*WIDTH*HEIGHT-1-:16] = data_o;
                end
                if (done_o) begin
                    state <= READ_P1;
                end
            end
            WRITE_P1: begin
                ap_start <= 1'b1;
                start_addr <= 0;
                addrb_reg <= 0;
                enb_reg <= 1;
                state <= WRITE_P2;
            end
            WRITE_P2: begin
                ap_start <= 1'b0;
                if (indata_req_o) begin
                    seq_state <= 1'b1;
                end
                if (seq_state) begin
                    addrb_reg <= addrb_reg + 1;
                end
                if (ap_done) begin
                    state <= IDLE;
                end
            end
        endcase
    end
end

endmodule
