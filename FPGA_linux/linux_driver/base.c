#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include "base.h"
#include "utils.h"

static void parse_model_file(char* model_dir_path, struct Model* model) {
    char fp [1024];

    sprintf(fp, "%smodel.yaml", model_dir_path);
    FILE* f = fopen(fp, "r");
    if (f == NULL) {
        printf("Open file failed, file_path: %s\n", fp);
        exit(-1);
    }

    fscanf(f, "sta_conv_weight_ddr_addr: %u\n", &model->sta_conv_weight_ddr_addr);
    fscanf(f, "sta_conv_weight_ddr_len: %u\n", &model->sta_conv_weight_ddr_len);
    fscanf(f, "dyn_conv_weight_ddr_addr: %u\n", &model->dyn_conv_weight_ddr_addr);
    fscanf(f, "dyn_conv_weight_ddr_len: %u\n", &model->dyn_conv_weight_ddr_len);
    fscanf(f, "fc_weight_ddr_addr: %u\n", &model->fc_weight_ddr_addr);
    fscanf(f, "fc_weight_ddr_len: %u\n", &model->fc_weight_ddr_len);
    fscanf(f, "bias_ddr_addr: %u\n", &model->bias_ddr_addr);
    fscanf(f, "bias_ddr_len: %u\n", &model->bias_ddr_len);
    fscanf(f, "ins_ddr_addr: %u\n", &model->ins_ddr_addr);
    fscanf(f, "ins_ddr_len: %u\n", &model->ins_ddr_len);
    fscanf(f, "xphs_ddr_addr: %u\n", &model->xphs_ddr_addr);
    fscanf(f, "xphs_ddr_len: %u\n", &model->xphs_ddr_len);
    fscanf(f, "input_ddr_addr: %u\n", &model->input_ddr_addr);
    fscanf(f, "input_ddr_len: %u\n", &model->input_ddr_len);
    fscanf(f, "input_rtm_addr: %u\n", &model->input_rtm_addr);
    fscanf(f, "output_ddr_addr: %u\n", &model->output_ddr_addr);
    fscanf(f, "output_ddr_len: %u\n", &model->output_ddr_len);
    fscanf(f, "output_rtm_addr: %u\n", &model->output_rtm_addr);
    fscanf(f, "output_rtm_mode: %s\n", (char*)(&model->output_rtm_mode));
    fscanf(f, "input_n_chan: %u\n", &model->input_n_chan);
    fscanf(f, "input_height: %u\n", &model->input_height);
    fscanf(f, "input_width: %u\n", &model->input_width);
    fscanf(f, "input_s: %f\n", &model->input_s);
    fscanf(f, "input_z: %hhd\n", &model->input_z);
    fscanf(f, "output_s: %f\n", &model->output_s);
    fscanf(f, "output_z: %hhd\n", &model->output_z);

    fclose(f);
}

static void load_sta_conv_weights(char* model_dir_path, struct Model* model) {
    char fp [1024];
    sprintf(fp, "%ssta_conv_weights.hex", model_dir_path);
    if (model->sta_conv_weight_ddr_len > 0) {
        posix_memalign((void **)&model->sta_conv_weights, 4096, model->sta_conv_weight_ddr_len);
        rd_hex_file(fp, model->sta_conv_weights);
    } else {
        model->sta_conv_weights = NULL;
    }
}

static void load_dyn_conv_weights(char* model_dir_path, struct Model* model) {
    char fp [1024];
    sprintf(fp, "%sdyn_conv_weights.hex", model_dir_path);
    if (model->dyn_conv_weight_ddr_len > 0) {
        posix_memalign((void **)&model->dyn_conv_weights, 4096, model->dyn_conv_weight_ddr_len);
        rd_hex_file(fp, model->dyn_conv_weights);
    } else {
        model->dyn_conv_weights = NULL;
    }
}

static void load_fc_weights(char* model_dir_path, struct Model* model) {
    char fp [1024];
    sprintf(fp, "%sfc_weights.hex", model_dir_path);
    if (model->fc_weight_ddr_len > 0) {
        posix_memalign((void **)&model->fc_weights, 4096, model->fc_weight_ddr_len);
        rd_hex_file(fp, model->fc_weights);
    } else {
        model->fc_weights = NULL;
    }
}

