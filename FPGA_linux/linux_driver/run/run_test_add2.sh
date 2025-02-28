vec_size=0
# [128, 128*65536]
for((i=7;i<23;i++));
do
    vec_size=$[2**$i]
    echo "----------------------------"
    echo "RTM entries: $[2**($i-7)]"
    ../out/test_add2 --vec_size $vec_size --test_case_dir_path "/media/fpgagogogo/E1FDBB88D64498E9/program/Python/cnn_accel4/test_case_out/m32p32/add/${vec_size}/case0/"
    echo "----------------------------"
done
