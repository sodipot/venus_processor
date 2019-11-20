`include "../reg/g_register.v"

module ID (
  clk,
  rst,
  inst_i,
  rd_value_o,
  rs_value_o,
  imm_value_o,
  immf_o,
  stall_i,
  stall_o,
  ctrl_inte_o,
  ctrl_logic_o,
  ctrl_shift_o,
  ctrl_ld_o,
  ctrl_st_o,
  ctrl_br_o,
  wb_r_i,
  wb_i,
  wb_data_i
);

  parameter W_DOPC  = 9;    // decoded opecode width
  parameter W_INST  = 32;   // instruction width
  parameter P_RD    = 20;   // position of register
  parameter W_OPC   = 7;    // opecode width

  input clk, rst;           // clock and reset
  input [31:0] inst_i;      // instruction
  input wb_i;               // write-back flag from the WB stage (1: WB enable)
  input [3:0] wb_r_i;       // write-back target register address
  input [31:0] wb_data_i;   // write-back data

  // control bits (1: use this module)
  output ctrl_inte_o;       // control (integer)
  output ctrl_logic_o;      // control (logic)
  output ctrl_shift_o;      // control (shift)
  output ctrl_ld_o;         // control (load)
  output ctrl_st_o;         // control (store)
  output ctrl_br_o;         // control (branch)
  output immf_o;            // immediate flag (1: use immediate)

  // stall flag
  output stall_o;
  input  stall_i;           // stall from next stage (1: stall)

  // data output
  output [31:0] rd_value_o; // value of destination register
  output [31:0] rs_value_o; // value of source register (may not be unused)
  output [31:0] imm_value_o;  // value of immediate

  wire [W_DOPC-1:0] dopc; // decoded opecode

  assign dopc    = decode_ins(inst_i[W_INST-1:W_INST-W_OPC]);

  assign inte    = dopc[W_DOPC-1]; // integer
  assign logic   = dopc[W_DOPC-2]; // logic
  assign shift   = dopc[W_DOPC-3]; // shift
  assign ld      = dopc[W_DOPC-4]; // load
  assign st      = dopc[W_DOPC-5]; // store
  assign br      = dopc[W_DOPC-6]; // branch
  assign imme16  = dopc[W_DOPC-7]; // immediate 16
  assign rsv_o   = dopc[W_DOPC-8]; // reserve
  assign und     = dopc[W_DOPC-9]; // undefined

  // **************** decode opecode *****************
    // dopc = {inte, logic, shift, ls, br, imm16, rsv, und}
    // integer, logic, shift, load, store, branch, immediate, reserved, undefined
    function [W_DOPC -1: 0] decode_ins;
      input [6: 0] opcode;
      case (opcode) // synopsys parallel_case
        // integer reg - reg
        7'b0000_000: decode_ins = 9'b100000_0_1_0;
        7'b0000_001: decode_ins = 9'b100000_0_1_0;
        7'b0000_010: decode_ins = 9'b100000_0_1_0;
        7'b0000_011: decode_ins = 9'b100000_0_1_0;
        7'b0000_100: decode_ins = 9'b100000_0_0_0;
        7'b0000_101: decode_ins = 9'b100000_0_1_0;
        7'b0000_110: decode_ins = 9'b100000_0_1_0;
        7'b0000_111: decode_ins = 9'b100000_0_1_0;

        // shift reg - reg
        7'b000_1000: decode_ins = 9'b001000_1_1_0;
        7'b000_1001: decode_ins = 9'b001000_1_1_0;
        7'b000_1010: decode_ins = 9'b001000_1_1_0;
        7'b000_1100: decode_ins = 9'b001000_1_1_0;
        7'b000_1101: decode_ins = 9'b001000_1_1_0;
        
        // logic reg - reg
        7'b00_10000: decode_ins = 9'b010000_0_1_0;
        7'b00_10001: decode_ins = 9'b010000_0_1_0;
        7'b00_10010: decode_ins = 9'b010000_0_1_0;
        7'b00_10011: decode_ins = 9'b010000_0_1_0;

        // set reg - reg
        7'b00_10110: decode_ins = 9'b000000_0_1_0;
        7'b00_10111: decode_ins = 9'b000000_0_1_0;

        // load
        7'b00_11000: decode_ins = 9'b000100_0_1_0;

        // store
        7'b00_11001: decode_ins = 9'b000010_0_1_0;

        // branch
        7'b00_11100: decode_ins = 9'b000001_0_1_0;
        7'b00_11101: decode_ins = 9'b000001_0_1_0;
        7'b00_11110: decode_ins = 9'b000001_0_1_0;
        7'b00_11111: decode_ins = 9'b000001_0_1_0;

        default:     decode_ins = 9'b000000_0_0_1;
      endcase
    endfunction

  // **************** decode register *****************
  wire [3:0] rd_addr;
  wire [3:0] rs_addr;
  wire reserved_o_register;
  assign rd_addr = inst_i[23:20];
  assign rs_addr = inst_i[19:16];
  
  g_register register (
    .clk(clk),
    .rst(rst),
    .w_reserve_i(rsv_o),
    .r0_i(rd_addr),
    .r1_i(rs_addr),
    .r_opr0_o(rd_value_o),
    .r_opr1_o(rs_value_o),
    .reserved_o(reserved_o_register),
    .wb_i(wb_i),
    .wb_r_i(wb_r_i),
    .result_i(wb_data_i)
  );


  // *************** stall logic ********************
  assign stall_o = stall_i | reserved_o_register | und;

  // **************** decode immediate ****************
  `include "../id/SignEx.v" 
  wire [31:0] dimm; // decoded immediate
  assign dimm = extend_sign(~imme16, inst_i[15:0]);

  // *************** pipeline register ***************
  reg ctrl_inte_r;
  reg ctrl_logic_r;
  reg ctrl_shift_r;
  reg ctrl_ld_r;
  reg ctrl_st_r;
  reg ctrl_br_r;
  reg immf_r;
  reg [31:0] imm_r;

  assign ctrl_inte_o  = ctrl_inte_r;
  assign ctrl_logic_o = ctrl_logic_r;
  assign ctrl_shift_o = ctrl_shift_r;
  assign ctrl_ld_o    = ctrl_ld_r;
  assign ctrl_st_o    = ctrl_st_r;
  assign ctrl_br_o    = ctrl_br_r;
  assign immf_o       = immf_r;
  assign imm_value_o  = imm_r;

  always @(posedge clk or negedge rst) begin
    if (~rst) begin
      ctrl_inte_r  <= 1'b0;
      ctrl_logic_r <= 1'b0;
      ctrl_shift_r <= 1'b0;
      ctrl_ld_r    <= 1'b0;
      ctrl_st_r    <= 1'b0;
      ctrl_br_r    <= 1'b0;
      immf_r       <= 1'b0;
      imm_r        <= 32'b0;
    end
    else if (stall_o) begin
      ctrl_inte_r  <= ctrl_inte_r;
      ctrl_logic_r <= ctrl_logic_r;
      ctrl_shift_r <= ctrl_shift_r;
      ctrl_ld_r    <= ctrl_ld_r;
      ctrl_st_r    <= ctrl_st_r;
      ctrl_br_r    <= ctrl_br_r;
      immf_r       <= immf_r;
      imm_r        <= imm_r;
    end
    else begin
      ctrl_inte_r  <= inte;
      ctrl_logic_r <= logic;
      ctrl_shift_r <= shift;
      ctrl_ld_r    <= ld;
      ctrl_st_r    <= st;
      ctrl_br_r    <= br;
      immf_r       <= inst_i[24];
      imm_r        <= dimm;
    end
  end

endmodule
