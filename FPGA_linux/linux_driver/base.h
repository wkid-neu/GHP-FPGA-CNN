#if !defined(__BASE_H__)
#define __BASE_H__

#include <stdint.h>

#define INS_NONE 0b11111111
#define INS_CONV 0b00000001
#define INS_MAXP 0b00000010
#define INS_AVGP 0b00000011
#define INS_ADD 0b00000100
#define INS_REMAP 0b00000101
#define INS_FC 0b00000110

typedef uint8_t uint4_t;

struct Model {
    uint32_t sta_conv_weight_ddr_addr;
    uint32_t sta_conv_weight_ddr_len;
    uint32_t dyn_conv_weight_ddr_addr;
    uint32_t dyn_conv_weight_ddr_len;
    uint32_t fc_weight_ddr_addr;
    uint32_t fc_weight_ddr_len;
    uint32_t bias_ddr_addr;
    uint32_t bias_ddr_len;
    uint32_t ins_ddr_addr;
    uint32_t ins_ddr_len;
    uint32_t xphs_ddr_addr;
    uint32_t xphs_ddr_len;
    uint32_t input_ddr_addr;
    uint32_t input_ddr_len;
    uint32_t input_rtm_addr;
    uint32_t output_ddr_addr;
    uint32_t output_ddr_len;
    uint32_t output_rtm_addr;
    char output_rtm_mode [256];
    uint32_t input_n_chan;
    uint32_t input_height;
    uint32_t input_width;
    float input_s;
    uint8_t input_z;
    float output_s;
    uint8_t output_z;

    // Data
    uint8_t* sta_conv_weights;
    uint8_t* dyn_conv_weights;
    uint8_t* fc_weights;
    uint8_t* bias;
    uint8_t* ins;
    uint8_t* xphs;
};

struct Conv {
    uint8_t op_type;
    uint16_t xphs_addr;
    uint16_t xphs_len;
    uint32_t W_addr;
    uint32_t W_n_bytes;
    uint16_t B_addr;
    uint32_t X_addr;
    uint32_t Y_addr;
    uint16_t OC;
    uint16_t INC;
    uint16_t INW_;
    uint8_t KH;
    uint8_t KW;
    uint4_t strideH;
    uint4_t strideW;
    uint4_t padL;
    uint4_t padU;
    uint16_t INH2;
    uint16_t INW2;
    uint16_t ifm_height;
    uint16_t ofm_height;
    uint8_t n_last_batch;
    uint16_t n_W_round;
    uint16_t row_bound;
    uint16_t col_bound;
    uint16_t vec_size;
    uint16_t vec_size_minus_1;
    uint8_t Xz;
    uint8_t Wz;
    uint8_t Yz;
    uint32_t m1;
    uint8_t n1;
    uint8_t obj1;
    uint8_t obj2;
    uint8_t obj3;
    uint8_t obj4;
};

struct Add {
    uint8_t op_type;
    uint32_t A_addr;
    uint32_t B_addr;
    uint32_t C_addr;
    uint32_t len;
    uint32_t m1;
    uint32_t m2;
    uint8_t n;
    uint8_t Az;
    uint8_t Bz;
    uint8_t Cz;
};

struct Remap {
    uint8_t op_type;
    uint32_t X_addr;
    uint32_t Y_addr;
    uint32_t len;
    uint32_t m1;
    uint8_t n1;
    uint16_t Xz;
    uint8_t Yz;
};

struct End {
    uint8_t op_type;
};

struct Xph {
    uint16_t X_a_;
    uint16_t len_per_chan;
    uint16_t win_x;
    uint16_t win_y;
};

// Read model.yaml and DRAM content files
void Model_load(char* model_dir_path, struct Model* model);
// Print hardware model.
void Model_print(struct Model* model);
// Convert Conv instruction to bytes (64bytes)
void Conv_bytes(struct Conv* ins, uint8_t* dst);
// Convert Add instruction to bytes (64bytes)
void Add_bytes(struct Add* ins, uint8_t* dst);
// Convert Remap instruction to bytes (64bytes)
void Remap_bytes(struct Remap* ins, uint8_t* dst);
// Convert End instruction to bytes (64bytes)
void End_bytes(struct End* ins, uint8_t* dst);
// Generate xphs for the given shape parameters
void gen_Xphs(
    uint32_t INH_, uint32_t INW_, 
    uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
    uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD,
    uint32_t P, uint32_t Q,
    struct Xph* xphs
);
// Convert a batch of Xph into bytes (64bytes/Xph)
void Xphs_bytes(struct Xph* xphs, uint32_t size, uint8_t* dst);

#endif // __BASE_H__