static void load_bias(char* model_dir_path, struct Model* model) {
    char fp [1024];
    sprintf(fp, "%sbias.hex", model_dir_path);
    if (model->bias_ddr_len > 0) {
        posix_memalign((void **)&model->bias, 4096, model->bias_ddr_len);
        rd_hex_file(fp, model->bias);
    } else {
        model->bias = NULL;
    }
}

static void load_ins(char* model_dir_path, struct Model* model) {
    char fp [1024];
    sprintf(fp, "%sins.hex", model_dir_path);
    posix_memalign((void **)&model->ins, 4096, model->ins_ddr_len);
    rd_hex_file(fp, model->ins);
}

static void load_xphs(char* model_dir_path, struct Model* model) {
    char fp [1024];
    sprintf(fp, "%sxphs.hex", model_dir_path);
    if (model->xphs_ddr_len > 0) {
        posix_memalign((void **)&model->xphs, 4096, model->xphs_ddr_len);
        rd_hex_file(fp, model->xphs);
    } else {
        model->xphs = NULL;
    }
}

void Model_load(char* model_dir_path, struct Model* model) {
    /* Parse the model.yaml file. */
    parse_model_file(model_dir_path, model);
    /* Load sta_conv_weights */
    load_sta_conv_weights(model_dir_path, model);
    /* Load dyn_conv_weights */
    load_dyn_conv_weights(model_dir_path, model);
    /* Load fc_weights */
    load_fc_weights(model_dir_path, model);
    /* Load bias */
    load_bias(model_dir_path, model);
    /* Load instructions */
    load_ins(model_dir_path, model);
    /* Load xphs */
    load_xphs(model_dir_path, model);
}

void Model_print(struct Model* model) {
    printf("sta_conv_weight_ddr_addr: %u\n", model->sta_conv_weight_ddr_addr);
    printf("sta_conv_weight_ddr_len: %u\n", model->sta_conv_weight_ddr_len);
    printf("dyn_conv_weight_ddr_addr: %u\n", model->dyn_conv_weight_ddr_addr);
    printf("dyn_conv_weight_ddr_len: %u\n", model->dyn_conv_weight_ddr_len);
    printf("fc_weight_ddr_addr: %u\n", model->fc_weight_ddr_addr);
    printf("fc_weight_ddr_len: %u\n", model->fc_weight_ddr_len);
    printf("bias_ddr_addr: %u\n", model->bias_ddr_addr);
    printf("bias_ddr_len: %u\n", model->bias_ddr_len);
    printf("ins_ddr_addr: %u\n", model->ins_ddr_addr);
    printf("ins_ddr_len: %u\n", model->ins_ddr_len);
    printf("xphs_ddr_addr: %u\n", model->xphs_ddr_addr);
    printf("xphs_ddr_len: %u\n", model->xphs_ddr_len);
    printf("input_ddr_addr: %u\n", model->input_ddr_addr);
    printf("input_ddr_len: %u\n", model->input_ddr_len);
    printf("input_rtm_addr: %u\n", model->input_rtm_addr);
    printf("output_ddr_addr: %u\n", model->output_ddr_addr);
    printf("output_ddr_len: %u\n", model->output_ddr_len);
    printf("output_rtm_addr: %u\n", model->output_rtm_addr);
    printf("output_rtm_mode: %s\n", model->output_rtm_mode);
    printf("input_n_chan: %u\n", model->input_n_chan);
    printf("input_height: %u\n", model->input_height);
    printf("input_width: %u\n", model->input_width);
    printf("input_s: %.7f\n", model->input_s);
    printf("input_z: %d\n", model->input_z);
    printf("output_s: %.7f\n", model->output_s);
    printf("output_z: %d\n", model->output_z);
}

