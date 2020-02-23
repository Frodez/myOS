;MBR段
;
SECTION MBR vstart=0x7c00
    mov ax, cs;将cs中值赋给ax,ds,es,ss,fs(它们不能被直接赋值)
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov sp, 0x7c00;将0x07c00赋给sp,暂时作为栈顶

;
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

;
;获取光标位置系统调用: int 0x10  功能号0x03
;参数:
;AH     功能号(0x03)
;BH     光标所在页号
;返回值: 
;CH,CL  光标开始行,光标结束行
;DH,DL  光标所在行,光标所在列

    mov ah, 3
    mov bh, 0
    int 0x10

;
;打印字符串系统调用: int 0x10  功能号0x13
;参数:
;BP     字符串地址
;CX     字符串长度(不包括结尾的'\0')
;AH,AL  功能号(0x13),写字符方式(0x01,光标跟随移动)   0x1301
;BH,BL  要显示的页号,字符属性                       0xc
;DH,DL  坐标(X,Y)DH=Y,DL=X                       0xc20
;返回值:

    mov ax, message
    mov bp, ax;bp不能被直接赋值
    mov ax, 0x1301
    mov bx, 0xc
    mov cx, 9
    mov dx, 0xc20
    int 0x10

;
;跳转向自己,使程序悬停
    jmp $

;数据

    message db "hello mbr"

;
;重复0x0直到512字节
;$指向当前行地址,$$指向段首地址。本段起始地址0x7c00，$-$$即中间所用的地址长度
    times 510-($-$$) db 0

;MBR结束标志0x55,0xaa
    db 0x55, 0xaa
