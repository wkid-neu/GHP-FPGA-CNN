
OC=0
INC=0
for((i=7;i<12;i++));
do
    OC=$[2**$i]
    for((j=5;j<16;j++));
    do
        INC=$[2**$j]
        echo "----------------------------"
        echo "OC: $OC, INC: $INC, t_mode: 0"
        ../out/test_fc2 --OC $OC  --INC $INC --t_mode 0 --test_case_dir_path "/media/fpgagogogo/E1FDBB88D64498E9/program/Python/cnn_accel4/test_case_out/m32p32/fc/${OC}_${INC}/case0/"
        echo "OC: $OC, INC: $INC, t_mode: 1"
        ../out/test_fc2 --OC $OC  --INC $INC --t_mode 1 --test_case_dir_path "/media/fpgagogogo/E1FDBB88D64498E9/program/Python/cnn_accel4/test_case_out/m32p32/fc/${OC}_${INC}/case0/"
        echo "----------------------------"
    done
done

