#!/bin/bash

export PATH=$PATH:/home/gangdeng/rocksdb-8.9.1/build

if [ "$#" -ne 1 ]; then
  echo "Error: This script requires exactly one parameter."
  exit 1
fi


if [ "$1" -eq 128 ] || [ "$1" -eq 8 ]; then
  echo "Success: The parameter is valid."
else
  echo "Error: The parameter must be 128 or 8."
  exit 1
fi

db_recs=0
val_sz=$1

if [ "$1" -eq 128 ]; then
        db_recs=200000
elif [ "$1" -eq 8 ]; then
        #db_recs=1600000
        db_recs=3200000
fi


nohup db_bench --benchmarks=compact --use_existing_db=0 --disable_wal=1 --sync=0 --threads=64 --num_multi_db=32 --max_background_jobs=64 --max_background_flushes=32 --max_background_compactions=56 --max_write_buffer_number=6 --allow_concurrent_memtable_write=true --level0_file_num_compaction_trigger=1000000 --level0_slowdown_writes_trigger=1000000 --level0_stop_writes_trigger=1000000 --db=/data2/db --wal_dir=/data2/wal --num=${db_recs} --key_size=20 --value_size=$((val_sz * 1024)) --block_size=8192 --cache_size=2147483648 --cache_numshardbits=10 --compression_type=lz4 --min_level_to_compress=2 --bytes_per_sync=2097152 --write_buffer_size=134217728 --target_file_size_base=134217728 --max_bytes_for_level_base=$((256*1024*1024)) --max_bytes_for_level_multiplier=8 --statistics=1 --histogram=1 --report_interval_seconds=1 --stats_interval_seconds=60 --subcompactions=4 --compaction_style=0 --num_levels=8 --level_compaction_dynamic_level_bytes=false --pin_l0_filter_and_index_blocks_in_cache=0 --open_files=65536 --seed=1755087265 > compact_${val_sz}k_${db_recs}.out 2>&1 &
