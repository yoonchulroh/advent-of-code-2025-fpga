# The following code is written by another person. This is not part of my work.
# The purpose of including this reference solution was to compare performance with my FPGA solution.
# This reference solution is the optimized version of code written by u/tenthmascot. (with optimization suggested by u/DataMn)
# Check https://www.reddit.com/r/adventofcode/comments/1pk87hl/2025_day_10_part_2_bifurcate_your_way_to_victory/

# I made modifications to the original code for
# 1) measuring the execution time of the code
# 2) reading from a downloaded txt file, instead of using the auto-downloader

input_file = "../data/input.txt"

from functools import cache
from itertools import combinations, product
import time

def patterns(coeffs: list[tuple[int, ...]]) -> dict[tuple[int, ...], dict[tuple[int, ...], int]]:
	num_buttons = len(coeffs)
	num_variables = len(coeffs[0])
	out = {parity_pattern: {} for parity_pattern in product(range(2), repeat=num_variables)}
	for num_pressed_buttons in range(num_buttons+1):
		for buttons in combinations(range(num_buttons), num_pressed_buttons):
			pattern = tuple(map(sum, zip((0,) * num_variables, *(coeffs[i] for i in buttons))))
			parity_pattern = tuple(i%2 for i in pattern)
			if pattern not in out[parity_pattern]:
				out[parity_pattern][pattern] = num_pressed_buttons
	return out

def solve_single(coeffs: list[tuple[int, ...]], goal: tuple[int, ...]) -> int:
	pattern_costs = patterns(coeffs)
	@cache
	def solve_single_aux(goal: tuple[int, ...]) -> int:
		if all(i == 0 for i in goal): return 0
		answer = 1000000
		for pattern, pattern_cost in pattern_costs[tuple(i%2 for i in goal)].items():
			if all(i <= j for i, j in zip(pattern, goal)):
				new_goal = tuple((j - i)//2 for i, j in zip(pattern, goal))
				answer = min(answer, pattern_cost + 2 * solve_single_aux(new_goal))
		return answer
	return solve_single_aux(goal)

def solve(raw: str):
	score = 0
	lines = raw.splitlines()
	for I, L in enumerate(lines, 1):
		_, *coeffs, goal = L.split()
		goal = tuple(int(i) for i in goal[1:-1].split(","))
		coeffs = [[int(i) for i in r[1:-1].split(",")] for r in coeffs]
		coeffs = [tuple(int(i in r) for i in range(len(goal))) for r in coeffs]

		subscore = solve_single(coeffs, goal)
		print(f'Line {I}/{len(lines)}: answer {subscore}')
		score += subscore
	print(score)

start_time = time.perf_counter_ns()

solve(open(input_file).read())

end_time = time.perf_counter_ns()

duration_ns = end_time - start_time
duration_ms = duration_ns / 1000

print(f"Duration: {duration_ms:.3f} us")