M=64
P=64
Q=16

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
    test_case_dir_path="/media/fpgagogogo/E1FDBB88D64498E9/program/Python/cnn_accel4/test_case_out/m${M}p${P}/maxp/${OC}_${INC}_${INH_}_${INW_}_${KH}_${KW}_${strideH}_${strideW}_${padL}_${padR}_${padU}_${padD}/case0/"
    echo "----------------------------"
    echo "OC: ${OC}, INC: ${INC}, INH_: ${INH_}, INW_: ${INW_}, KH: ${KH}, KW: ${KW}, strideH: ${strideH}, strideW: ${strideW}, padL: ${padL}, padR: ${padR}, padU: ${padU}, padD: ${padD}"
    ../out/test_maxp2 --M ${M} --P ${P} --Q ${Q} --OC ${OC} --INC ${INC} --INH_ ${INH_} --INW_ ${INW_} --KH ${KH} --KW ${KW} --strideH ${strideH} --strideW ${strideW} --padL ${padL} --padR ${padR} --padU ${padU} --padD ${padD} --test_case_dir_path ${test_case_dir_path}
    echo "----------------------------"
done