void Conv_bytes(struct Conv* ins, uint8_t* dst) {
    uint8_t list [64];
    for (int i=0; i<64; i++)
        list[i] = 0;

    int ptr = 0;
    list[ptr] = ins->op_type; ptr++;
    list[ptr] = ins->xphs_addr&0x00ff; ptr++; list[ptr] = (ins->xphs_addr&0xff00)>>8; ptr++; 
    list[ptr] = ins->xphs_len&0x00ff; ptr++; list[ptr] = (ins->xphs_len&0xff00)>>8; ptr++;
    list[ptr] = ins->W_addr&0x000000ff; ptr++; list[ptr] = (ins->W_addr&0x0000ff00)>>8; ptr++; list[ptr] = (ins->W_addr&0x00ff0000)>>16; ptr++; list[ptr] = (ins->W_addr&0xff000000)>>24; ptr++;
    list[ptr] = ins->W_n_bytes&0x000000ff; ptr++; list[ptr] = (ins->W_n_bytes&0x0000ff00)>>8; ptr++; list[ptr] = (ins->W_n_bytes&0x00ff0000)>>16; ptr++; list[ptr] = (ins->W_n_bytes&0xff000000)>>24; ptr++;
    list[ptr] = ins->B_addr&0x00ff; ptr++; list[ptr] = (ins->B_addr&0xff00)>>8; ptr++;
    list[ptr] = ins->X_addr&0x000000ff; ptr++; list[ptr] = (ins->X_addr&0x0000ff00)>>8; ptr++; list[ptr] = (ins->X_addr&0x00ff0000)>>16; ptr++; list[ptr] = (ins->X_addr&0xff000000)>>24; ptr++;
    list[ptr] = ins->Y_addr&0x000000ff; ptr++; list[ptr] = (ins->Y_addr&0x0000ff00)>>8; ptr++; list[ptr] = (ins->Y_addr&0x00ff0000)>>16; ptr++; list[ptr] = (ins->Y_addr&0xff000000)>>24; ptr++;
    list[ptr] = ins->OC&0x00ff; ptr++; list[ptr] = (ins->OC&0xff00)>>8; ptr++;
    list[ptr] = ins->INC&0x00ff; ptr++; list[ptr] = (ins->INC&0xff00)>>8; ptr++;
    list[ptr] = ins->INW_&0x00ff; ptr++; list[ptr] = (ins->INW_&0xff00)>>8; ptr++;
    list[ptr] = ins->KH; ptr++;
    list[ptr] = ins->KW; ptr++;
    list[ptr] = (ins->strideW<<4)+ins->strideH; ptr++;
    list[ptr] = (ins->padU<<4)+ins->padL; ptr++;
    list[ptr] = ins->INH2&0x00ff; ptr++; list[ptr] = (ins->INH2&0xff00)>>8; ptr++;
    list[ptr] = ins->INW2&0x00ff; ptr++; list[ptr] = (ins->INW2&0xff00)>>8; ptr++;
    list[ptr] = ins->ifm_height&0x00ff; ptr++; list[ptr] = (ins->ifm_height&0xff00)>>8; ptr++;
    list[ptr] = ins->ofm_height&0x00ff; ptr++; list[ptr] = (ins->ofm_height&0xff00)>>8; ptr++;
    list[ptr] = ins->n_last_batch; ptr++;
    list[ptr] = ins->n_W_round&0x00ff; ptr++; list[ptr] = (ins->n_W_round&0xff00)>>8; ptr++;
    list[ptr] = ins->row_bound&0x00ff; ptr++; list[ptr] = (ins->row_bound&0xff00)>>8; ptr++;
    list[ptr] = ins->col_bound&0x00ff; ptr++; list[ptr] = (ins->col_bound&0xff00)>>8; ptr++;
    list[ptr] = ins->vec_size&0x00ff; ptr++; list[ptr] = (ins->vec_size&0xff00)>>8; ptr++;
    list[ptr] = ins->vec_size_minus_1&0x00ff; ptr++; list[ptr] = (ins->vec_size_minus_1&0xff00)>>8; ptr++;
    list[ptr] = ins->Xz; ptr++;
    list[ptr] = ins->Wz; ptr++;
    list[ptr] = ins->Yz; ptr++;
    list[ptr] = ins->m1&0x000000ff; ptr++; list[ptr] = (ins->m1&0x0000ff00)>>8; ptr++; list[ptr] = (ins->m1&0x00ff0000)>>16; ptr++; list[ptr] = (ins->m1&0xff000000)>>24; ptr++;
    list[ptr] = ins->n1; ptr++;
    list[ptr] = ins->obj1; ptr++;
    list[ptr] = ins->obj2; ptr++;
    list[ptr] = ins->obj3; ptr++;
    list[ptr] = ins->obj4;

    for (int i=0; i<64; i++) 
        dst[i] = list[i];
}

