.PHONY: init build load clean
#项目路径
path=/home/frodez/myOS
#源文件路径
src_path=${path}/src
#目标文件路径
target_path=${path}/target
#虚拟机路径
vm_path=${path}/vm

init:
	#创建目标文件夹
	@-mkdir ${target_path}
	@-mkdir ${target_path}/boot
	@-mkdir ${target_path}/kernel
	@-mkdir ${target_path}/lib
	#创建镜像
	bximage -hd=10 -mode="create" -q ${vm_path}/disk.img

build:
	#以下为编译MBR和kernel loader
	nasm -I ${src_path}/boot/include/ -o ${target_path}/boot/mbr.bin ${src_path}/boot/mbr.s
	nasm -I ${src_path}/boot/include/ -o ${target_path}/boot/loader.bin ${src_path}/boot/loader.s
	#以下为编译内核所用lib文件
	nasm -f elf -o ${target_path}/lib/print.o ${src_path}/lib/kernel/print.s
	#以下为编译内核到目标文件(由于选用虚拟机为32位，故必须编译到32位)
	gcc -m32 -I ${src_path}/lib/kernel -c -o ${target_path}/kernel/main.o  ${src_path}/kernel/main.c
	#以下为链接内核生成二进制可执行文件(由于选用虚拟机为32位，故必须编译到32位)
	ld -m elf_i386 -Ttext 0xc0001500 -e main -o ${target_path}/kernel/kernel.bin ${target_path}/kernel/main.o ${target_path}/lib/print.o

load:
	#烧录MBR
	dd if=${target_path}/boot/mbr.bin of=${vm_path}/disk.img bs=512 count=1 conv=notrunc
	#烧录内核loader
	dd if=${target_path}/boot/loader.bin of=${vm_path}/disk.img bs=512 count=4 seek=2 conv=notrunc
	#烧录内核
	dd if=${target_path}/kernel/kernel.bin of=${vm_path}/disk.img bs=512 count=200 seek=9 conv=notrunc

clean:
	#删除img
	@-rm -rf ${vm_path}/disk.img
	#删除target中内容
	@-rm -rf ${target_path}/boot/*~
	@-rm -rf ${target_path}/kernel/*~
	@-rm -rf ${target_path}/lib/*~

