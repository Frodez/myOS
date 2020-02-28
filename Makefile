.PHONY: refresh_mbr_loader refresh_kernel build clean
#项目路径
path=/home/frodez/myOS
#源文件路径
src_path=${path}/src
#目标文件路径
target_path=${path}/target
#虚拟机路径
vm_path=${path}/vm
#内核入口地址
entry_address=0xc0001500
#nasm及目标格式
nasm_default=nasm -f elf
#gcc默认命令头
gcc_default=gcc -m32
#链接及目标格式
ld_default=ld -m elf_i386
#include宏
dir_includes=${foreach dir, ${shell find ${src_path} -type d}, -I ${dir}}
c_files=${shell find ${src_path} -type f -name "*.c"}

#第一行:目标文件;源文件;其他依赖
#第二行:当目标文件变更时的操作
#$@--目标文件，$^--所有的依赖文件，$<--第一个依赖文件。

#以下为编译和烧录MBR和kernel loader
refresh_mbr_loader:
	
	nasm ${dir_includes} ${src_path}/boot/mbr.s  -o ${target_path}/bin/mbr.bin
	nasm ${dir_includes} ${src_path}/boot/loader.s -o ${target_path}/bin/loader.bin

	#烧录
	dd if=${target_path}/bin/mbr.bin of=${vm_path}/disk.img bs=512 count=1 conv=notrunc
	dd if=${target_path}/bin/loader.bin of=${vm_path}/disk.img bs=512 count=4 seek=2 conv=notrunc

#编译和烧录内核
refresh_kernel:

	#编译和烧录内核
	#c代码部分
	${foreach file, ${c_files}, ${shell ${gcc_default} ${dir_includes} -w -c ${file} -o ${target_path}/kernel/${basename ${notdir ${file}}}.o;}}
	#汇编代码部分
	${nasm_default} ${src_path}/kernel/kernel.s -o ${target_path}/kernel/kernel.o
	${nasm_default} ${src_path}/lib/kernel/print.s -o ${target_path}/kernel/print.o

	find ${target_path} -type f -name "*.o" |xargs ${ld_default} -Ttext 0xc0001500 -e main -o ${target_path}/bin/kernel.bin

	#烧录
	dd if=${target_path}/bin/kernel.bin of=${vm_path}/disk.img bs=512 count=200 seek=9 conv=notrunc

#初始化环境
build:

	#编译和烧录MBR和kernel loader
	nasm ${dir_includes} ${src_path}/boot/mbr.s  -o ${target_path}/bin/mbr.bin
	nasm ${dir_includes} ${src_path}/boot/loader.s -o ${target_path}/bin/loader.bin

	dd if=${target_path}/bin/mbr.bin of=${vm_path}/disk.img bs=512 count=1 conv=notrunc
	dd if=${target_path}/bin/loader.bin of=${vm_path}/disk.img bs=512 count=4 seek=2 conv=notrunc

	#编译和烧录内核
	#c代码部分
	${foreach file, ${c_files}, ${shell ${gcc_default} ${dir_includes} -w -c ${file} -o ${target_path}/kernel/${basename ${notdir ${file}}}.o;}}
	#汇编代码部分
	${nasm_default} ${src_path}/kernel/kernel.s -o ${target_path}/kernel/kernel.o
	${nasm_default} ${src_path}/lib/kernel/print.s -o ${target_path}/kernel/print.o

	find ${target_path} -type f -name "*.o" |xargs ${ld_default} -Ttext 0xc0001500 -e main -o ${target_path}/bin/kernel.bin

	#烧录
	dd if=${target_path}/bin/kernel.bin of=${vm_path}/disk.img bs=512 count=200 seek=9 conv=notrunc

test:
	#编译和烧录MBR和kernel loader
	nasm ${src_path}/boot/mbr.s ${dir_includes} -o ${target_path}/bin/mbr.bin
	nasm ${src_path}/boot/loader.s ${dir_includes} -o ${target_path}/bin/loader.bin

	dd if=${target_path}/bin/mbr.bin of=${vm_path}/disk.img bs=512 count=1 conv=notrunc
	dd if=${target_path}/bin/loader.bin of=${vm_path}/disk.img bs=512 count=4 seek=2 conv=notrunc

	#编译和烧录内核
	${gcc_default} ${dir_includes} -c ${src_path}/kernel/main.c -o ${target_path}/kernel/main.o
	${gcc_default} ${dir_includes} -c ${src_path}/kernel/init.c -o ${target_path}/kernel/init.o
	${gcc_default} ${dir_includes} -c ${src_path}/kernel/interrupt.c -o ${target_path}/kernel/interrupt.o
	${gcc_default} ${dir_includes} -c ${src_path}/device/timer.c -o ${target_path}/kernel/timer.o
	${gcc_default} ${dir_includes} -c ${src_path}/kernel/debug.c -o ${target_path}/kernel/debug.o
	${gcc_default} ${dir_includes} -c ${src_path}/kernel/memory.c -o ${target_path}/kernel/memory.o
	${gcc_default} ${dir_includes} -c ${src_path}/lib/kernel/bitmap.c -o ${target_path}/kernel/bitmap.o
	${gcc_default} ${dir_includes} -c ${src_path}/lib/string.c -o ${target_path}/kernel/string.o

	${nasm_default} ${src_path}/kernel/kernel.s -o ${target_path}/kernel/kernel.o
	${nasm_default} ${src_path}/lib/kernel/print.s -o ${target_path}/kernel/print.o

	find ${target_path} -type f ! -name "*.bin" |xargs ${ld_default} -Ttext 0xc0001500 -e main -o ${target_path}/bin/kernel.bin

	#烧录
	dd if=${target_path}/bin/kernel.bin of=${vm_path}/disk.img bs=512 count=200 seek=9 conv=notrunc

#清理环境
clean:

	#删除target中内容
	find ${target_path} -type f | xargs rm -rf

