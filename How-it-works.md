# How This Design Solves Day 10 Part 2, Advent of Code 2025

## Definitions
Before explaining the algorithm and the implementation details of this solution, several key terms used in this document are defined below.
* **MACHINE_COUNT** is the parameter that represents the maximum number of machines in each line. Each machine has one "joltage" (a non-negative integer value). Without loss of generality, all lines are assumed to contain `MACHINE_COUNT` machines. Joltage values for padded (non-existent) machines can be set to 0. 
* **MAX_BUTTON_COUNT** is the parameter that represents the maximum number of buttons in one input line.
* **BITS_PER_JOLTAGE** is the parameter for the number of bits required to represent the joltages in this problem without overflow.
* **Buttons** may or may not be assigned to each machine, and each button may be assigned to multiple machines. In this design, each button is represented with a `MACHINE_COUNT`-width bit vector. If bit `i` is asserted, the button is assigned to machine `i`, and each press of that button increases the counter for the machine `i` by 1.
* **Combination** refers to a specific subset of buttons chosen to be pressed. For example, a combination may consist of pressing buttons 0 and 2. In this design, a combination is represented with `MAX_BUTTON_COUNT` bits, where bit `i` being asserted indicates that the combination includes pressing button `i`.
* **Counter** is the array of accumulated joltages resulting from a specific set of button presses.
* **Target** is the array of joltages for each machine. The counter must converge to the target by pressing the buttons, while minimizing the total number of button presses.
* **Parity** is represented with `MACHINE_COUNT` bits in this design.
    * **Parity of a combination** means the XOR result of pressing each button in a combination once. For example, button 0 is assigned to machines 4 and 6, and button 2 is assigned to machines 3 and 6. Then the parity of combination `(0, 2)` is 1 for machines 3 and 4, and 0 for other machines.
    * **Parity of a target** indicates the odd/even status of the joltage for each machine in the target. For example, if the target is 3 for machine 0 and 4 for machine 1, only bit 0 of the parity is 1.

## The Algorithm
This solution uses the algorithm suggested by u/tenthmascot and improved by u/DataMn, posted on r/adventofcode on Reddit.
Refer to [this reddit post](https://www.reddit.com/r/adventofcode/comments/1pk87hl/2025_day_10_part_2_bifurcate_your_way_to_victory/) for the original algorithm description.

The goal for each line in the input is to find the button presses that can achieve the given target while minimizing the total number of button presses. Each button can be pressed an unlimited number of times.

Let `v` be a vector of presses for each button that yields the given target. Then `v` can be split into v<sub>even</sub> and v<sub>combination</sub>. v<sub>combination</sub> is a combination that includes buttons that are pressed an odd number of times. v<sub>even</sub> = v - v<sub>combination</sub>. Then the values in v<sub>even</sub> are all even numbers.

Here, the parity of the combination v<sub>combination</sub> **must align** with the parity of the given target. The parity of v matches the parity of the given target. Since v<sub>even</sub> consists exclusively of even numbers, subtracting it from v preserves parity. Therefore, the parity of v<sub>combination</sub> is identical to that of the target.

From this property, all v<sub>combination</sub> candidates can be found by iterating over all combinations and checking which ones have a parity that matches the parity of the given target.

For each v<sub>combination</sub> candidate found in this manner, there are 3 possibilities for the counter from pressing buttons in v<sub>combination</sub>:
1) A counter value exceeds the corresponding target value. This means that the candidate cannot be an actual v<sub>combination</sub> for some v.
2) All joltages in the counter are equal to the target. This means that v = v<sub>combination</sub>. The number of presses in v is equal to the number of buttons included in v<sub>combination</sub>.
3) All joltages in the counter are less than or equal to the target, and at least one joltage is less than the value in the target. v<sub>even</sub> yields the counter value (target - counter from v<sub>combination</sub>).

Case 1 indicates an invalid branch; the candidate is discarded. Case 2 means that the number of buttons included in v<sub>combination</sub> is a valid number of total button presses that achieves the target. Case 3 means that the number of presses in v<sub>even</sub>, plus the number of buttons included in v<sub>combination</sub>, is a valid number of total button presses that achieves the target. 

For case 3, the problem becomes finding the v<sub>even</sub> with the minimum number of button presses that yields (target - counter from v<sub>combination</sub>). All joltages in (target - counter from v<sub>combination</sub>) are even numbers, because the parity of v<sub>combination</sub> and the target match. If v<sub>divided</sub> yields (target - counter from v<sub>combination</sub>) / 2 with the minimum number of button presses, v<sub>divided</sub> * 2 is the v<sub>even</sub> with the minimum number of button presses. If there is some other v<sub>even</sub> that yields (target - counter from v<sub>combination</sub>) with fewer button presses, v<sub>even</sub> / 2 should have been the minimum number of button presses for (target - counter from v<sub>combination</sub>) / 2. The problem is reduced to finding the minimum number of button presses for (target - counter from v<sub>combination</sub>) / 2.

