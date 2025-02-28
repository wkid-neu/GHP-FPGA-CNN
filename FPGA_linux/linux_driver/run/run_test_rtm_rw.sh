R=16
S=8
n_bytes=0
# [128, 128*65536]
for((i=7;i<24;i++));
do
    n_bytes=$[2**$i]
    echo "----------------------------"
    echo "RTM entries: $[2**($i-7)]"
    ../out/test_rtm_rw --R $R --S $S --rtm_addr 0 --n_bytes $n_bytes
    echo "----------------------------"
done
