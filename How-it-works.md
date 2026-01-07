# How This Design Solves Day 10 Part 2, Advent of Code 2025

## Definitions
Before explaining the algorithm and the implementation details of this solution, some definitions of words used in this document needs to be clarified.
* **MACHINE_COUNT** is the parameter that represents the maximum number of machines in each line. Each machine has one "joltage", or non-negative integer value. Without loss of generality, it can be assumed that all lines have `MACHINE_COUNT` number of machines. This is because the joltages for non-existent machines can be set to 0 without changing the minimum button count.
* **BITS_PER_JOLTAGE** is the parameter for the number of bits required to represent the joltages in this problem without overflow.
* **Buttons** may or may not be assigned to each machine, and each button may be assigned to multiple machines. In this design, each button is represented with `MACHINE_COUNT` bits. If bit `i` is 1, the button is assigned to machine `i`, and each press of that button increases the counter for the machine `i` by 1.
* **Combination** means a combination of either pressing or not pressing each button. For example, a combination may consist of pressing buttons 0 and 2. In this design, a combination is represented with `MACHINE_COUNT` bits, where bit `i` being 1 indicates that the combination includes pressing machine `i`.
* **Target** is the array of joltages for each machines. The counters for all machines have to match the target by pressing the buttons, while minimizing the total number of button presses.
* **Counter** is the array of accumulated joltages resulting from a specific set of button presses.
* **Parity** is represented with `MACHINE_COUNT` bits in this design.
    * **Parity of a combination** means the XOR result of pressing each button in a combination once. For example, button 0 is assigned to machines 4 and 6, and button 2 is assigned to machines 3 and 6. Then the parity of combination `(0, 2)` is 1 for machines 3 and 4, and 0 for other machines.
    * **Parity of a target** means whether or not the joltage of the machines in the target is odd. For example, if the target is 3 for machine 0 and 4 for machine 1, only bit 0 of the parity is 1.

## The Algorithm
This solution uses the algorithm suggested by u/tenthmascot and improved by u/DataMn, posted on r/adventofcode on Reddit.
Check https://www.reddit.com/r/adventofcode/comments/1pk87hl/2025_day_10_part_2_bifurcate_your_way_to_victory/ for the original algorithm description.

The goal for each line in the input is to find the button presses that can achieve the given target while minimizing the total number of button presses. Each button can be pressed an unlimited number of times.

Say `v` is some vector of presses for each button that yields the given target. Then `v` can be split into `v_even` and `v_combination`. `v_combination` is a combination that includes buttons that are pressed odd number of times. `v_even = v - v_combination`, and the values in `v_even` are all even numbers.

Then the parity of the combination `v_combination` **must match** the parity of the given target. This is because the parity of `v` matches the parity of the given target, and button presses in `v_even` cannot change the parity when subtracted from `v`, because they are all even numbers.

From this property, all `v_combination` candidates can be found by iterating over all combinations and checking which ones have the parity that match the parity of the given target.

For each `v_combination` candidate found in this manner, there are 3 possibilities for the counter from pressing buttons in `v_combination`:
1) Some joltage in the counter exceeds the joltage in the target. This means that the candidate cannot be an actual `v_combination` for some `v`.
2) All joltages in the counter are equal to the target. This means that `v = v_combination`. The number of presses in `v` is equal to the number of buttons included in `v_combination`.
3) All joltages in the counter are less or equal to the target, and at least one joltage is less than the value in the target. `v_even` yields (target - counter from `v_combination`).

Case 1 means that the candidate should be discarded. Case 2 means that the number of buttons included in `v_combination` is a valid number of total button presses that achieves the target. Case 3 means that the number of presses in `v_even`, plus the number of buttons included in `v_combination`, is a valid number of total button presses that achieves the target. 

For case 3, the problem becomes finding the `v_even` with the minimum number of button presses that yields (target - counter from `v_combination`). All joltages in (target - counter from `v_combination`) are even numbers, because the parity of `v_combination` and the target match. If `v_divided` yields `(target - counter from v_combination) / 2` with the minimum number of button presses, `v_divided * 2` is the `v_even` with the minimum number of button presses. If there is some other `v_even` that yields (target - counter from `v_combination`) with fewer button presses, `v_even / 2` should have been the minimum number of button presses for `(target - counter from v_combination) / 2`. The problem is reduced to finding the minimum number of button presses for `(target - counter from v_combination) / 2` 