void Add_bytes(struct Add* ins, uint8_t* dst) {
    uint8_t list [64];
    for (int i=0; i<64; i++)
        list[i] = 0;
    
    int ptr = 0;
    list[ptr] = ins->op_type; ptr++;
    list[ptr] = ins->A_addr&0x000000ff; ptr++; list[ptr] = (ins->A_addr&0x0000ff00)>>8; ptr++; list[ptr] = (ins->A_addr&0x00ff0000)>>16; ptr++; list[ptr] = (ins->A_addr&0xff000000)>>24; ptr++;
    list[ptr] = ins->B_addr&0x000000ff; ptr++; list[ptr] = (ins->B_addr&0x0000ff00)>>8; ptr++; list[ptr] = (ins->B_addr&0x00ff0000)>>16; ptr++; list[ptr] = (ins->B_addr&0xff000000)>>24; ptr++;
    list[ptr] = ins->C_addr&0x000000ff; ptr++; list[ptr] = (ins->C_addr&0x0000ff00)>>8; ptr++; list[ptr] = (ins->C_addr&0x00ff0000)>>16; ptr++; list[ptr] = (ins->C_addr&0xff000000)>>24; ptr++;
    list[ptr] = ins->len&0x000000ff; ptr++; list[ptr] = (ins->len&0x0000ff00)>>8; ptr++; list[ptr] = (ins->len&0x00ff0000)>>16; ptr++; list[ptr] = (ins->len&0xff000000)>>24; ptr++;
    list[ptr] = ins->m1&0x000000ff; ptr++; list[ptr] = (ins->m1&0x0000ff00)>>8; ptr++; list[ptr] = (ins->m1&0x00ff0000)>>16; ptr++; list[ptr] = (ins->m1&0xff000000)>>24; ptr++;
    list[ptr] = ins->m2&0x000000ff; ptr++; list[ptr] = (ins->m2&0x0000ff00)>>8; ptr++; list[ptr] = (ins->m2&0x00ff0000)>>16; ptr++; list[ptr] = (ins->m2&0xff000000)>>24; ptr++;
    list[ptr] = ins->n; ptr++;
    list[ptr] = ins->Az; ptr++;
    list[ptr] = ins->Bz; ptr++;
    list[ptr] = ins->Cz;

    for (int i=0; i<64; i++) 
        dst[i] = list[i];
}

void Remap_bytes(struct Remap* ins, uint8_t* dst) {
    uint8_t list [64];
    for (int i=0; i<64; i++)
        list[i] = 0;

    int ptr = 0;
    list[ptr] = ins->op_type; ptr++;
    list[ptr] = ins->X_addr&0x000000ff; ptr++; list[ptr] = (ins->X_addr&0x0000ff00)>>8; ptr++; list[ptr] = (ins->X_addr&0x00ff0000)>>16; ptr++; list[ptr] = (ins->X_addr&0xff000000)>>24; ptr++;
    list[ptr] = ins->Y_addr&0x000000ff; ptr++; list[ptr] = (ins->Y_addr&0x0000ff00)>>8; ptr++; list[ptr] = (ins->Y_addr&0x00ff0000)>>16; ptr++; list[ptr] = (ins->Y_addr&0xff000000)>>24; ptr++;
    list[ptr] = ins->len&0x000000ff; ptr++; list[ptr] = (ins->len&0x0000ff00)>>8; ptr++; list[ptr] = (ins->len&0x00ff0000)>>16; ptr++; list[ptr] = (ins->len&0xff000000)>>24; ptr++;
    list[ptr] = ins->m1&0x000000ff; ptr++; list[ptr] = (ins->m1&0x0000ff00)>>8; ptr++; list[ptr] = (ins->m1&0x00ff0000)>>16; ptr++; list[ptr] = (ins->m1&0xff000000)>>24; ptr++;
    list[ptr] = ins->n1; ptr++;
    list[ptr] = ins->Xz&0x00ff; ptr++; list[ptr] = (ins->Xz&0xff00)>>8; ptr++;
    list[ptr] = ins->Yz;

    for (int i=0; i<64; i++) 
        dst[i] = list[i];
}

