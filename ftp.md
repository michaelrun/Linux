# clone FTP directory to local
lftp -c 'mirror --parallel=30 http://vt-nfs.sh.intel.com/Tools/Performance%20Benchmark/specjbb/'
