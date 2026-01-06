#include <iostream>
#include <fstream>
#include <vector>
#include <string>

#include <deque>

#include <verilated.h>
#include "VDay10Part2.h"

using namespace std;

// parameters
const int CLK_FREQUENCY = 100'000'000;
const int BAUD_RATE = 5'000'000;
const int CLKS_PER_BIT = CLK_FREQUENCY / BAUD_RATE;
const int MACHINE_COUNT = 10;
const string INPUT_FILE = "../data/input.txt";

class TransmitterToDut {
    enum State { IDLE, START_BIT, DATA_BITS, STOP_BIT };
    State state = IDLE;
    int clock_count;
    int bit_index;
    uint8_t latched_byte_to_send;

    deque<uint8_t> byte_to_send_queue;

public:
    void newByteToSend(uint8_t byte_to_send) {
        byte_to_send_queue.push_back(byte_to_send);
    }

    bool posedgeClk() {
        bool uart_bit_to_dut;

        switch (state) {
            case IDLE:
                uart_bit_to_dut = true;
                if (!byte_to_send_queue.empty()) {
                    latched_byte_to_send = byte_to_send_queue.front();
                    byte_to_send_queue.pop_front();
                    state = START_BIT;
                    clock_count = 0;
                }
                break;

            case START_BIT:
                uart_bit_to_dut = false;
                if (++clock_count >= CLKS_PER_BIT) {
                    state = DATA_BITS;
                    clock_count = 0;
                    bit_index = 0;
                }
                break;

            case DATA_BITS:
                uart_bit_to_dut = (latched_byte_to_send >> bit_index) & 1;
                if (++clock_count >= CLKS_PER_BIT) {
                    if (++bit_index >= 8) state = STOP_BIT;
                    clock_count = 0;
                }
                break;

            case STOP_BIT:
                uart_bit_to_dut = true;
                if (++clock_count >= CLKS_PER_BIT) {
                    state = IDLE;
                    clock_count = 0;
                }
                break;
        }

        return uart_bit_to_dut;
    }
};

class ReceiverFromDut {
    enum State { IDLE, START_BIT, DATA_BITS, CLEANUP };
    State state = IDLE;
    int clock_count = 0;
    int bit_index = 0;

public:
    bool new_byte;
    uint8_t byte_received;

    void posedgeClk(bool uart_bit_from_dut) {
        new_byte = false;

        switch (state) {
            case IDLE:
                if (!uart_bit_from_dut) {
                    state = START_BIT;
                    clock_count = 0;
                }
                break;

            case START_BIT:
                if (++clock_count >= CLKS_PER_BIT / 2) {
                    state = (uart_bit_from_dut == 0) ? DATA_BITS : IDLE;
                    clock_count = 0;
                    bit_index = 0;
                    byte_received = 0;
                }
                break;

            case DATA_BITS:
                if (++clock_count >= CLKS_PER_BIT) {
                    if (uart_bit_from_dut) byte_received |= (1 << bit_index);
                    if (++bit_index >= 8) state = CLEANUP;
                    clock_count = 0;
                }
                break;

            case CLEANUP:
                if (++clock_count >= CLKS_PER_BIT) {
                    state = IDLE;
                    clock_count = 0;
                    new_byte = true;
                }
                break;
        }
    }
};

class Decoder {
    enum State { IDLE, RECEIVING_DATA };
    State state = IDLE;
    int number_of_bytes_read = 0;
    int number_of_bytes_to_read = 0;
    uint64_t result;

public:
    void decode(uint8_t byte_received, int& number_of_lines_read) {
        switch (state) {
            case IDLE:
                state = RECEIVING_DATA;
                number_of_bytes_read = 0;
                number_of_bytes_to_read = byte_received;
                result = 0;
                break;
            case RECEIVING_DATA:
                result += (byte_received << number_of_bytes_read * 8);
                number_of_bytes_read += 1;
                if (--number_of_bytes_to_read == 0) {
                    state = IDLE;
                    number_of_lines_read++;
                    cout << number_of_lines_read << ": " << result << endl;
                }
                break;
        }
    }
};

struct Line {
    vector<uint16_t> buttons;
    vector<uint16_t> targets;
};

Line parse_line(string& raw_line) {
    Line parsed_line;
    int i;
    for (i = 1; i < raw_line.size(); i++) {
        if (raw_line[i] == ']') {
            i++;
            break;
        }
    }

    uint16_t button;
    for (i++; i < raw_line.size(); i++) {
        if (raw_line[i] == '(') {
            button = 0;
        } else if (raw_line[i] == ')') {
            parsed_line.buttons.push_back(button);
        } else if (raw_line[i] >= '0' && raw_line[i] <= '9') {
            button += (1 << (raw_line[i] - '0'));
        } else if (raw_line[i] == '{') break;
    }

    int joltageTarget = 0;
    for (i++; i < raw_line.size(); i++) {
        if (raw_line[i] == ',') {
            parsed_line.targets.push_back(joltageTarget);
            joltageTarget = 0;
        }
        else if (raw_line[i] == '}') {
            parsed_line.targets.push_back(joltageTarget);
            break;
        }
        else if (raw_line[i] >= '0' && raw_line[i] <= '9') {
            joltageTarget *= 10;
            joltageTarget += raw_line[i] - '0';
        }
    }

    return parsed_line;
}

void send_line(TransmitterToDut& transmitter, Line& parsed_line) {
    transmitter.newByteToSend(0x00);
    transmitter.newByteToSend(parsed_line.buttons.size());

    for (uint16_t button: parsed_line.buttons) {
        transmitter.newByteToSend(button & 0xFF);
        transmitter.newByteToSend(button >> 8);
    }

    for (int i = 0; i < MACHINE_COUNT; i++) {
        uint16_t target = (i < parsed_line.targets.size()) ? parsed_line.targets[i] : 0;
        transmitter.newByteToSend(target & 0xFF);
        transmitter.newByteToSend(target >> 8);
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    VDay10Part2* dut = new VDay10Part2;

    TransmitterToDut transmitter;
    ReceiverFromDut receiver;
    Decoder decoder;

    int number_of_input_lines_sent = 0;
    ifstream input_file(INPUT_FILE);
    string raw_line;
    getline(input_file, raw_line);
    while(true) {
        Line parsed_line = parse_line(raw_line);
        send_line(transmitter, parsed_line);
        number_of_input_lines_sent++;
        if (!getline(input_file, raw_line)) break;
    }
    input_file.close();

    int time_for_reset = 100;
    dut->reset = 1;
    dut->clk = 0;
    dut->uart_input = 1;

    int number_of_lines_read = 0;

    while (!Verilated::gotFinish()) {
        dut->clk = !dut->clk;
        if (--time_for_reset > 0) dut->reset = 1;
        else dut->reset = 0;

        if (dut->reset == 0 && dut->clk) {
            dut->uart_input = transmitter.posedgeClk();
            receiver.posedgeClk(dut->uart_output);
            if (receiver.new_byte) decoder.decode(receiver.byte_received, number_of_lines_read);
        }

        dut->eval();

        if (number_of_lines_read >= number_of_input_lines_sent) break;
    }

    delete dut;
    return 0;
}