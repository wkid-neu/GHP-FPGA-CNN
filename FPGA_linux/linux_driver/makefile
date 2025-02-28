test_dram_rw:
	gcc test_dram_rw.c test.c base.c hw.c utils.c -o ./out/test_dram_rw -lm

test_rtm_rw:
	gcc test_rtm_rw.c test.c base.c hw.c utils.c -o ./out/test_rtm_rw -lm

test_remap1:
	gcc test_remap1.c test.c base.c hw.c utils.c -o ./out/test_remap1 -lm

test_remap2:
	gcc test_remap2.c test.c base.c hw.c utils.c -o ./out/test_remap2 -lm

test_add1:
	gcc test_add1.c test.c base.c hw.c utils.c -o ./out/test_add1 -lm

test_add2:
	gcc test_add2.c test.c base.c hw.c utils.c -o ./out/test_add2 -lm

test_fc1:
	gcc test_fc1.c test.c base.c hw.c utils.c -o ./out/test_fc1 -lm

test_fc2:
	gcc test_fc2.c test.c base.c hw.c utils.c -o ./out/test_fc2 -lm

test_maxp1:
	gcc test_maxp1.c test.c base.c hw.c utils.c -o ./out/test_maxp1 -lm

test_maxp2:
	gcc test_maxp2.c test.c base.c hw.c utils.c -o ./out/test_maxp2 -lm

test_avgp1:
	gcc test_avgp1.c test.c base.c hw.c utils.c -o ./out/test_avgp1 -lm

test_avgp2:
	gcc test_avgp2.c test.c base.c hw.c utils.c -o ./out/test_avgp2 -lm

test_conv1:
	gcc test_conv1.c test.c base.c hw.c utils.c -o ./out/test_conv1 -lm

test_conv2:
	gcc test_conv2.c test.c base.c hw.c utils.c -o ./out/test_conv2 -lm

model_e2e_perf:
	gcc model_e2e_perf.c model.c base.c hw.c utils.c -o ./out/model_e2e_perf -lm

model_ins_perf:
	gcc model_ins_perf.c model.c base.c hw.c utils.c -o ./out/model_ins_perf -lm

model_build_db:
	gcc model_build_db.c model.c test.c base.c hw.c utils.c -o ./out/model_build_db -lm

clean: 
	rm -rf out/*
