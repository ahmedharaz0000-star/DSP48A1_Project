`timescale 1ns / 1ps
module DSP48A1 #(
    // ---------------- Parameters -----------------
    parameter A0REG = 0,
    parameter A1REG = 1,
    parameter B0REG = 0,
    parameter B1REG = 1,
    parameter CREG = 1,
    parameter DREG = 1,
    parameter MREG = 1,
    parameter PREG = 1,
    parameter CARRYINREG = 1,
    parameter CARRYOUTREG = 1,
    parameter OPMODEREG = 1,
    parameter CARRYINSEL = "OPMODE5",
    parameter B_INPUT = "DIRECT",
    parameter RSTTYPE = "SYNC"
) (
    // ---------------- Data Inputs ----------------
    input wire [17:0] A,
    input wire [17:0] B,
    input wire [17:0] D,
    input wire [47:0] C,
    // -------------- Cascade Inputs ---------------
    input wire [17:0] BCIN,
    input wire [47:0] PCIN,
    input wire CARRYIN,
    // ------------- Control Inputs ----------------
    input wire [7:0] OPMODE,
    input wire CLK,
    // ----------- Clock Enable Inputs -------------
    input wire CEA, CEB, CEC, CECARRYIN, CED, CEM, CEOPMODE, CEP,
    // --------------- Reset Inputs ----------------
    input wire RSTA, RSTB, RSTC, RSTCARRYIN, RSTD, RSTM, RSTOPMODE, RSTP,
    // ---------------- Data Outputs ---------------
    output wire [17:0] BCOUT,
    output wire [47:0] PCOUT, P,
    output wire [35:0] M,
    output wire CARRYOUT, CARRYOUTF
);
// Internal Signals & Wires
wire [17:0] b_mux_out = (B_INPUT == "CASCADE") ? BCIN : B;
reg [17:0] d_reg_out, b0_reg_out, a0_reg_out;
reg [47:0] c_reg_out;
reg [7:0] opmode_reg_out;
reg [17:0] b1_reg_out, a1_reg_out;
reg [35:0] m_reg_out;
reg [47:0] p_reg_out;
reg cyi_reg_out, cyo_reg_out;
wire [17:0] pre_adder_out;
wire [17:0] b1_mux_in;
wire [35:0] mult_out;
wire [47:0] c_mux_out;
reg [47:0] x_mux_out, z_mux_out;
wire post_adder_cin, post_adder_cout;
wire [47:0] post_adder_out;

// Stage 1: Initial Pipeline Registers (A0, B0, D, C, OPMODE)

always @(posedge CLK or posedge RSTA) begin
    if (RSTA && RSTTYPE == "ASYNC") a0_reg_out <= 18'b0;
    else if (RSTA && RSTTYPE == "SYNC") a0_reg_out <= 18'b0;
    else if (CEA) a0_reg_out <= A;
end
wire [17:0] a0_mux_out = A0REG ? a0_reg_out : A;

always @(posedge CLK or posedge RSTB) begin
    if (RSTB && RSTTYPE == "ASYNC") b0_reg_out <= 18'b0;
    else if (RSTB && RSTTYPE == "SYNC") b0_reg_out <= 18'b0;
    else if (CEB) b0_reg_out <= b_mux_out;
end
wire [17:0] b0_mux_out = B0REG ? b0_reg_out : b_mux_out;

always @(posedge CLK or posedge RSTD) begin
    if (RSTD && RSTTYPE == "ASYNC") d_reg_out <= 18'b0;
    else if (RSTD && RSTTYPE == "SYNC") d_reg_out <= 18'b0;
    else if (CED) d_reg_out <= D;
end
wire [17:0] d_mux_out = DREG ? d_reg_out : D;

always @(posedge CLK or posedge RSTC) begin
    if (RSTC && RSTTYPE == "ASYNC") c_reg_out <= 48'b0;
    else if (RSTC && RSTTYPE == "SYNC") c_reg_out <= 48'b0;
    else if (CEC) c_reg_out <= C;
end
assign c_mux_out = CREG ? c_reg_out : C;

always @(posedge CLK or posedge RSTOPMODE) begin
    if (RSTOPMODE && RSTTYPE == "ASYNC") opmode_reg_out <= 8'b0;
    else if (RSTOPMODE && RSTTYPE == "SYNC") opmode_reg_out <= 8'b0;
    else if (CEOPMODE) opmode_reg_out <= OPMODE;
end
wire [7:0] op_mux_out = OPMODEREG ? opmode_reg_out : OPMODE;

// Pre-Adder / Subtracter & Stage 2 Registers (A1, B1)
assign pre_adder_out = op_mux_out[6] ? (d_mux_out - b0_mux_out) : (d_mux_out + b0_mux_out);
assign b1_mux_in = op_mux_out[4] ? pre_adder_out : b0_mux_out;

always @(posedge CLK or posedge RSTA) begin
    if (RSTA && RSTTYPE == "ASYNC") a1_reg_out <= 18'b0;
    else if (RSTA && RSTTYPE == "SYNC") a1_reg_out <= 18'b0;
    else if (CEA) a1_reg_out <= a0_mux_out;
end
wire [17:0] a1_mux_out = A1REG ? a1_reg_out : a0_mux_out;

always @(posedge CLK or posedge RSTB) begin
    if (RSTB && RSTTYPE == "ASYNC") b1_reg_out <= 18'b0;
    else if (RSTB && RSTTYPE == "SYNC") b1_reg_out <= 18'b0;
    else if (CEB) b1_reg_out <= b1_mux_in;
end
wire [17:0] b1_mux_out = B1REG ? b1_reg_out : b1_mux_in;

// Multiplier & M Register
assign mult_out = a1_mux_out * b1_mux_out;

always @(posedge CLK or posedge RSTM) begin
    if (RSTM && RSTTYPE == "ASYNC") m_reg_out <= 36'b0;
    else if (RSTM && RSTTYPE == "SYNC") m_reg_out <= 36'b0;
    else if (CEM) m_reg_out <= mult_out;
end
wire [35:0] m_mux_out = MREG ? m_reg_out : mult_out;
assign M = m_mux_out;

// 48-bit X and Z Multiplexers

wire [47:0] concat_dab = {d_mux_out[11:0], a1_mux_out[17:0], b1_mux_out[17:0]};

always @(*) begin
    case (op_mux_out[1:0])
        2'b00: x_mux_out = 48'b0;
        2'b01: x_mux_out = {12'b0, m_mux_out};
        2'b10: x_mux_out = P;
        2'b11: x_mux_out = concat_dab;
        default: x_mux_out = 48'b0;
    endcase
end

always @(*) begin
    case (op_mux_out[3:2])
        2'b00: z_mux_out = 48'b0;
        2'b01: z_mux_out = PCIN;
        2'b10: z_mux_out = P;
        2'b11: z_mux_out = c_mux_out;
        default: z_mux_out = 48'b0;
    endcase
end

// Carry-In Logic (CYI)
wire cin_mux_out = (CARRYINSEL == "OPMODE5") ? op_mux_out[5] : CARRYIN;

always @(posedge CLK or posedge RSTCARRYIN) begin
    if (RSTCARRYIN && RSTTYPE == "ASYNC") cyi_reg_out <= 1'b0;
    else if (RSTCARRYIN && RSTTYPE == "SYNC") cyi_reg_out <= 1'b0;
    else if (CECARRYIN) cyi_reg_out <= cin_mux_out;
end
assign post_adder_cin = CARRYINREG ? cyi_reg_out : cin_mux_out;


// Post-Adder / Subtracter & P / Carry-Out Registers
assign {post_adder_cout, post_adder_out} = op_mux_out[7] ?
                                            (z_mux_out - (x_mux_out + post_adder_cin)) :
                                            (z_mux_out + x_mux_out + post_adder_cin);

always @(posedge CLK or posedge RSTP) begin
    if (RSTP && RSTTYPE == "ASYNC") p_reg_out <= 48'b0;
    else if (RSTP && RSTTYPE == "SYNC") p_reg_out <= 48'b0;
    else if (CEP) p_reg_out <= post_adder_out;
end
wire [47:0] p_final = PREG ? p_reg_out : post_adder_out;

always @(posedge CLK or posedge RSTCARRYIN) begin
    if (RSTCARRYIN && RSTTYPE == "ASYNC") cyo_reg_out <= 1'b0;
    else if (RSTCARRYIN && RSTTYPE == "SYNC") cyo_reg_out <= 1'b0;
    else if (CECARRYIN) cyo_reg_out <= post_adder_cout;
end
wire carry_final = CARRYOUTREG ? cyo_reg_out : post_adder_cout;

// Output Assignments

assign P = p_final;
assign PCOUT = p_final;
assign BCOUT = b1_mux_out;
assign CARRYOUT = carry_final;
assign CARRYOUTF = carry_final;

endmodule
