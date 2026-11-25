<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

TT-RANDOM-ALU-4 is a compact digital system implemented in Verilog that integrates a 4-bit Arithmetic Logic Unit (ALU), a 4-bit Linear Feedback Shift Register (LFSR) pseudo-random number generator, and a 4-state Finite State Machine (FSM).

The ALU performs basic arithmetic and logical operations, including addition, subtraction, AND, OR, and XOR. It generates a 4-bit result along with status flags such as Carry, Zero, Negative, and Overflow.

The LFSR generates pseudo-random binary sequences using XOR feedback and a non-zero initial seed. It can produce up to 15 different non-zero states before repeating.

The FSM controls the system operation through four states: IDLE, LOAD, EXECUTE, and DONE. It coordinates data loading, operation execution, and result availability.

The design uses the standard Tiny Tapeout interface, with 8 dedicated inputs, 8 dedicated outputs, and 8 bidirectional pins for data communication and control.

## How to test

The design can be tested through Verilog simulation and the Tiny Tapeout demonstration board.

For the ALU, apply two 4-bit operands and select an arithmetic or logical operation. Verify the output result and status flags.

For the LFSR, load a non-zero seed, enable the generator, and apply clock pulses to observe the pseudo-random sequence. Verify that it generates the expected 15 non-zero states.

For the FSM, verify the transitions between IDLE, LOAD, EXECUTE, and DONE using a simulation waveform viewer such as GTKWave.

Finally, test the complete system by checking operation selection, output values, reset behavior, and bidirectional pin functionality.

## External hardware

No external hardware is required for the core digital functionality.

For physical testing, the Tiny Tapeout demonstration board can be used together with DIP switches, LEDs, a clock source, and a logic analyzer to interact with the chip and observe its digital signals.

The design can also be simulated using Verilog-compatible tools and the Wokwi custom-chip environment.
