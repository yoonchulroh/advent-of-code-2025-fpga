# advent-of-code-2025-fpga
This repository contains a Verilog implementation for Advent of Code 2025, Day 10 Part 2. Designed for FPGA acceleration, this solution significantly outperforms CPU-based implementations in both execution time and power efficiency. 

## The problem
This design solves Part 2 of Day 10 in Advent of Code 2025. In summary, there are buttons that increase the "joltage" levels of the designated machines by 1. The goal is to find the minimum number of total button presses for reaching the given "joltage" targets, for all machines. Each button may be designated to multiple machines. Each button can be pressed multiple times, and each button press increases the "joltage" levels of all designated machines by 1.

Each line in the input tells which button is assigned to which machines, and what the "joltage" targets are. The ultimate goal is to find the sum of the minimum button presses for each line of input.
```
(3,6) (1,3,5,6,7,8,9) (0,4,9) (8) (0,1,2,3,4,5,6,7,8,9) (0) (5) (6,8) (1,3,4,6,8) (7,8,9) (1,3,5,8) (2,6,7,8) (2,4,5,7,8) {28,34,17,41,27,32,50,31,65,28}
```

The original problem description can be found in https://adventofcode.com/2025/day/10, after solving Part 1.

Part 1 defines the target as the XOR result of button presses. This repository focuses exclusively on Part 2, as Part 1 is computationally trivial for CPUs, whereas I/O throughput would bottleneck the speedup from an FPGA implementation.

## The algorithm

See `How-it-works.md` for a detailed description of the implementation.

This solution uses algorithm suggested by u/tenthmascot and improved by u/DataMn, posted on r/adventofcode on Reddit.
Check https://www.reddit.com/r/adventofcode/comments/1pk87hl/2025_day_10_part_2_bifurcate_your_way_to_victory/ for the original algorithm.

This project implements this algorithm with Verilog so that it could be run on FPGAs, for significantly reduced execution time. The original algorithm was implemented using Python to be run on CPUs.

## Providing the Input and Interpreting the Output

This solution reads the input from `data/input.txt`. Delete the contents of the file and paste your inputs for Day 10.

The file currently contains a custom-generated demo input. In compliance with Advent of Code policies regarding input redistribution, the provided `data/input.txt` contains a custom-generated demo dataset that mimics the structure of official inputs. It follows the same principles, but you may find some differences if you look closely. The correct answer for the demo input is 24549.

For each line of input, this solution outputs the sum of the minimum number of button presses for each line, since reset. Therefore, you only need to check the last output to find the correct answer. The program automatically quits after finding the minimum button presses for all lines in the input. If you need to find the answer for another input set, assert reset to set the current sum back to 0.

*Note*: This solution contains multiple units that solves each line of input in parallel and Out-of-Order. The intermediate partial sums may be printed without following the order in the input file, but the final result is consistent. 

## Setting the Parameters (Optional for Verilator Simulation)

This solution contains multiple parameters that depend on the properties of the input and the targeted FPGA. For official inputs and Verilator simulation, the default parameters are sufficient. If you want to give it modified inputs, or use your own FPGA to run the modules, you may need to change the parameters for correct operation.

The parameters in this solution are:
1) BAUD_RATE: This solution uses UART with 8N1 configuration for IO. This parameter sets the BAUD rate for UART. It is currently set to 5 million. If you need to use some other BAUD rate, change this parameter.
2) CLK_FREQUENCY: The clock frequency of the module. It is currently set to 100MHz. If you run the module on a FPGA with some other clock frequency, change this parameter.
3) MACHINE_COUNT: The maximum number of machines to target in each line. It is currently set to 10.
4) BITS_PER_JOLTAGE: The number of bits needed to represent the "joltage" target for each machine, in unsigned binary format. Since no target exceeded `2^9 - 1` in the official input, I set it to 9.
5) ANSWER_BIT_WIDTH: The number of bits needed to represent the answer (total number of button presses). It is currently set to 24. 24 bits provide sufficient range for the solution space of this problem. 
6) STACK_SIZE: The number of entries on the stack for solving each line of input. It is currently set to 10. It has to be larger than BITS_PER_JOLTAGE.
7) LSU_COUNT: LSUs (line solving unit) are units that independently find the minimum button presses for each line. It is recommended to have as many LSUs as your FPGA allows, because more LSUs reduce execution time. As a reference, each LSU utilizes approximately 3000 LUTs on an AMD Spartan-7 FPGA. There has to be at least one LSU.
8) BUFFER_SIZE: The size of the buffer on the FPGA, which stores the inputs and outputs before sending them to LSUs or back to the host. It is ideal to make the buffer size larger than the number of lines in the input. If the buffer size is too small, execution time may worsen significantly.
9) INPUT_FILE: The file that the host side reads the input from.
10) SERIAL_PORT: The name of the port that the host uses for UART communication with the FPGA.

