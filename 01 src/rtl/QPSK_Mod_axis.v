module QPSK_Mod_AXI_Stream(
    input         clk,                              // 全局时钟
    input         rst,                              // 异步复位（低有效）

    // AXI-Stream 输入接口（接收待调制数据）
    input         s_axis_tvalid,                    // 输入数据有效
    input  [5:0]  s_axis_tdata,                     // 输入数据（6位）
    input         s_axis_tlast,                     // 输入数据包结束
    // output  reg   s_axis_tready,                    // 输入就绪
    output        s_axis_tready,                    // 输入就绪
    input         s_bit_symb_last,

    // AXI-Stream 输出接口（发送调制后的复数数据）
    output        m_axis_tvalid,                    // 输出数据有效
    output [31:0] m_axis_tdata,                     // 输出数据（32位，高16位为Q，低16位为I）
    output        m_axis_tlast,                     // 输出数据包结束
    input         m_axis_tready,                    // 输出就绪
    output        m_bit_symb_last
);


// 定义内部寄存器
reg [1:0]  idata_reg;       // 锁存的输入数据（2位）
reg        data_valid; // 调制数据有效标志
reg        last_reg;
reg        symb_last_reg;

//-----------------------------
// 输入握手逻辑
//-----------------------------
assign s_axis_tready = m_axis_tready; // 输入就绪条件

// always @(posedge clk) begin
//     if (rst) begin
//         s_axis_tready <= #1 1'b0;
//     end 
//     else begin
//         s_axis_tready <= #1 m_axis_tready; 
//     end
// end

always @(posedge clk) begin
    if (rst) begin
        idata_reg <= #1 2'b00;
        last_reg <= #1 1'b0;
        symb_last_reg <= #1 1'b0;
    end else if (s_axis_tvalid && s_axis_tready) begin
        idata_reg <= #1 s_axis_tdata[1:0]; // 锁存输入数据
        last_reg  <= #1 s_axis_tlast;
        symb_last_reg <= #1 s_bit_symb_last;
    end
end

//-----------------------------
// 调制数据处理
//-----------------------------
wire [15:0] datout_Re = (idata_reg[0]) ? 16'h5A82 : 16'hA57E; // I分量
wire [15:0] datout_Im = (idata_reg[1]) ? 16'h5A82 : 16'hA57E; // Q分量

//-----------------------------
// 输出握手逻辑
//-----------------------------
assign m_axis_tvalid = data_valid;       // 输出数据有效
assign m_axis_tdata  = {datout_Im, datout_Re}; // 合并I/Q分量
assign m_axis_tlast = last_reg;
assign m_bit_symb_last = symb_last_reg;

always @(posedge clk) begin
    if (rst) begin
        data_valid <= #1 1'b0;
    end else begin
        if (s_axis_tvalid && s_axis_tready) begin
            data_valid <= #1 1'b1;            // 新数据到达，置位有效                 
        end 
        else if (m_axis_tvalid && m_axis_tready)begin
            data_valid <= #1 1'b0;            // 数据已发送，清除有效                        
        end
    end
end

endmodule