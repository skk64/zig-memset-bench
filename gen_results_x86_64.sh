hyperfine --warmup 3 \
-L memset libc,glibc_avx2,skk64,builtin \
-L len 1,2,3,4,5,6,7,8,9,10,12,14,16,18,20,24,28,32,50,100,200,400,800 \
'./zig-out/bin/memset_bench {memset} 500_000_000 {len}' \
--export-csv results.csv

# -L memset libc,glibc_avx2,skk64,rpkak,builtin,musl_asm,basic \
