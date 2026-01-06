// The following code is AI generated. This is not part of my work.
// The purpose of including this reference solution was to compare performance with my FPGA solution.
// This reference solution is the C++ version of code written by u/tenthmascot. (with optimization suggested by u/DataMn)
// Check https://www.reddit.com/r/adventofcode/comments/1pk87hl/2025_day_10_part_2_bifurcate_your_way_to_victory/

#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <sstream>
#include <algorithm>
#include <unordered_map>
#include <chrono>
#include <cmath>

std::string INPUT_FILE = "../data/input.txt";

// Use high performance IO settings
void fast_io() {
    std::ios_base::sync_with_stdio(false);
    std::cin.tie(NULL);
}

// Custom hash for std::vector<int> to be used in unordered_map
struct VectorHash {
    size_t operator()(const std::vector<int>& v) const {
        size_t seed = 0;
        for (int i : v) {
            seed ^= std::hash<int>{}(i) + 0x9e3779b9 + (seed << 6) + (seed >> 2);
        }
        return seed;
    }
};

using State = std::vector<int>;
using ParityMap = std::vector<std::vector<std::pair<State, int>>>;
using MemoMap = std::unordered_map<State, long long, VectorHash>;

const long long INF_COST = 1000000;

// Helper to parse "(1,2,3)" into vector
std::vector<int> parse_tuple(std::string_view s) {
    std::vector<int> res;
    if (s.size() < 2) return res;
    // content inside parens
    std::string content(s.substr(1, s.size() - 2));
    if (content.empty()) return res;
    
    // Replace commas with spaces for easy parsing
    for (char &c : content) {
        if (c == ',') c = ' ';
    }
    
    std::stringstream ss(content);
    int val;
    while (ss >> val) {
        res.push_back(val);
    }
    return res;
}

// Convert vector parity to integer mask
int get_parity_mask(const State& s) {
    int mask = 0;
    for (size_t i = 0; i < s.size(); ++i) {
        if (s[i] % 2 != 0) {
            mask |= (1 << i);
        }
    }
    return mask;
}

// Precompute patterns
ParityMap compute_patterns(const std::vector<State>& coeffs, int num_vars) {
    int num_buttons = coeffs.size();
    // Parity mask size is 2^num_vars
    int parity_count = 1 << num_vars;
    
    // Temporary map: parity_mask -> { pattern -> min_cost }
    // We use a flat vector for parity, and unordered_map for deduplication
    std::vector<std::unordered_map<State, int, VectorHash>> temp_lookup(parity_count);

    // Iterate all subsets of buttons via bitmask
    int limit = 1 << num_buttons;
    for (int mask = 0; mask < limit; ++mask) {
        State pattern(num_vars, 0);
        int cost = 0;
        
        // Build the pattern for this subset
        for (int i = 0; i < num_buttons; ++i) {
            if ((mask >> i) & 1) {
                cost++;
                const auto& c = coeffs[i];
                for (int j = 0; j < num_vars; ++j) {
                    pattern[j] += c[j];
                }
            }
        }
        
        int p_mask = get_parity_mask(pattern);
        
        // Update minimum cost for this specific pattern
        auto& entry = temp_lookup[p_mask];
        auto it = entry.find(pattern);
        if (it == entry.end()) {
            entry[pattern] = cost;
        } else {
            if (cost < it->second) {
                it->second = cost;
            }
        }
    }
    
    // Flatten into vector for fast iteration during recursion
    ParityMap result(parity_count);
    for (int i = 0; i < parity_count; ++i) {
        result[i].reserve(temp_lookup[i].size());
        for (const auto& kv : temp_lookup[i]) {
            result[i].push_back(kv);
        }
    }
    return result;
}

// Recursive solver
long long solve_single_aux(const State& goal, const ParityMap& pattern_costs, MemoMap& memo) {
    // Base case check: all zero
    bool all_zero = true;
    for (int x : goal) {
        if (x != 0) {
            all_zero = false;
            break;
        }
    }
    if (all_zero) return 0;
    
    // Check memo
    if (memo.count(goal)) return memo[goal];
    
    long long answer = INF_COST;
    int p_mask = get_parity_mask(goal);
    
    // Iterate over patterns with matching parity
    const auto& candidates = pattern_costs[p_mask];
    for (const auto& kv : candidates) {
        const State& pattern = kv.first;
        int cost = kv.second;
        
        // Check condition: all(i <= j for i, j in zip(pattern, goal))
        bool valid = true;
        for (size_t i = 0; i < goal.size(); ++i) {
            if (pattern[i] > goal[i]) {
                valid = false;
                break;
            }
        }
        
        if (valid) {
            State new_goal(goal.size());
            for (size_t i = 0; i < goal.size(); ++i) {
                new_goal[i] = (goal[i] - pattern[i]) / 2;
            }
            
            long long sub_res = solve_single_aux(new_goal, pattern_costs, memo);
            
            // To match Python logic: min(answer, cost + 2 * sub_res)
            // Note: sub_res can be large if it bubbled up from an INF path.
            long long total = cost + 2 * sub_res;
            if (total < answer) {
                answer = total;
            }
        }
    }
    
    return memo[goal] = answer;
}

int main() {
    fast_io();
    
    // Start timing
    auto start_time = std::chrono::high_resolution_clock::now();
    
    std::string input_file = INPUT_FILE;
    std::ifstream file(input_file);
    if (!file.is_open()) {
        std::cerr << "Error opening file" << std::endl;
        return 1;
    }

    // Read all lines first
    std::vector<std::string> lines;
    std::string line;
    while (std::getline(file, line)) {
        if (!line.empty()) {
            lines.push_back(line);
        }
    }

    long long total_score = 0;
    
    for (size_t I = 0; I < lines.size(); ++I) {
        const std::string& L = lines[I];
        
        // Parsing logic: "_ *coeffs goal"
        // Split by space
        std::stringstream ss(L);
        std::string segment;
        std::vector<std::string> parts;
        while (ss >> segment) {
            parts.push_back(segment);
        }
        
        // Python: _, *coeffs, goal = L.split()
        // parts[0] is ignored
        // parts.back() is goal
        // middle are coeffs (indices tuples)
        
        // Parse Goal
        std::vector<int> goal = parse_tuple(parts.back());
        int num_vars = goal.size();
        
        // Parse Coeffs (Buttons)
        // Python logic: coeffs = [tuple(int(i in r) for i in range(len(goal))) for r in coeffs]
        std::vector<State> coeffs;
        // Iterate parts[1] to parts[size-2]
        for (size_t k = 1; k < parts.size() - 1; ++k) {
            std::vector<int> indices = parse_tuple(parts[k]);
            State c(num_vars, 0);
            for (int idx : indices) {
                if (idx >= 0 && idx < num_vars) {
                    c[idx] = 1;
                }
            }
            coeffs.push_back(c);
        }
        
        // Precompute
        ParityMap pattern_costs = compute_patterns(coeffs, num_vars);
        
        // Solve
        MemoMap memo;
        long long subscore = solve_single_aux(goal, pattern_costs, memo);
        
        total_score += subscore;
        std::cout << "Line " << (I + 1) << "/" << lines.size() << ": answer " << total_score << "\n";
    }
    
    std::cout << total_score << "\n";

    auto end_time = std::chrono::high_resolution_clock::now();
    auto duration_ns = std::chrono::duration_cast<std::chrono::nanoseconds>(end_time - start_time).count();
    double duration_us = duration_ns / 1000.0;
    
    // Output formatted to 3 decimal places
    printf("Duration: %.3f us\n", duration_us);

    return 0;
}