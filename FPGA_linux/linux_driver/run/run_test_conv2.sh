M=32
P=96
Q=16

arr=(\
    32 4 112 112 3 3 2 2 0 0 0 0 \
    64 4 112 112 3 3 2 2 0 0 0 0 \
    64 4 224 224 3 3 2 2 0 0 0 0 \
    64 4 224 224 3 3 2 2 1 1 1 1 \
    64 4 224 224 7 7 2 2 3 3 3 3 \
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
    test_case_dir_path="/media/fpgagogogo/E1FDBB88D64498E9/program/Python/cnn_accel4/test_case_out/m${M}p${P}/conv/${OC}_${INC}_${INH_}_${INW_}_${KH}_${KW}_${strideH}_${strideW}_${padL}_${padR}_${padU}_${padD}/case0/"
    echo "----------------------------"
    echo "OC: ${OC}, INC: ${INC}, INH_: ${INH_}, INW_: ${INW_}, KH: ${KH}, KW: ${KW}, strideH: ${strideH}, strideW: ${strideW}, padL: ${padL}, padR: ${padR}, padU: ${padU}, padD: ${padD}"
    echo "static mode"
    ../out/test_conv2 --M ${M} --P ${P} --Q ${Q} --OC ${OC} --INC ${INC} --INH_ ${INH_} --INW_ ${INW_} --KH ${KH} --KW ${KW} --strideH ${strideH} --strideW ${strideW} --padL ${padL} --padR ${padR} --padU ${padU} --padD ${padD} --sta_mode 1 --test_case_dir_path ${test_case_dir_path}
    echo "dynamic mode"
    ../out/test_conv2 --M ${M} --P ${P} --Q ${Q} --OC ${OC} --INC ${INC} --INH_ ${INH_} --INW_ ${INW_} --KH ${KH} --KW ${KW} --strideH ${strideH} --strideW ${strideW} --padL ${padL} --padR ${padR} --padU ${padU} --padD ${padD} --sta_mode 0 --test_case_dir_path ${test_case_dir_path}
    echo "----------------------------"
done
