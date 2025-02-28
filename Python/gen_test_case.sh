export PYTHONPATH=./

m32p32_conv=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m32p32/conv/
m32p64_conv=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m32p64/conv/
m32p96_conv=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m32p96/conv/
m64p64_conv=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m64p64/conv/
m32p32_maxp=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m32p32/maxp/
m32p64_maxp=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m32p64/maxp/
m32p96_maxp=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m32p96/maxp/
m64p64_maxp=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m64p64/maxp/
m32p32_avgp=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m32p32/avgp/
m32p64_avgp=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m32p64/avgp/
m32p96_avgp=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m32p96/avgp/
m64p64_avgp=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m64p64/avgp/
m32p32_remap=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m32p32/remap/
m32p64_remap=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m32p64/remap/
m32p96_remap=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m32p96/remap/
m64p64_remap=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m64p64/remap/
m32p32_add=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m32p32/add/
m32p64_add=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m32p64/add/
m32p96_add=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m32p96/add/
m64p64_add=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m64p64/add/
m32p32_fc=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m32p32/fc/
m32p64_fc=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m32p64/fc/
m32p96_fc=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m32p96/fc/
m64p64_fc=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/test_case_out/m64p64/fc/

# python3 ./test_case/conv.py --db_dir_path $m32p32_conv --M 32 --P 32 --Q 16 --OC 1024 --INC 1280 --INH_ 4 --INW_ 4 --KH 1 --KW 1 --strideH 1 --strideW 1 --padL 0 --padR 0 --padU 0 --padD 0
# python3 ./test_case/conv.py --db_dir_path $m32p64_conv --M 32 --P 64 --Q 16 --OC 64 --INC 4 --INH_ 112 --INW_ 112 --KH 3 --KW 3 --strideH 2 --strideW 2 --padL 0 --padR 0 --padU 0 --padD 0
# python3 ./test_case/conv.py --db_dir_path $m32p96_conv --M 32 --P 96 --Q 16 --OC 64 --INC 4 --INH_ 112 --INW_ 112 --KH 3 --KW 3 --strideH 2 --strideW 2 --padL 0 --padR 0 --padU 0 --padD 0
# python3 ./test_case/conv.py --db_dir_path $m64p64_conv --M 64 --P 64 --Q 16 --OC 32 --INC 4 --INH_ 112 --INW_ 112 --KH 3 --KW 3 --strideH 2 --strideW 2 --padL 0 --padR 0 --padU 0 --padD 0

# python3 ./test_case/maxp.py --db_dir_path $m32p32_maxp --M 32 --P 32 --Q 16 --OC 128 --INC 128 --INH_ 32 --INW_ 32 --KH 2 --KW 2 --strideH 2 --strideW 2 --padL 0 --padR 0 --padU 0 --padD 0
# python3 ./test_case/maxp.py --db_dir_path $m32p64_maxp --M 32 --P 64 --Q 16 --OC 128 --INC 128 --INH_ 32 --INW_ 32 --KH 2 --KW 2 --strideH 2 --strideW 2 --padL 0 --padR 0 --padU 0 --padD 0
# python3 ./test_case/maxp.py --db_dir_path $m32p96_maxp --M 32 --P 96 --Q 16 --OC 128 --INC 128 --INH_ 32 --INW_ 32 --KH 2 --KW 2 --strideH 2 --strideW 2 --padL 0 --padR 0 --padU 0 --padD 0
# python3 ./test_case/maxp.py --db_dir_path $m64p64_maxp --M 64 --P 64 --Q 16 --OC 128 --INC 128 --INH_ 32 --INW_ 32 --KH 2 --KW 2 --strideH 2 --strideW 2 --padL 0 --padR 0 --padU 0 --padD 0

arr=(\
    4 4 4 4 2 2 2 2 0 0 0 0 \
    8 8 4 4 2 2 2 2 0 0 0 0 \
    4 4 6 6 2 2 2 2 0 0 0 0 \
    8 8 6 6 2 2 2 2 0 0 0 0 \
    32 32 14 14 3 3 1 1 1 1 1 1 \
    32 32 16 16 2 2 2 2 0 0 0 0 \
    64 64 55 55 3 3 2 2 0 0 0 0 \
    64 64 112 112 3 3 2 2 1 1 1 1 \
    64 64 224 224 2 2 2 2 0 0 0 0 \
    96 96 109 109 3 3 2 2 0 0 0 0 \
    128 128 56 56 3 3 2 2 0 1 0 1 \
    128 128 112 112 2 2 2 2 0 0 0 0 \
    192 192 27 27 3 3 2 2 0 0 0 0 \
    256 256 13 13 3 3 2 2 0 0 0 0 \
    256 256 28 28 3 3 2 2 0 1 0 1 \
    256 256 56 56 2 2 2 2 0 0 0 0 \
    384 384 54 54 3 3 2 2 0 1 0 1 \
    384 384 14 14 3 3 2 2 0 1 0 1 \
    512 512 7 7 7 7 1 1 0 0 0 0 \
    512 512 14 14 2 2 2 2 0 0 0 0 \
    512 512 28 28 2 2 2 2 0 0 0 0 \
    768 768 27 27 3 3 2 2 0 0 0 0 \
    1000 1000 13 13 13 13 1 1 0 0 0 0 \
    1024 1024 4 4 4 4 1 1 0 0 0 0 \
    2048 2048 7 7 7 7 1 1 0 0 0 0 \
)

