#!/usr/bin/env bash

# Copyright (c) 2018, University of Kaiserslautern
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER
# OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# Author: Éder F. Zulian

DIR="$(cd "$(dirname "$0")" && pwd)"
TOPDIR=$DIR/../..
source $TOPDIR/common/defaults.in
source $TOPDIR/common/util.in

# Set to "yes" or "no" in order to enable a spinner or not.
spinner="no"

sysver=20180409
imgdir="$FSDIRARM/aarch-system-${sysver}/disks"
bmsuite="stream"
img="$imgdir/linaro-minimal-aarch64-${bmsuite}-inside.img"
bmsuiteroot="home"

arch="ARM"
mode="opt"
gem5_elf="build/$arch/gem5.$mode"
cd $ROOTDIR/gem5
if [[ ! -e $gem5_elf ]]; then
	build_gem5 $arch $mode
fi

currtime=$(date "+%Y.%m.%d-%H.%M.%S")
output_rootdir="fs_output_${bmsuite}_$currtime"
config_script="configs/example/arm/starter_fs.py"
ncores="1"
cpu_options="--cpu=hpi --num-cores=$ncores"
mem_options="--mem-size=1GB"
#tlm_options="--tlm-memory=transactor"
disk_options="--disk-image=$img"
kernel="--kernel=$FSDIRARM/aarch-system-${sysver}/binaries/vmlinux.vexpress_gem5_v1_64"
dtb="--dtb=$FSDIRARM/aarch-system-${sysver}/binaries/armv8_gem5_v1_${ncores}cpu.dtb"

benchmark_progs="
stream/stream_c.exe
"

bootscript="${bmsuite}_${ncores}_cores.rcS"
printf '#!/bin/bash\n' > $bootscript
printf "declare -a pids\n" >> $bootscript
printf "cd $bmsuiteroot\n" >> $bootscript
for b in $benchmark_progs; do
	printf "echo \"Starting $b in background...\"\n" >> $bootscript
	printf "$b & pids+=(\$!)\n" >> $bootscript
	printf "echo \"$b started\"\n" >> $bootscript
done
printf 'echo "Waiting..."\n' >> $bootscript
printf 'wait "${pids[@]}"\n' >> $bootscript
printf 'unset pids\n' >> $bootscript
printf 'echo "All benchmark programs finished. Hurray!"\n' >> $bootscript
printf 'echo "Calling m5 exit in 1 second from now..."\n' >> $bootscript
printf 'sleep 1\n' >> $bootscript
printf 'm5 exit\n' >> $bootscript


# start spinner
if [ "$spinner" = "yes" ]; then
	pulse &
	pupid=$!
fi

bootscript_options="--script=$ROOTDIR/gem5/$bootscript"
output_dir="$output_rootdir/${bmsuite}_${ncores}_cores"
mkdir -p ${output_dir}
logfile=${output_dir}/gem5.log
export M5_PATH="$FSDIRARM/aarch-system-${sysver}":${M5_PATH}
$gem5_elf -d $output_dir $config_script $cpu_options $mem_options $tlm_options $kernel $dtb $disk_options $bootscript_options > $logfile 2>&1 &
wait

# stop spinner
if [ "$spinner" = "yes" ]; then
	kill $pupid &>/dev/null
fi
