size=0
for((i=6;i<27;i++));
do
    size=$[2**$i]
    echo "----------------------------"
    ../out/test_dram_rw --addr $[16#80000000] --size $size
    echo "----------------------------"
done
echo "Done"
