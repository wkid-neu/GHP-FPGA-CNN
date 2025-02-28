#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <getopt.h>
#include <string.h>
#include <math.h>
#include <assert.h>

#include "utils.h"
#include "base.h"
#include "hw.h"
#include "test.h"

static const struct option long_opts[] = {
    {"addr", required_argument, NULL, 0},
    {"size",required_argument,NULL, 1}
};

void run(uint32_t addr, uint32_t size);

int main(int argc, char const *argv[]) {
    int cmd_opt;
    uint32_t addr = 0, size = 0;

    while ((cmd_opt = getopt_long(
        argc, (char * const*)argv, "0:1:", long_opts, NULL
    )) != -1) {
        switch (cmd_opt)
        {
        case 0:
            // addr = strtoul(optarg, NULL, 16);
            addr = atol(optarg);
            break;
        case 1:
            size = atol(optarg);
            break;
        default:
            printf("Arguments error\n");
			exit(0);
            break;
        }
    }

    run(addr, size);
}

void run(uint32_t addr, uint32_t size) {
    /* Parameters checking */
    assert(addr >= 0x80000000);
    assert(size%64 == 0);
    assert(addr+size <= 0xffffffff);
    /* Devices */
    int h2c_fd, c2h_fd;
    /* Open devices */
    h2c_fd = open(DEVICE_H2C, O_RDWR | O_NONBLOCK);
    c2h_fd = open(DEVICE_C2H, O_RDWR | O_NONBLOCK);
    /* Run the test */
    long h2c_latency = 0, c2h_latency = 0;
    test_dram_rw(h2c_fd, c2h_fd, addr, size, &h2c_latency, &c2h_latency);
    float h2c_speed = get_mem_speed_GBPS(h2c_latency, size);
    float c2h_speed = get_mem_speed_GBPS(c2h_latency, size);
    printf("wr_speed: %.2f GB/s, rd_speed: %.2f GB/s\n", h2c_speed, c2h_speed);
    /* Close devices */
    close(h2c_fd);
    close(c2h_fd);
}