Based on this logic, the following recursive function is derived:
```
find_min_button_presses(target, buttons):
    min_button_presses = INFINITY
    for all combinations whose parities match the parity of the target (v_combination):
        new_target = (target - counter from v_combination) / 2 
        if (case 1 - there is a negative number in new_target): discard
        if (case 2 - new_target is 0): 
            if (presses in v_combination < min_button_presses): min_button_presses = presses in v_combination
        if (case 3 - new_target has no negatives and is not 0):
            min_button_presses_candidate = 2 * find_min_button_presses(new_target, buttons) + (presses in v_combination)
            if (min_button_presses_candidate < min_button_presses):
                min_button_presses = min_button_presses_candidate
    return min_button_presses
```

## Hierarchy of the Modules
The modules defined in `rtl/` combine to implement the above algorithm on an FPGA. The module hierarchy is structured as follows. Minor helper modules are omitted.
```
Day10Part2
├── line_fetcher
├── line_buffer
├── line_solving_unit (0 ... LSU_COUNT - 1)
│   ├── parity_finder
│   ├── parity_to_combination_table
│   ├── combination_new_target_finder
│   └── function_call_stack
└── multiple_byte_sender
```

## Module `Day10Part2`

![Diagram for the module Day10Part2](./images/Day10Part2Diagram.png)
(Diagram generated by AI to help understanding)

This is the top-level entity of the design. It contains modules `line_fetcher`, `line_buffer`, multiple `line_solving_unit`, and `multiple_byte_sender`.

`line_fetcher` receives the parsed input lines from the host. Incoming lines are pushed to the `line_buffer` FIFO (First-In-First-Out) upon receipt. Buffered lines are dispatched to a `line_solving_unit` (LSU) when one becomes available. Each LSU finds and outputs the minimum number of button presses for the assigned input line. The outputs are added to the global accumulated button press count. For each input line given, the accumulated button press count is sent to the host.

All LSUs operate in parallel with no inter-dependencies, exploiting line-level parallelism in the problem. Note that LSUs may complete operations Out-of-Order. Consequently, intermediate accumulation values may not reflect the input order; however, the final summation remains consistent. 

### I/O Protocol

Host communication is established via UART. 8N1 configuration (8 data bits, no parity bit, and 1 stop bit) is used to send each byte.

The `line_fetcher` module adheres to the following reception protocol:
1) A generic byte to start the transmission of a new input line.
2) A byte that represents the number of buttons in the input line.
3) The contents of each button in little-endian format. When `MACHINE_COUNT` is set to 10, it expects 2 bytes per button. The first byte indicates whether the button is assigned to machines 0 to 7. The second byte indicates whether the button is assigned to machines 8 to 9. The upper bits of the second byte are discarded.
4) The joltages in the target in little-endian format. When `BITS_PER_JOLTAGE` is set to 9, it expects 2 bytes per joltage. It expects `MACHINE_COUNT` number of joltages.

The `multiple_byte_sender` module sends each result in the following format:
1) A byte that represents the number of bytes for the result.
2) The result in little-endian format. 

## Module `line_solving_unit`

![Diagram for the module line_solving_unit](./images/LSUDiagram.png)
(Diagram generated by AI to help understanding)

`line_solving_unit` is the main module that implements the recursive function `find_min_button_presses` in hardware. Go to the above section [The Algorithm](#the-algorithm) for its pseudocode and proof.

The module supports recursive calls with the new target when case 3 of the function is encountered. It also supports state restoration upon function return, when all combinations with matching parity are searched.

The module maintains both line-global states and function-local states. States `combination_upper_bound` and `flattened_buttons` apply to all function calls within the same input line. `combination`, `current_target`, `current_min_button_press_count`, and `button_press_count_for_current_call` are states for the current function call. Upon function invocation, the caller's state is pushed onto the `function_call_stack`. Upon each function return, the states from the caller function are restored from the top of the `function_call_stack`.

The module receives the buttons and the target when it is assigned to an input line. Whenever it is given a new input line, it first acquires a parity-to-combination table via the submodule `parity_to_combination_table`. The submodule builds a linked list structure for all possible parities. Block RAM (BRAM) stores the head combination for each parity, and next combination for each combination sharing the same parity. Each linked list contains all combinations that have the same parity. Because iterating over all combinations at every function call is computationally expensive, the `parity_to_combination_table` iterates over all combinations once to build the linked lists. Once the table of linked lists is built, it can be globally used by all function calls within the same input line. The module only starts computing the first function after the parity-to-combination table is fully constructed.

The LSU consults the table to find if there is an unexplored combination that matches the parity of `current_target`. If there is an unexplored combination, the hit-combination (matching combination) is used to calculate the new target, as defined in `The Algorithm` section. For case 1, it reverts to finding the next hit-combination for the current target parity, without changing `current_min_button_press_count`. For case 2, it updates the `current_min_button_press_count` if a smaller value is found, while also looping back to finding the next hit-combination. For case 3, it calls the recursive function to find the minimum button press count for the new target.

When there are no more unexplored combinations for `current_target`, the callee function returns to the caller function. When `2 * current_min_button_press_count + button_press_count_for_current_call` in the callee function is smaller than the minimum button press count for the caller, the `current_min_button_press_count` of the caller is updated. An empty stack upon return indicates completion of the root function call for the current input line. The module then outputs the answer for the input line and asserts the ready signal.