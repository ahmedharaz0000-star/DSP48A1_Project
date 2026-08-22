`timescale 1ns / 1ps
module tb_DSP48A1;

// Signals & Testbench Variables

reg [17:0] A, B, D, BCIN;
reg [47:0] C, PCIN;
reg CARRYIN, CLK;
reg [7:0] OPMODE;
reg CEA, CEB, CEC, CECARRYIN, CED, CEM, CEOPMODE, CEP;
reg RSTA, RSTB, RSTC, RSTCARRYIN, RSTD, RSTM, RSTOPMODE, RSTP;

wire [17:0] BCOUT;
wire [47:0] PCOUT, P;
wire [35:0] M;
wire CARRYOUT, CARRYOUTF;

// Variables to store past values for Path 3 checking
reg [47:0] past_P;
reg past_CARRYOUT;

// Device Under Test (DUT) Instantiation
// Instantiated with default parameters as specified
DSP48A1 #(
    .A0REG(0), .A1REG(1), .B0REG(0), .B1REG(1),
    .CREG(1), .DREG(1), .MREG(1), .PREG(1),
    .CARRYINREG(1), .CARRYOUTREG(1), .OPMODEREG(1),
    .CARRYINSEL("OPMODE5"), .B_INPUT("DIRECT"), .RSTTYPE("SYNC")
) uut (
    .A(A), .B(B), .D(D), .C(C),
    .BCIN(BCIN), .PCIN(PCIN), .CARRYIN(CARRYIN),
    .OPMODE(OPMODE), .CLK(CLK),
    .CEA(CEA), .CEB(CEB), .CEC(CEC), .CECARRYIN(CECARRYIN),
    .CED(CED), .CEM(CEM), .CEOPMODE(CEOPMODE), .CEP(CEP),
    .RSTA(RSTA), .RSTB(RSTB), .RSTC(RSTC), .RSTCARRYIN(RSTCARRYIN),
    .RSTD(RSTD), .RSTM(RSTM), .RSTOPMODE(RSTOPMODE), .RSTP(RSTP),
    .BCOUT(BCOUT), .PCOUT(PCOUT), .P(P), .M(M),
    .CARRYOUT(CARRYOUT), .CARRYOUTF(CARRYOUTF));

// Clock Generation
initial CLK = 0;
always #5 CLK = ~CLK; // 100MHz clock

// Stimulus Generation (Initial Block)
initial begin
    // Initialize Inputs
    A = 0; B = 0; C = 0; D = 0;
    BCIN = 0; PCIN = 0; CARRYIN = 0; OPMODE = 0;
    CEA = 0; CEB = 0; CEC = 0; CECARRYIN = 0; CED = 0; CEM = 0; CEOPMODE = 0; CEP = 0;
    RSTA = 0; RSTB = 0; RSTC = 0; RSTCARRYIN = 0; RSTD = 0; RSTM = 0; RSTOPMODE = 0; RSTP = 0;


    // Step 2.1: Verify Reset Operation
    $display("Starting Step 2.1: Verify Reset Operation");

    // Assert all active-high resets
    RSTA = 1; RSTB = 1; RSTC = 1; RSTCARRYIN = 1;
    RSTD = 1; RSTM = 1; RSTOPMODE = 1; RSTP = 1;

    // Drive remaining inputs with arbitrary values
    A = $random; B = $random; C = $random; D = $random;

    // Wait for the negative edge of the clock
    @(negedge CLK);

    // Self-checking condition to verify outputs are zero
    if (BCOUT === 0 && PCOUT === 0 && P === 0 && M === 0 && CARRYOUT === 0 && CARRYOUTF === 0)
        $display("-> PASS: Reset successful. All outputs are zero.");
    else
        $display("-> FAIL: Outputs are not zero after reset.");

    // Deassert resets and assert clock enables
    RSTA = 0; RSTB = 0; RSTC = 0; RSTCARRYIN = 0;
    RSTD = 0; RSTM = 0; RSTOPMODE = 0; RSTP = 0;
    CEA = 1; CEB = 1; CEC = 1; CECARRYIN = 1;
    CED = 1; CEM = 1; CEOPMODE = 1; CEP = 1;

    
    // Step 2.2: Verify DSP Path 1
    
    $display("Starting Step 2.2: Verify DSP Path 1");
    OPMODE = 8'b11011101;
    A = 20; B = 10; C = 350; D = 25;
    BCIN = $random; PCIN = $random; CARRYIN = $random;

    // Wait for four negative clock edges
    repeat(4) @(negedge CLK);

    if (BCOUT === 18'hf && M === 36'h12c && P === 48'h32 && PCOUT === 48'h32
        && CARRYOUT === 0 && CARRYOUTF === 0)
        $display("-> PASS: Path 1 outputs match expected values.");
    else
        $display("-> FAIL: Path 1 outputs incorrect. P=%h", P);

    
    // Step 2.3: Verify DSP Path 2
    
    $display("Starting Step 2.3: Verify DSP Path 2");
    OPMODE = 8'b00010000;
    A = 20; B = 10; C = 350; D = 25;
    BCIN = $random; PCIN = $random; CARRYIN = $random;

    // Wait for three negative clock edges
    repeat(3) @(negedge CLK);

    if (BCOUT === 18'h23 && M === 36'h2bc && P === 0 && PCOUT === 0
        && CARRYOUT === 0 && CARRYOUTF === 0)
        $display("-> PASS: Path 2 outputs match expected values.");
    else
        $display("-> FAIL: Path 2 outputs incorrect. P=%h, M=%h", P, M);

    // Store past values for Path 3 verification
    past_P = P;
    past_CARRYOUT = CARRYOUT;

    // Step 2.4: Verify DSP Path 3
    $display("Starting Step 2.4: Verify DSP Path 3");
    OPMODE = 8'b00001010;
    A = 20; B = 10; C = 350; D = 25;
    BCIN = $random; PCIN = $random; CARRYIN = $random;

    // Wait for three negative clock edges
    repeat(3) @(negedge CLK);

    if (BCOUT === 18'ha && M === 36'hc8 && P === past_P && PCOUT === past_P
        && CARRYOUT === past_CARRYOUT && CARRYOUTF === past_CARRYOUT)
        $display("-> PASS: Path 3 outputs match expected values (Feedback retained).");
    else
        $display("-> FAIL: Path 3 outputs incorrect.");


    // Step 2.5: Verify DSP Path 4
    $display("Starting Step 2.5: Verify DSP Path 4");
    OPMODE = 8'b10100111;
    A = 5; B = 6; C = 350; D = 25; PCIN = 3000;
    BCIN = $random; CARRYIN = $random;

    // Wait for three negative clock edges
    repeat(3) @(negedge CLK);

    if (BCOUT === 18'h6 && M === 36'h1e && P === 48'hfe6fffec0bb1 && PCOUT === 48'hfe6fffec0bb1
        && CARRYOUT === 1 && CARRYOUTF === 1)
        $display("-> PASS: Path 4 outputs match expected values.");
    else
        $display("-> FAIL: Path 4 outputs incorrect. P=%h", P);

    // End Simulation
    $display("Simulation Complete.");
    $finish;
end

endmodule
