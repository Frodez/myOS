.PHONY: refresh_mbr_loader refresh_kernel build clean
#项目路径
path=/home/frodez/myOS
#源文件路径
src_path=${path}/src
#源文件目录
src_dirs=${shell find ${src_path} -type d}
#目标文件路径
target_path=${path}/target
#目标文件目录
target_dirs=${shell find ${target_path} -type d}
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
#源文件
sources=${shell find ${src_path} -type f}
#include宏
macro_includes=${foreach dir, ${src_dirs}, -I ${dir}}

#第一行:目标文件;源文件;其他依赖
#第二行:当目标文件变更时的操作
#$@--目标文件，$^--所有的依赖文件，$<--第一个依赖文件。

#以下为编译和烧录MBR和kernel loader
refresh_mbr_loader: ${sources}
	
	nasm ${macro_includes} $< -o $@

	nasm ${macro_includes} $< -o $@

	#烧录
	dd if=${target_path}/bin/mbr.bin of=${vm_path}/disk.img bs=512 count=1 conv=notrunc

	dd if=${target_path}/bin/loader.bin of=${vm_path}/disk.img bs=512 count=4 seek=2 conv=notrunc

#编译和烧录内核
refresh_kernel: ${sources}

	#c代码编译部分
	${gcc_default} ${macro_includes} -c ${src_path}/kernel/main.c -o ${target_path}/kernel/main.o

	${gcc_default} ${macro_includes} -c ${src_path}/kernel/init.c -o ${target_path}/kernel/init.o

	${gcc_default} ${macro_includes} -c ${src_path}/kernel/interrupt.c -o ${target_path}/kernel/interrupt.o

	${gcc_default} ${macro_includes} -c ${src_path}/device/timer.c -o ${target_path}/kernel/timer.o

	${gcc_default} ${macro_includes} -c ${src_path}/kernel/debug.c -o ${target_path}/kernel/debug.o

	#汇编代码编译部分
	${nasm_default} ${src_path}/kernel/kernel.s -o ${target_path}/kernel/kernel.o

	${nasm_default} ${src_path}/lib/kernel/print.s -o ${target_path}/kernel/print.o

	#链接部分(由于选用虚拟机为32位，故必须编译到32位)
	find ${target_path} -type f ! -name "*.bin" |xargs ${ld_default} -Ttext 0xc0001500 -e main -o ${target_path}/bin/kernel.bin

	#烧录
	dd if=${target_path}/bin/kernel.bin of=${vm_path}/disk.img bs=512 count=200 seek=9 conv=notrunc

#初始化环境
build:

	#创建目标文件夹
	if [ ! -d ${target_path} ];then mkdir ${target_path};fi
	if [ ! -d ${target_path}/bin ];then mkdir ${target_path}/bin;fi
	if [ ! -d ${target_path}/kernel ];then mkdir ${target_path}/kernel;fi

	#创建镜像
	bximage -hd=10 -mode="create" -q ${vm_path}/disk.img

	#编译和烧录MBR和kernel loader
	nasm ${src_path}/boot/mbr.s ${macro_includes} -o ${target_path}/bin/mbr.bin
	nasm ${src_path}/boot/loader.s ${macro_includes} -o ${target_path}/bin/loader.bin

	dd if=${target_path}/bin/mbr.bin of=${vm_path}/disk.img bs=512 count=1 conv=notrunc

	dd if=${target_path}/bin/loader.bin of=${vm_path}/disk.img bs=512 count=4 seek=2 conv=notrunc

	#编译和烧录内核
	${gcc_default} ${macro_includes} -c ${src_path}/kernel/main.c -o ${target_path}/kernel/main.o

	${gcc_default} ${macro_includes} -c ${src_path}/kernel/init.c -o ${target_path}/kernel/init.o

	${gcc_default} ${macro_includes} -c ${src_path}/kernel/interrupt.c -o ${target_path}/kernel/interrupt.o

	${gcc_default} ${macro_includes} -c ${src_path}/device/timer.c -o ${target_path}/kernel/timer.o

	${gcc_default} ${macro_includes} -c ${src_path}/kernel/debug.c -o ${target_path}/kernel/debug.o

	${nasm_default} ${src_path}/kernel/kernel.s -o ${target_path}/kernel/kernel.o

	${nasm_default} ${src_path}/lib/kernel/print.s -o ${target_path}/kernel/print.o

	find ${target_path} -type f ! -name "*.bin" |xargs ${ld_default} -Ttext 0xc0001500 -e main -o ${target_path}/bin/kernel.bin

	#烧录
	dd if=${target_path}/bin/kernel.bin of=${vm_path}/disk.img bs=512 count=200 seek=9 conv=notrunc

#清理环境
clean:

	#删除img
	@-rm -rf ${vm_path}/disk.img
	#删除target中内容
	@-rm -rf ${target_path}/

