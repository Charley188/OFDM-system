// 还可以的版本，暂时看起来都没问题了

module Pilots_Insert_AXI_Stream_3 #(
    parameter SYMBOL_POS      = 16'h7FFF,
    parameter SYMBOL_NEG      = 16'h8001
)(
    input  wire         clk,
    input  wire         rst,

    // AXI-Stream s_port
    input  wire         s_axis_tvalid,
    output wire         s_axis_tready,
    input  wire [31:0]  s_axis_tdata,
    input  wire         s_axis_tlast,
    input  wire         s_mod_symb_last,   

    // AXI-Stream m_port
    output reg          m_axis_tvalid,
    input  wire         m_axis_tready,
    output reg  [31:0]  m_axis_tdata=0,
    output reg          m_axis_tlast,
    output reg          m_axis_symb_tlast   
);


//-----------------------------------------------------------------
// rom IP pilot data
//-----------------------------------------------------------------
reg [2:0] pilot_cnt;
wire [0:0] dout_pilot;

rom_pilot inst_rom_pilot (
  .clka(clk),    // input wire clka
  .addra({4'd0,pilot_cnt}),  // input wire [6 : 0] addra
  .douta(dout_pilot)  // output wire [0 : 0] douta
);

//-----------------------------------------------------------------
// fifo IP
//-----------------------------------------------------------------

reg        fifo_axis_tvalid;
wire [31:0] fifo_axis_tdata;
wire        fifo_axis_tlast;
wire        fifo_axis_symb_tlast;
// reg        rd_en_1d;
wire [33:0] dout_data;
reg rd_en;
reg [6:0] data_cnt;

// 声明 full 和 empty 信号
wire full;
wire empty;

pilot_insert_fifo pilot_insert_fifo (
  .clk(clk),               // input wire clk
  .srst(rst),               // input wire rst
  .din({s_axis_tlast,s_mod_symb_last,s_axis_tdata}),      // input wire [33 : 0] din
  .wr_en(s_axis_tvalid),   // input wire wr_en
  .rd_en(rd_en),  // input wire rd_en
  .dout(dout_data),    // output wire [33 : 0] dout
  .full(full),    // output wire full
  .empty(empty)  // output wire empty
);


// always @(posedge clk)begin
//     if(rst)begin
//         fifo_axis_tvalid <= #1 1'd0;
//         fifo_axis_tlast <= #1 1'd0;
//         fifo_axis_tdata <= #1 32'd0;
//         rd_en_1d <= #1 1'd0;
//     end
//     else begin
//         fifo_axis_tvalid <= #1 rd_en_1d;
//         fifo_axis_tlast <= #1 dout_data[32];
//         fifo_axis_tdata <= #1 dout_data[31:0];
//         rd_en_1d <= #1 rd_en;
//     end
// end

always @(posedge clk)begin
    if(rst)begin
        fifo_axis_tvalid <= #1 1'd0;
    end
    else begin
        fifo_axis_tvalid <= #1 rd_en;
    end
end

assign #1 fifo_axis_tlast = dout_data[33];
assign #1 fifo_axis_symb_tlast = dout_data[32];
assign #1 fifo_axis_tdata = dout_data[31:0];
// assign fifo_axis_tvalid = rd_en;
assign #1 s_axis_tready = ~full && m_axis_tready;

//-----------------------------------------------------------------
// pilot_data
//-----------------------------------------------------------------
wire [15:0] pilot_re;
wire [31:0] pilot_data;

assign pilot_re = (dout_pilot) ? SYMBOL_NEG : SYMBOL_POS;
assign pilot_data = {16'h0000, pilot_re}; 

//-----------------------------------------------------------------
// three_stage_fsm logic
//-----------------------------------------------------------------

localparam IDLE  = 2'b00;
localparam NULL  = 2'b01;
localparam DATA  = 2'b10;
localparam PILOT = 2'b11;

reg [1:0] current_state;
reg [1:0] next_state ;

always @(posedge clk) begin
   if(rst)begin
       current_state <= #1 2'd0;
   end
   else begin
       current_state <= #1 next_state;
   end
end

wire NULL_FLAG;
assign NULL_FLAG = (data_cnt == 7'd0 || data_cnt == 7'd27) && m_axis_tready && (~empty);
assign DATA_FLAG = (data_cnt == 7'd1 || data_cnt == 7'd8 || data_cnt == 7'd22
     || data_cnt == 7'd38 || data_cnt == 7'd44 || data_cnt == 7'd58) && m_axis_tready && (~empty);
assign PILOT_FLAG = (data_cnt == 7'd7 || data_cnt == 7'd21 || data_cnt == 7'd43
     || data_cnt == 7'd57) && m_axis_tready;

always@(*) begin
    case (current_state)
        IDLE: begin
            if(NULL_FLAG)
                next_state = NULL;
            else if(DATA_FLAG)
                next_state = DATA;
            else if(PILOT_FLAG)
                next_state = PILOT;
            else 
                next_state = IDLE;
        end
        NULL: begin
            if(DATA_FLAG)
                next_state = DATA;
            else if(PILOT_FLAG)
                next_state = PILOT;
            else 
                next_state = NULL;
        end
        DATA: begin
            if(PILOT_FLAG)
                next_state = PILOT;
            else if(NULL_FLAG)
                next_state = NULL;
            else if(DATA_FLAG)
                next_state = DATA;
            else if(fifo_axis_symb_tlast && fifo_axis_tvalid)
                next_state = IDLE;
        end
        PILOT: begin
            if(DATA_FLAG)
                next_state = DATA;
            else if(NULL_FLAG)
                next_state = NULL;
            else 
                next_state = PILOT;
        end
        default: begin
            next_state = IDLE;
        end
    endcase // current_state
end

always @(posedge clk) begin
    if(rst)begin
        data_cnt <= #1 7'd0;
        // rd_en <= #1 1'd0;
        pilot_cnt <= #1 3'd0;
    end
    else begin
        case (next_state)
            IDLE:begin
                data_cnt <= #1 7'd0;
                // rd_en <= #1 1'd0;
            end
            NULL:begin
                if(m_axis_tready)begin
                    data_cnt <= #1 data_cnt + 1'd1;
                    // rd_en <= #1 1'd0;
                end
            end
            DATA: begin
                if(data_cnt == 7'd64)
                    data_cnt <= #1 7'd0;
                else if(m_axis_tready && (~empty))begin
                    data_cnt <= #1 data_cnt + 1'd1;
                    // rd_en <= #1 1'd1;
                end
                if(fifo_axis_tlast && fifo_axis_tvalid)
                    pilot_cnt <= #1 3'd0;
            end
            PILOT: begin
                if(m_axis_tready)begin
                    data_cnt <= #1 data_cnt + 1'd1;
                    pilot_cnt <= #1 pilot_cnt + 1'd1;
                    // rd_en <= #1 1'd0;
                end
            end
            default:begin
                data_cnt <= #1 7'd0;
                pilot_cnt <= #1 3'd0;
                // rd_en <= #1 1'd0;
            end
        endcase

//-----------------------------------------------------------------
// frame factor logic
//-----------------------------------------------------------------

        case (current_state)
            IDLE:begin
                m_axis_tdata <= #1 32'd0;
                m_axis_tvalid <= #1 1'd0;
                m_axis_tlast <= #1 1'd0;
                m_axis_symb_tlast <= #1 1'd0;
            end
            NULL:begin
                m_axis_tdata <= #1 32'd0;
                m_axis_tvalid <= #1 1'd1;
                m_axis_tlast <= #1 1'd0;
                m_axis_symb_tlast <= #1 1'd0;
            end
            DATA: begin
                m_axis_tdata <= #1 fifo_axis_tdata;
                m_axis_tvalid <= #1 fifo_axis_tvalid;
                m_axis_tlast <= #1 fifo_axis_tlast;
                m_axis_symb_tlast <= #1 fifo_axis_symb_tlast;
            end
            PILOT: begin
                m_axis_tdata <= #1 pilot_data;
                m_axis_tvalid <= #1 1'd1;
                m_axis_tlast <= #1 1'd0;
                m_axis_symb_tlast <= #1 1'd0;
            end
            default:begin
                m_axis_tdata <= #1 32'd0;
                m_axis_tvalid <= #1 1'd0;
                m_axis_tlast <= #1 1'd0;
                m_axis_symb_tlast <= #1 1'd0;
            end
        endcase
    end
 end

assign rd_en = (next_state == DATA) && (m_axis_tready);

 endmodule