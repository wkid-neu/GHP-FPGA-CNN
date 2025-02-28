R=16
S=8

INC=0
OC=0
for((i=5;i<16;i++));
do
    INC=$[2**$i]
    for((j=7;j<12;j++));
    do
        OC=$[2**$j]
        ../out/test_fc1 --R $R --S $S --OC $OC --INC $INC --t_mode 0
        ../out/test_fc1 --R $R --S $S --OC $OC --INC $INC --t_mode 1
    done
done