These parameters are found in `rtl/Day10Part2.v`, `sim/sim_Day10Part2.cpp`, and `host/InputParser.cpp`. If you want to change the parameters for simulation with Verilator, modify `rtl/Day10Part2.v` and `sim/sim_Day10Part2.cpp`. If you want to change the parameters for a run with an actual FPGA, modify `rtl/Day10Part2.v` and `host/InputParser.cpp`.

## How to Simulate with Verilator

This RTL design can be simulated using Verilator, an open-source software for simulating Verilog modules. I found that using event-driven simulators such as Icarus Verilog were too slow for testing and simulating this Verilog solution, making a cycle-based simulator such as Verilator more suitable. This is because although this solution is faster than CPU-based solutions, it still takes significantly large number of cycles to find the answer.

### Prerequisites
You need the following tools installed to simulate the solution.
* **Verilator**
* **C++ Compiler** (`g++` or `clang`)
* **Make**

### Installing Verilator
The following commands are for installing Verilator. Refer to https://verilator.org/guide/latest/install.html for detailed installation guide.

**Ubuntu / Debian / WSL (Windows Subsystem for Linux)**
```bash
sudo apt-get update
sudo apt-get install verilator build-essential
```

**MacOS**
```zsh
brew install verilator
```

### Verilate the Design
Run the following command to navigate to the `sim/` directory and translate the Verilog solution to C++.
```bash
cd sim
verilator --cc --exe --build -j 0 -y ../rtl -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND sim_Day10Part2.cpp Day10Part2.v
```

### Run the Simulation
Execute the binary created under `sim/obj_dir/` to run the simulation.
```bash
./obj_dir/VDay10Part2
```

## How to Run on an Actual FPGA

This section describes the steps for running this solution on Digilent Arty S7-25 development board, which contains AMD Spartan-7 FPGA (XC7S25-CSGA324). If you use FPGAs from other vendors, your procedure may vary.
I used Vivado for synthesis, implementation, and generating bitstream.
It also uses C++ code targeted for Linux on the host side for UART IO. If your OS is different, `host/InputParser.cpp` would not work.

1) Create a new RTL project in Vivado. Choose the part or board that you use.
2) Add all modules in `rtl/` as design sources.
3) Create and add the constraints. The constraints need to include `clk`, `reset`, `uart_input` (host to FPGA), and `uart_output` (FPGA to host). The constraints file I used is included in `constraints/` for reference.
4) Run synthesis, run implementation, and generate bitstream.
5) If generating bitstream is complete without error, connect and program the FPGA.
6) Compile and run `host/InputParser.cpp`.
```bash
cd host
g++ -o InputParser InputParser.cpp
./InputParser
```

## Performance Evaluation

The following table compares the execution time and the power consumption of the FPGA-based solution in this repository and the CPU-based reference solution. 

The reference solution can be found in https://www.reddit.com/r/adventofcode/comments/1pk87hl/2025_day_10_part_2_bifurcate_your_way_to_victory/. \
I modified the original reference solution to read from a local input file instead of fetching the input with `aocd`.

|| CPU-based reference solution | This FPGA-based solution |
| :---: | :---: | :---: |
| Device | Apple M2 Max | AMD Spartan-7 FPGA (XC7S25-CSGA324) |
| Clock rate | 3.49 GHz | 100 MHz |
| Execution time* | 283403 µs | 18169 µs (15.6x improvement) |
| Power Consumption | 6026 mW** | 174 mW (34.6x improvement) |

\* Total time including input parsing and IO latency \
\*\* Increased power compared to idle power

As this solution was deployed on an entry-level FPGA (23,360 logic cells), the number of LSUs was limited to 4. Scaling to larger FPGAs would allow for more parallel LSUs, further reducing execution time. \
For detailed specification of the FPGA that I used in this comparison, check page 9 of https://docs.amd.com/v/u/en-US/cost-optimized-product-selection-guide.