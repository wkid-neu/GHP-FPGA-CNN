#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <time.h>
#include <math.h>

#include "utils.h"

void rd_hex_file(char* fp, void* dst_buf) {
    int fd = open(fp, O_RDONLY);
    if (fd < 0) {
        printf("Open file failed, fp: %s\n, fd: %d", fp, fd);
        exit(-1);
    }

    struct stat f_stat;
    if (fstat(fd, &f_stat) < 0) {
        printf("Get file attributes failed, fp: %s, fd: %d\n", fp, fd);
        exit(-1);
    }

    void* base = mmap(NULL, f_stat.st_size, PROT_READ, MAP_SHARED, fd, 0);
    if (base == MAP_FAILED) {
        printf("mmap failed, fp: %s, fd: %d\n", fp, fd);
        exit(-1);
    }

    memcpy((void*)dst_buf, base, f_stat.st_size);

    if (munmap(base, f_stat.st_size) < 0) {
        printf("munmap failed, fp: %s, fd: %d\n", fp, fd);
        exit(-1);
    }
    close(fd);
}

long get_file_size(char* fp) {
    int fd = open(fp, O_RDONLY);
    if (fd < 0) {
        printf("Open file failed, fp: %s\n, fd: %d", fp, fd);
        exit(-1);
    }

    struct stat f_stat;
    if (fstat(fd, &f_stat) < 0) {
        printf("Get file attributes failed, fp: %s, fd: %d\n", fp, fd);
        exit(-1);
    }

    close(fd);
    return f_stat.st_size;
}

void conv_get_ofm_shape(
    uint32_t INH_, uint32_t INW_, 
    uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
    uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD,
    uint32_t* OH, uint32_t* OW
) {
    double _OH = floor((INH_+padU+padD-KH)*1.0/strideH+1);
    double _OW = floor((INW_+padL+padR-KW)*1.0/strideW+1);
    *OH = (uint32_t)_OH;
    *OW = (uint32_t)_OW;
}

float conv_get_n_op(
    uint32_t OC, uint32_t INC,
    uint32_t INH_, uint32_t INW_, 
    uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
    uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD
) {
    uint32_t OH, OW;
    conv_get_ofm_shape(
        INH_, INW_, KH, KW, strideH, strideW,
        padL, padR, padU, padD,
        &OH, &OW
    );
    uint32_t n_pixels = OC*OH*OW;
    uint32_t n_op_pixel = INC*KH*KW*2;
    return n_pixels*1.0*n_op_pixel;
}

float get_ideal_throughput(uint32_t M, uint32_t P, float sa_clk) {
    float n_mac = M*P;
    return n_mac*sa_clk*(32.0/9)/1000000000;
}

float get_throughput_gops(float n_op, uint32_t n_cycle, float main_clk) {
    float time_ns = n_cycle*(1000000000/main_clk);
    return n_op/time_ns;
}

float get_mem_speed_MBPS(long latency_ns, uint32_t size) {
    return size*1000*1.0/latency_ns;
}

float get_mem_speed_GBPS(long latency_ns, uint32_t size) {
    return size*1.0/latency_ns;
}

static int timespec_check(struct timespec *t) {
	if ((t->tv_nsec < 0) || (t->tv_nsec >= 1000000000))
		return -1;
	return 0;
}

void timespec_sub(struct timespec *t1, struct timespec *t2) {
	if (timespec_check(t1) < 0) {
		fprintf(stderr, "invalid time #1: %lld.%.9ld.\n",
			(long long)t1->tv_sec, t1->tv_nsec);
		return;
	}
	if (timespec_check(t2) < 0) {
		fprintf(stderr, "invalid time #2: %lld.%.9ld.\n",
			(long long)t2->tv_sec, t2->tv_nsec);
		return;
	}
	t1->tv_sec -= t2->tv_sec;
	t1->tv_nsec -= t2->tv_nsec;
	if (t1->tv_nsec >= 1000000000) {
		t1->tv_sec++;
		t1->tv_nsec -= 1000000000;
	} else if (t1->tv_nsec < 0) {
		t1->tv_sec--;
		t1->tv_nsec += 1000000000;
	}
}

void rd_tensor(char* fp, uint32_t len, float* buf) {
    FILE* f = fopen(fp, "r");
    for (uint32_t i=0; i<len; i++) {
        fscanf(f, "%f\n", buf+i);
    }
    fclose(f);
}

void check_buf(void* src, void* dst, uint32_t size, uint32_t* match, uint32_t* mismatch) {
    uint8_t expected = 0, got = 0;
    uint32_t err = 0;

    for (uint32_t i=0; i<size; i++) {
        expected = *(((uint8_t*)src)+i);
        got = *(((uint8_t*)dst)+i);
        if (expected != got) {
            err ++;
            // printf("expected: %0d, got: %0d\n", expected, got);
        }
    }

    *match = size - err;
    *mismatch = err;
}