From the above, the following recursive function can be acquired:
```
find_min_button_presses(target, buttons):
    min_button_presses = INFINITE
    for all combinations whose parities match the parity of the target (v_combination):
        new_target = (target - counter from v_combination) / 2 
        if (case 1 - there is a negative number in new_target): discard
        if (case 2 - new_target is 0): 
            if (presses in v_combinatin < min_button_presses): min_button_presses = presses in v_combination
        if (case 3 - new_target has no negatives and is not 0):
            if (2 * find_min_button_presses(new_target, buttons) + (presses in v_combination) < min_button_presses):
                min_button_presses = 2 * find_min_button_presses(new_target, buttons) + (presses in v_combination)
    return min_button_presses
```

## Structure of the Modules
The modules defined in `rtl/` combine to implement the above algorithm on a FPGA. This is the tree of how the core modules are structured. Minor helper modules are omitted.
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

This module is the top module of the design. It contains modules `line_fetcher`, `line_buffer`, multiple `line_solving_unit`, and `multiple_byte_sender`.

`line_fetcher` receives the parsed input lines from the host. Whenever a new line is given, it is pushed to `line_buffer`, which stores lines as a queue. A line stored in the buffer is assigned to one of the `line_solving_unit`s, or LSUs, when some LSU becomes available. Each LSU finds and outputs the minimum number of button presses for the assigned input line. The outputs are added to the accumulated button press count. For each input line given, the accumulated button press count is sent to the host.

All LSUs operate in parallel without any dependencies among themselves, exploiting line-level paralleism in the problem. Note that LSUs may complete operations Out-of-Order. This means that the intermediate values of accumulated button press count does not follow the order in the input. However, its final value is always consistent.

### I/O Protocol

This design uses UART for I/O with the host. 8N1 configuration (8 data bits, no parity bit, and 1 stop bit) is used to send each byte.

The `line_fetcher` module expects the following protocol from the host for each input line:
1) Any byte to start the transmission of a new input line.
2) A byte that represents the number of buttons in the input line.
3) The contents of each button in little-endian format. When `MACHINE_COUNT` is set to 10, it expects 2 bytes per button. The first byte tells if the button is assigned to machines 0 to 7. The second byte tells if the button is assigned to machines 8 to 9. The upper bits of the second byte are discarded.
4) The joltages in the target in little-endian format. When `BITS_PER_JOLTAGE` is set to 9, it expects 2 bytes per joltage. It expects `MACHINE_COUNT` number of joltages.

The `multiple_byte_sender` module sends each result in the following format:
1) A byte that represents the number of bytes for the result.
2) The result in little-endian format. 

## Module `line_solving_unit`

![Diagram for the module line_solving_unit](./images/LSUDiagram.png)
(Diagram generated by AI to help understanding)

`line_solving_unit` is the main module that implements the recursive function `find_min_button_presses` in hardware. Check the above section `The Algorithm` for its pseudocode and proof.

The module is able to call the recursive function with the new target when case 3 of the function is encountered. It is also able to return to the state before the function call when all combinations with matching parity are searched.

The module has states that are universal within each input line, and states that are for the current function call. States `combination_upper_bound` and `flattened_buttons` apply to all function calls within the same input line. `combination`, `current_target`, `current_min_button_press_count`, and `button_press_count_for_current_call` are states for the current function call. Upon each function call, the states of the caller function are stored on the top of the `function_call_stack`. Upon each function return, the states from the caller function are restored from the top of the `function_call_stack`.

The module receives the buttons and the target when it is assigned to an input line. Whenever it is given a new input line, it first acquires a parity-to-combination table using the submodule `parity_to_combination_table`. The submodule builds a linked list structure for all possible parities, on BRAM. Each linked list contains all combinations that has the same parity. Because iterating over all possible combinations at every function call is computationally expensive, the `parity_to_combination_table` iterates over all combinations once to build the linked lists. The module only starts computing the first function after the parity-to-combination table is fully constructed.

The LSU consults the table to find if there is a unexplored combination that matches the parity of `current_target`. If there is a unexplored combination, the hit-combination is used to calculate the new target, as defined in `The Algorithm` section. For case 1, it reverts back to finding the next hit-combination for the current target parity, without changing `current_min_button_press_count`. For case 2, it updates the `current_min_button_press_count` if a smaller value is found, while also reverting back to finding the next hit-combination. For case 3, it calls the recursive function to find the minimum button press count for the new target.

When there are no more unexplored combinations for `current_target`, the callee function returns to the caller function. When `2 * current_min_button_press_count + button_press_count_for_current_call` in the callee function is smaller than the minimum button press count for the caller, the `current_min_button_press_count` of the caller is updated. If the stack is empty when a function is returned, it means that the current function was the one called with the target in the input line. It outputs the answer for the input line and signals that the result is ready.