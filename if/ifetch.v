`include "../mem/DP_mem32x64k.v"

module ifetch(clk,
              rst,
              branch_i,
              branch_addr_i,
              stall_i,
              inst_o,
              inst_addr_o
              );

  parameter ADDR = 16;
  parameter WORD = 32;
  
  input           clk;            // clock
  input           rst;            // reset
  input           branch_i;       // branch input (if H then branch)
  input [ADDR-1:0]  branch_addr_i;  // branch address
  input           stall_i;        // stall input (if H then stall)
  output [WORD-1:0] inst_o;         // instruction to the next stage
  output [ADDR-1:0] inst_addr_o;    // instruction addr to memory


  // program counter
  reg [ADDR-1:0] pc;
  wire [ADDR-1:0] pc_plus1;
  wire [ADDR-1:0] next_pc;
  reg [WORD-1:0] inst_r;
  reg [ADDR-1:0] inst_addr_buf_r;
  reg [ADDR-1:0] inst_addr_r;
  wire [WORD-1:0] Q_DP_mem32x64k;

  assign pc_plus1 = pc + 16'h0001;
  assign next_pc = branch_i ? branch_addr_i : pc_plus1;

  // connect pipeline registers to output
  assign inst_addr_o = inst_addr_r;
  assign inst_o = inst_r;

  DP_mem32x64k inst_mem (
    .clk(clk),
    .A(pc),
    .W(1'b0),
    .D(),
    .Q(Q_DP_mem32x64k)
  );

  always @(posedge clk or negedge rst) begin
    if (~rst) begin
      pc <= 16'h0000;
      inst_addr_buf_r <= 16'h0;
      inst_addr_r <= 16'h0;
      inst_r <= 32'h3C00_0000;   // set NOP
    end // if (~rst)
    else
      if (stall_i) begin
        pc <= pc;
        inst_addr_buf_r <= 16'h0;
        inst_addr_r <= 16'h0;
        inst_r <= 32'h3C00_0000;   // send NOP
      end // if (stall_i)
      else begin
        pc <= next_pc;
        inst_addr_buf_r <= pc;
        inst_addr_r <= inst_addr_buf_r;
        inst_r <= Q_DP_mem32x64k;
      end
  end // always @(posedge clk or negedge rst)


endmodule // if
