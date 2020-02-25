;MBR段
%include "boot.inc"
SECTION MBR vstart=0x7c00
    mov ax, cs;将cs中值(0x7c00)赋给ax,ds,es,ss,fs(它们不能被直接赋值)
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov sp, 0x7c00;将0x07c00赋给sp,暂时作为栈顶

;清空屏幕(采用上卷窗口的方式)
;上卷窗口系统调用：int 0x10  功能号0x06
;参数:
;AH,AL  功能号(0x06),上卷的行数(为0代表全部) 0x0600
;BH     上卷行属性                        0x0700
;CH,CL  窗口左上角的(X,Y)位置,CH=Y,CL=X    0x0(0行0列)
;DH,DL  窗口右下角的(X,Y)位置,DH=Y,DL=X    0x184f(24行79列)
;返回值: 无
    mov ax, 0x600
    mov bx, 0x700
    mov cx, 0
    mov dx, 0x184f
    int 0x10

;直接写显存
;一个字符占2byte，低位字节为ascii码，高位为颜色亮度闪烁设置。

    mov ax, 0xb800;将0xb800赋给gs
    mov gs, ax
    mov byte [gs:0x00], 'M'
    mov byte [gs:0x01], 0xA4 ; A 表示绿色背景闪烁，4 表示前景色为红色
    mov byte [gs:0x02], 'B'
    mov byte [gs:0x03], 0xA4
    mov byte [gs:0x04], 'R'
    mov byte [gs:0x05], 0xA4
    mov byte [gs:0x06], ' '
    mov byte [gs:0x07], 0xA4
    mov byte [gs:0x08], 'R'
    mov byte [gs:0x09], 0xA4
    mov byte [gs:0x0a], 'U'
    mov byte [gs:0x0b], 0xA4
    mov byte [gs:0x0c], 'N'
    mov byte [gs:0x0d], 0xA4
    mov byte [gs:0x0e], 'N'
    mov byte [gs:0x0f], 0xA4
    mov byte [gs:0x10], 'I'
    mov byte [gs:0x11], 0xA4
    mov byte [gs:0x12], 'N'
    mov byte [gs:0x13], 0xA4
    mov byte [gs:0x14], 'G'
    mov byte [gs:0x15], 0xA4

;读取loader扇区数据
    mov eax, LOADER_START_SECTOR;loader扇区lba地址
    mov bx,  LOADER_BASE_ADDR;写入内存的地址
    mov cx,  4;读入4个扇区
    call read_disk_to_memory

    jmp LOADER_BASE_ADDR+0x300;LOADER_BASE_ADDR是loader.s中汇编段的起始地址，跨过前面0x300的数据部分

;函数功能:读取硬盘n个扇区
;参数:
;EAX    LBA扇区号
;BX     写入到内存的地址
;CX     读入的扇区个数
read_disk_to_memory:
;1.设置读取扇区个数
    mov esi, eax;备份eax和cx
    mov di,  cx
    mov dx,  0x1f2;sector count寄存器地址(和磁盘通道及主从盘有关)
    mov al,  cl
    out dx,  al;向端口写读取的扇区数
    mov eax, esi;恢复eax
;2.存入LBA地址到对应寄存器
    mov dx,  0x1f3;LBA0-7位端口
    out dx,  al
    shr eax, 8;向右移，获取8-15位
    mov dx,  0x1f4;LBA8-15位端口
    out dx,  al
    shr eax, 8;向右移，获取16-23位
    mov dx,  0x1f5;LBA16-23位端口
    out dx,  al
    shr eax, 8;向右移，获取24-27位
    and al,  0x0f;高4位置0，低4位(24-27)不变
    or  al,  0xe0;低4位不变，高四位置为1110(之前已全部置为0)
    mov dx,  0x1f6;Device端口
    out dx,  al
;3.向0x1f7端口写入读命令0x20
    mov dx,  0x1f7
    mov al,  0x20
    out dx,  al
;4.检测硬盘状态
;同一端口,写时表示写入命令字,读时表示读入硬盘状态
.not_ready:;未准备好状态
    nop;空指令
    in  al,  dx
    and al,  0x88;第4，7位不变，其他位置0。第4位为1表示硬盘控制器已准备好数据传输，第7位为1表示硬盘忙
    cmp al,  0x08;判断是否只有第4位为1
    jnz .not_ready;不是则继续等待

;5.从端口读数据
    mov ax,  di
    mov dx,  0x100;一次2字节，一个扇区512字节，共计256次
    mul dx;dx*ax,ax中为读取扇区个数。扇区个数*256*2字节=最终读取字节数
    mov cx,  ax;乘法结果放入cx(结果不会太大，所以使用16bit存放)
    mov dx,  0x1f0;读数据端口

.continue_read:;继续读数据
    in  ax,  dx;指定写数据的长度
    mov [bx],ax;向BX指向地址写数据(存放地址时是eax，但实模式下只能访问16位，故取低16位。读取数据大小不能超过64KB)
    add bx,  0x2
    loop .continue_read;重复次数由cx寄存器指定(while(--cx!=0)，注意cx会溢出)
    ret

;重复0x0直到512字节
;$指向当前行地址,$$指向段首地址。本段起始地址0x7c00，$-$$即中间所用的地址长度
    times 510-($-$$) db 0

;MBR结束标志0x55,0xaa
    db 0x55, 0xaa
