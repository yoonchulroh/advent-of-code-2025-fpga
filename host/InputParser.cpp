#include <iostream>
#include <fstream>
#include <vector>
#include <string>

#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <asm/termbits.h>

#include <thread>
#include <mutex>

#include <chrono>

// configuration
const char* SERIAL_PORT = "/dev/ttyUSB1";
const char* INPUT_FILE = "../data/input.txt";
const int BAUD_RATE = 5000000; // 5M

const int MACHINE_COUNT = 10;
const int BUFFER_SIZE = 200;

const int TIMEOUT = 255; // in deciseconds

using namespace std;

struct Line {
    vector<uint16_t> buttons;
    vector<uint16_t> targets;
};

struct UARTData {
    bool allLinesSent = false;
    int number_of_input_lines = 0;
    int number_of_lines_read = 0;
    mutex mtx;
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

int UART_setup(const char* serial_port, int baud_rate) {
    int fd = open(serial_port, O_RDWR | O_NOCTTY);

    struct termios2 tio;
    ioctl(fd, TCGETS2, &tio);

    tio.c_cflag &= ~CBAUD;
    tio.c_cflag |= BOTHER;
    tio.c_ispeed = baud_rate;
    tio.c_ospeed = baud_rate;

    tio.c_cflag &= ~PARENB;
    tio.c_cflag &= ~CSTOPB;
    tio.c_cflag &= ~CSIZE;
    tio.c_cflag |= CS8;

    tio.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
    tio.c_iflag &= ~(IXON | IXOFF | IXANY | IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL);
    tio.c_oflag &= ~OPOST;

    tio.c_cc[VMIN] = 1;
    tio.c_cc[VTIME] = TIMEOUT;

    ioctl(fd, TCSETS2, &tio);

    return fd;
}

void send_line(int fd, Line& parsed_line) {
    vector<uint8_t> data_to_send_buffer;

    data_to_send_buffer.clear();
    data_to_send_buffer.push_back(0x00); // send 0 to start transmission
    data_to_send_buffer.push_back(parsed_line.buttons.size()); // send button_count

    // send buttons, each using 2 bytes, in little endian format
    for (uint16_t button: parsed_line.buttons) {
        data_to_send_buffer.push_back(button & 0xFF);
        data_to_send_buffer.push_back(button >> 8);
    }

    // send targets, each using 2 bytes, in little endian format
    for (int i = 0; i < MACHINE_COUNT; i++) {
        uint16_t target = (i < parsed_line.targets.size()) ? parsed_line.targets[i] : 0;
        data_to_send_buffer.push_back(target & 0xFF);
        data_to_send_buffer.push_back(target >> 8);
    }

    write(fd, data_to_send_buffer.data(), data_to_send_buffer.size());
}

int read_line_result(int fd, int number_of_bytes_to_read) {
    size_t number_of_bytes_read = 0;
    uint8_t byte_received;
    int result = 0;

    while (number_of_bytes_read < number_of_bytes_to_read) {
        if (read(fd, &byte_received, 1) > 0) {
            result += byte_received << 8 * number_of_bytes_read;
            number_of_bytes_read += 1;
        } else {
            cout << "timeout from UART after receiving initial byte" << endl;
            return 0;
        }
    }

    return result;
}

int main() {
    auto program_start_time = chrono::high_resolution_clock::now();

    int UART_fd = UART_setup(SERIAL_PORT, BAUD_RATE);

    ifstream input_file(INPUT_FILE);
    string raw_line;

    UARTData data_for_rx;

    thread thread_for_rx([UART_fd, &data_for_rx] {
        int number_of_lines_read = 0;
        bool allLinesSent = false;
        int number_of_input_lines = 0;

        while (allLinesSent == false || number_of_lines_read < number_of_input_lines) {
            uint8_t number_of_bytes_to_read;
            if (read(UART_fd, &number_of_bytes_to_read, 1) > 0) {
                cout << number_of_lines_read + 1 << ": " << read_line_result(UART_fd, number_of_bytes_to_read) << endl;
                number_of_lines_read += 1;
            } else {
                cout << "timeout from UART" << endl;
            }

            lock_guard<mutex> lock(data_for_rx.mtx);
            allLinesSent = data_for_rx.allLinesSent;
            number_of_input_lines = data_for_rx.number_of_input_lines;
            data_for_rx.number_of_lines_read = number_of_lines_read;
        }
    });

    int number_of_input_lines = 0;
    int number_of_lines_read = 0;
    getline(input_file, raw_line);
    while (true) {
        while (true) {
            lock_guard<mutex> lock(data_for_rx.mtx);
            if (number_of_input_lines - data_for_rx.number_of_lines_read < BUFFER_SIZE) break;
        }

        Line parsed_line = parse_line(raw_line);
        number_of_input_lines += 1;
        
        if (!getline(input_file, raw_line)) {
            lock_guard<mutex> lock(data_for_rx.mtx);
            data_for_rx.allLinesSent = true;
            data_for_rx.number_of_input_lines = number_of_input_lines;
            send_line(UART_fd, parsed_line); 
            break;
        }
        
        send_line(UART_fd, parsed_line); 
    }

    thread_for_rx.join();

    close(UART_fd);

    auto program_end_time = chrono::high_resolution_clock::now();
    
    auto duration_in_microseconds = chrono::duration_cast<chrono::microseconds>(program_end_time - program_start_time).count();

    cout << "Execution time: " << duration_in_microseconds << " microseconds" << endl;

    return 0;
}