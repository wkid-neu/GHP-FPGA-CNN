R=16
S=8
vec_size=0
# [128, 128*65536]
for((i=7;i<23;i++));
do
    vec_size=$[2**$i]
    echo "----------------------------"
    echo "RTM entries: $[2**($i-7)]"
    ../out/test_add1 --R $R --S $S --vec_size $vec_size 
    echo "----------------------------"
done