n_test_case=$[${#arr[*]}/12]
for((i=0;i<$n_test_case;i++));
do
    OC=${arr[$i*12]}
    INC=${arr[$i*12+1]}
    INH_=${arr[$i*12+2]}
    INW_=${arr[$i*12+3]}
    KH=${arr[$i*12+4]}
    KW=${arr[$i*12+5]}
    strideH=${arr[$i*12+6]}
    strideW=${arr[$i*12+7]}
    padL=${arr[$i*12+8]}
    padR=${arr[$i*12+9]}
    padU=${arr[$i*12+10]}
    padD=${arr[$i*12+11]}
    echo "----------------------------"
    echo "OC: ${OC}, INC: ${INC}, INH_: ${INH_}, INW_: ${INW_}, KH: ${KH}, KW: ${KW}, strideH: ${strideH}, strideW: ${strideW}, padL: ${padL}, padR: ${padR}, padU: ${padU}, padD: ${padD}"
    echo "M32P32"
    python3 ./test_case/avgp.py --db_dir_path $m32p32_avgp --M 32 --P 32 --Q 16 --OC ${OC} --INC ${INC} --INH_ ${INH_} --INW_ ${INW_} --KH ${KH} --KW ${KW} --strideH ${strideH} --strideW ${strideW} --padL ${padL} --padR ${padR} --padU ${padU} --padD ${padD}
    echo "M32P64"
    python3 ./test_case/avgp.py --db_dir_path $m32p64_avgp --M 32 --P 64 --Q 16 --OC ${OC} --INC ${INC} --INH_ ${INH_} --INW_ ${INW_} --KH ${KH} --KW ${KW} --strideH ${strideH} --strideW ${strideW} --padL ${padL} --padR ${padR} --padU ${padU} --padD ${padD}
    echo "M32P96"
    python3 ./test_case/avgp.py --db_dir_path $m32p96_avgp --M 32 --P 96 --Q 16 --OC ${OC} --INC ${INC} --INH_ ${INH_} --INW_ ${INW_} --KH ${KH} --KW ${KW} --strideH ${strideH} --strideW ${strideW} --padL ${padL} --padR ${padR} --padU ${padU} --padD ${padD}
    echo "M64P64"
    python3 ./test_case/avgp.py --db_dir_path $m64p64_avgp --M 64 --P 64 --Q 16 --OC ${OC} --INC ${INC} --INH_ ${INH_} --INW_ ${INW_} --KH ${KH} --KW ${KW} --strideH ${strideH} --strideW ${strideW} --padL ${padL} --padR ${padR} --padU ${padU} --padD ${padD}
    echo "----------------------------"
done

# python3 ./test_case/avgp.py --db_dir_path $m32p32_avgp --M 32 --P 32 --Q 16 --OC 32 --INC 32 --INH_ 18 --INW_ 18 --KH 2 --KW 2 --strideH 2 --strideW 2 --padL 0 --padR 0 --padU 0 --padD 0
# python3 ./test_case/avgp.py --db_dir_path $m32p64_avgp --M 32 --P 64 --Q 16 --OC 32 --INC 32 --INH_ 18 --INW_ 18 --KH 2 --KW 2 --strideH 2 --strideW 2 --padL 0 --padR 0 --padU 0 --padD 0
# python3 ./test_case/avgp.py --db_dir_path $m32p96_avgp --M 32 --P 96 --Q 16 --OC 32 --INC 32 --INH_ 18 --INW_ 18 --KH 2 --KW 2 --strideH 2 --strideW 2 --padL 0 --padR 0 --padU 0 --padD 0
# python3 ./test_case/avgp.py --db_dir_path $m64p64_avgp --M 64 --P 64 --Q 16 --OC 32 --INC 32 --INH_ 18 --INW_ 18 --KH 2 --KW 2 --strideH 2 --strideW 2 --padL 0 --padR 0 --padU 0 --padD 0

# python3 ./test_case/remap.py --db_dir_path $m32p32_remap --vec_size 65536

# python3 ./test_case/add.py --db_dir_path $m32p32_add --vec_size 262144

# python3 ./test_case/fc.py --db_dir_path $m32p32_fc --OC 128 --INC 16
