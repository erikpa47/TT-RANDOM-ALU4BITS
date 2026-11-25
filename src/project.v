/*
 * Copyright (c) 2026 Erik Paucar
 * SPDX-License-Identifier: Apache-2.0
 *
 * TT-RANDOM-ALU-4
 * 4-bit ALU + 4-bit LFSR + four-state controller.
 *
 * Interface:
 * ui_in[7:4] : ALU operand A
 * ui_in[3:0] : ALU operand B / LFSR seed
 *
 * uio_in[3:0]: ALU opcode
 * uio_in[4]  : mode (0 = ALU, 1 = LFSR)
 * uio_in[5]  : start transaction
 * uio_in[6]  : load LFSR seed during LOAD
 * uio_in[7]  : advance LFSR during EXECUTE
 *
 * uo_out[3:0]: ALU result or LFSR state
 * uo_out[4]  : Carry (ALU mode)
 * uo_out[5]  : Zero (ALU mode)
 * uo_out[7:6]: FSM state
 *
 * uio_out[0] : Overflow (ALU mode)
 * uio_out[1] : Negative (ALU mode)
 * uio_out[7:2]: reserved, driven low
 *
 * The bidirectional bus is driven only in DONE. During IDLE, LOAD,
 * and EXECUTE, the uio pins are inputs.
 */

`default_nettype none

module tt_um_random_alu_4 (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // Four-state FSM encoding.
    localparam [1:0] IDLE    = 2'b00;
    localparam [1:0] LOAD    = 2'b01;
    localparam [1:0] EXECUTE = 2'b10;
    localparam [1:0] DONE    = 2'b11;

    // ALU opcode encoding (uio_in[3:0]).
    localparam [3:0] OP_ADD = 4'b0000;
    localparam [3:0] OP_SUB = 4'b0001;
    localparam [3:0] OP_AND = 4'b0010;
    localparam [3:0] OP_OR  = 4'b0011;
    localparam [3:0] OP_XOR = 4'b0100;

    reg [1:0] state;
    reg [3:0] operand_a;
    reg [3:0] operand_b;
    reg [3:0] opcode_reg;
    reg       mode_lfsr;

    reg [3:0] result_reg;
    reg       carry_reg;
    reg       zero_reg;
    reg       negative_reg;
    reg       overflow_reg;

    reg [3:0] lfsr_state;
    wire      lfsr_feedback;

    reg [4:0] alu_temp;
    reg [3:0] alu_result_comb;
    reg       alu_carry_comb;
    reg       alu_overflow_comb;

    // Maximal-length 4-bit Fibonacci LFSR:
    // shift left, feedback = MSB XOR LSB.
    // This produces 15 non-zero states for any non-zero seed.
    assign lfsr_feedback = lfsr_state[3] ^ lfsr_state[0];

    // Combinational ALU.
    always @* begin
        alu_temp         = 5'b00000;
        alu_result_comb  = 4'b0000;
        alu_carry_comb   = 1'b0;
        alu_overflow_comb = 1'b0;

        case (opcode_reg)
            OP_ADD: begin
                alu_temp = {1'b0, operand_a} + {1'b0, operand_b};
                alu_result_comb = alu_temp[3:0];
                alu_carry_comb = alu_temp[4];
                alu_overflow_comb =
                    (~(operand_a[3] ^ operand_b[3])) &
                    (alu_result_comb[3] ^ operand_a[3]);
            end

            OP_SUB: begin
                alu_temp = {1'b0, operand_a} - {1'b0, operand_b};
                alu_result_comb = alu_temp[3:0];
                // Carry is defined as 1 when no borrow occurs.
                alu_carry_comb = (operand_a >= operand_b);
                alu_overflow_comb =
                    (operand_a[3] ^ operand_b[3]) &
                    (alu_result_comb[3] ^ operand_a[3]);
            end

            OP_AND: alu_result_comb = operand_a & operand_b;
            OP_OR : alu_result_comb = operand_a | operand_b;
            OP_XOR: alu_result_comb = operand_a ^ operand_b;

            default: alu_result_comb = 4'b0000;
        endcase
    end

    // Main controller, operand registers, ALU result registers and LFSR.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= IDLE;
            operand_a     <= 4'b0000;
            operand_b     <= 4'b0000;
            opcode_reg    <= OP_ADD;
            mode_lfsr     <= 1'b0;
            result_reg    <= 4'b0000;
            carry_reg     <= 1'b0;
            zero_reg      <= 1'b1;
            negative_reg  <= 1'b0;
            overflow_reg  <= 1'b0;
            lfsr_state    <= 4'b0001;
        end else if (ena) begin
            case (state)
                IDLE: begin
                    if (uio_in[5])
                        state <= LOAD;
                end

                LOAD: begin
                    operand_a  <= ui_in[7:4];
                    operand_b  <= ui_in[3:0];
                    opcode_reg <= uio_in[3:0];
                    mode_lfsr  <= uio_in[4];

                    // Load seed only when LFSR mode and seed_load are selected.
                    // Zero is replaced with 0001 to avoid the locked zero state.
                    if (uio_in[4] && uio_in[6]) begin
                        if (ui_in[3:0] == 4'b0000)
                            lfsr_state <= 4'b0001;
                        else
                            lfsr_state <= ui_in[3:0];
                    end

                    state <= EXECUTE;
                end

                EXECUTE: begin
                    if (mode_lfsr) begin
                        if (uio_in[7]) begin
                            // Register the next LFSR value as the transaction result.
                            result_reg <= {lfsr_state[2:0], lfsr_feedback};
                            lfsr_state <= {lfsr_state[2:0], lfsr_feedback};
                            zero_reg <= ({lfsr_state[2:0], lfsr_feedback} == 4'b0000);
                            negative_reg <= lfsr_state[2];
                        end else begin
                            // If STEP is low, report the current LFSR state.
                            result_reg <= lfsr_state;
                            zero_reg <= (lfsr_state == 4'b0000);
                            negative_reg <= lfsr_state[3];
                        end
                        carry_reg <= 1'b0;
                        overflow_reg <= 1'b0;
                    end else begin
                        result_reg   <= alu_result_comb;
                        carry_reg    <= alu_carry_comb;
                        zero_reg     <= (alu_result_comb == 4'b0000);
                        negative_reg <= alu_result_comb[3];
                        overflow_reg <= alu_overflow_comb;
                    end

                    state <= DONE;
                end

                DONE: begin
                    // DONE is a one-cycle result-valid state.
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Dedicated outputs.
    assign uo_out[3:0] = result_reg;
    assign uo_out[4]   = carry_reg;
    assign uo_out[5]   = zero_reg;
    assign uo_out[6]   = state[0];
    assign uo_out[7]   = state[1];

    // Bidirectional pins are inputs except during DONE, when they briefly
    // expose status information. This avoids driving against external inputs.
    assign uio_out = {6'b000000, negative_reg, overflow_reg};
    assign uio_oe  = (state == DONE) ? 8'hFF : 8'h00;

    // All top-level inputs are used; ena gates the sequential logic.
endmodule

`default_nettype wire