void End_bytes(struct End* ins, uint8_t* dst) {
    uint8_t list [64];
    for (int i=0; i<64; i++)
        list[i] = 0;

    list[0] = ins->op_type;

    for (int i=0; i<64; i++) 
        dst[i] = list[i];
}

void gen_Xphs(
    uint32_t INH_, uint32_t INW_, 
    uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
    uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD,
    uint32_t P, uint32_t Q,
    struct Xph* xphs
) {
    /* Output feature map shape. */
    uint32_t OH, OW;
    conv_get_ofm_shape(
        INH_, INW_, KH, KW, strideH, strideW,
        padL, padR, padU, padD,
        &OH, &OW
    );
    /* Generate header for each round. */
    uint32_t n_x_rnd = (uint32_t)(ceil(OH*OW*1.0/P));
    for (uint32_t x_rnd=0; x_rnd<n_x_rnd; x_rnd++) {
        struct Xph* xph = xphs + x_rnd;
        int in_pos_start = INT32_MAX, in_pos_end = INT32_MIN;
        for (int p=0; p<P; p++) {
            int out_pos = x_rnd*P+p;
            if (out_pos > OH*OW-1) 
                out_pos = OH*OW-1;
            int out_row = out_pos/OW, out_col = out_pos%OW;
            int win_y = out_row*strideH, win_x = out_col*strideW;
            if (p==0) {
                xph->win_x = win_x;
                xph->win_y = win_y;
            }
            for (int kh=0; kh<KH; kh++) {
                for (int kw=0; kw<KW; kw++) {
                    int x = win_x+kw, y = win_y+kh;
                    int x_ = x-padL, y_ = y-padU;
                    if (x_<0 || x_>INW_-1 || y_<0 || y_>INH_-1)
                        continue;
                    int in_pos = y_*INW_+x_;
                    if (in_pos < in_pos_start) 
                        in_pos_start = in_pos;
                    if (in_pos > in_pos_end)
                        in_pos_end = in_pos;
                }
            }
        }
        int start_a_ = in_pos_start/Q;
        int start_b_ = in_pos_start%Q;
        int end_a_ = in_pos_end/Q;
        int end_b_ = in_pos_end%Q;
        xph->X_a_ = start_a_;
        xph->len_per_chan = end_a_-start_a_+1;
    }
}

void Xphs_bytes(struct Xph* xphs, uint32_t size, uint8_t* dst) {
    uint8_t list [64];
    int ptr = 0;
    struct Xph* xph;
    for (uint32_t i=0; i<size; i++) {
        xph = xphs + i;
        for (int j=0; j<64; j++)
            list[j] = 0;
        
        ptr = 0;
        list[ptr] = xph->X_a_&0x00ff; ptr++; list[ptr] = (xph->X_a_&0xff00)>>8; ptr++;
        list[ptr] = xph->len_per_chan&0x00ff; ptr++; list[ptr] = (xph->len_per_chan&0xff00)>>8; ptr++;
        list[ptr] = xph->win_x&0x00ff; ptr++; list[ptr] = (xph->win_x&0xff00)>>8; ptr++;
        list[ptr] = xph->win_y&0x00ff; ptr++; list[ptr] = (xph->win_y&0xff00)>>8; ptr++;

        for (int j=0; j<64; j++)
            dst[i*64+j] = list[j];
    }
}
