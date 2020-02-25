;内核加载器
%include "boot.inc"
SECTION loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR;定义栈顶地址

;构建gdt及其内部的描述符
;1.构建全局描述符表
    GDT_BASE:           dd 0x00000000
                        dd 0x00000000
    CODE_DESC:          dd 0x0000FFFF
                        dd DESC_CODE_HIGH4
    DATA_STACK_DESC:    dd 0x0000FFFF
                        dd DESC_DATA_HIGH4
    VIDEO_DESC:         dd 0x80000007;limit = (0xbffff - 0xb8000) / 4k = 0x7
                        dd DESC_VIDEO_HIGH4;此时dpl为0
;2.确定GDT大小和段界限
    GDT_SIZE equ $ - GDT_BASE;GDT大小
    GDT_LIMIT equ GDT_SIZE - 1;段界限
    times 60 dq 0;此处预留60个描述符的空位
;3.构建代码段，数据段，显存段的选择子
    SELECTOR_CODE equ (0x0001<<3) + TI_GDT + RPL0;相当于(CODE_DESC - GDT_BASE) / 8 + TI_GDT + RPL0
    SELECTOR_DATA equ (0x0002<<3) + TI_GDT + RPL0;同上
    SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0;同上

;total_mem_bytes用于保存内存容量，以字节为单位，此位置比较好记
;当前偏移loader.bin文件头0x200字节，loader.bin的加载地址是0x900，故total_mem_bytes内存中的地址是0xb00
;在内核中会引用此地址

    total_mem_bytes dd 0

;以下是gdt的指针，前2字节是gdt 界限，后4字节是gdt起始地址

    gdt_ptr             dw GDT_LIMIT
                        dd GDT_BASE

;人工对齐:total_mem_bytes4+gdt_ptr6+ards_buf244+ards_nr2，共256字节

    ards_buf times 244 db 0
    ards_nr dw 0;用于记录ARDS结构体数量

loader_start:;0x900是本汇编段的起始地址，跨过前面0x300的数据部分

;int 15h eax = 0000E820h, edx = 534D4150h('SMAP')获取内存布局

    xor ebx, ebx;第一次调用时，ebx值要为0
    mov edx, 0x534d4150;edx只赋值一次，循环体中不会改变
    mov di,  ards_buf;ards结构缓冲区

.e820_mem_get_loop:
;1.循环获取每个ARDS 内存范围描述结构

    mov eax, 0x0000e820 ;执行int 0x15后，eax值变为0x534d4150，所以每次执行int 前都要更新为子功能号
    mov ecx, 20 ;ARDS地址范围描述符结构大小是20字节
    int      0x15
    jc       .e820_failed_so_try_e801;若cf位为1则有错误发生，尝试0xe801子功能
    add di,  cx ;使di增加20字节指向缓冲区中新的ARDS结构位置
    inc word [ards_nr];记录ARDS数量
    cmp ebx, 0;若ebx为0且cf不为1，这说明ards全部返回当前已是最后一个
    jnz      .e820_mem_get_loop;否则继续获取ARDS的其他内容
    ;在所有ards结构中找出(base_add_low + length_low)的最大值，即内存的容量
    mov cx,  [ards_nr]
    ;遍历每一个ARDS 结构体,循环次数是ARDS 的数量
    mov ebx, ards_buf
    xor edx, edx;edx为最大的内存容量，在此先清0

.find_max_mem_area:
;2.找出最大内存容量

    ;无需判断type 是否为1,最大的内存块一定是可被使用的
    mov eax, [ebx];base_add_low
    add eax, [ebx+8];length_low
    add ebx, 20;指向缓冲区中下一个ARDS结构
    cmp edx, eax
    ;冒泡排序,找出最大,edx寄存器始终是最大的内存容量
    jge      .next_ards
    mov edx, eax;edx为总内存大小
.next_ards:
    loop     .find_max_mem_area
    jmp      .mem_get_ok

;int 15h ax = E801h 获取内存大小，最大支持4G
;返回后, ax cx值一样，以KB为单位，bx dx值一样，以64KB为单位
;在ax和cx寄存器中为低16MB，在bx和dx寄存器中为16MB到4GB
.e820_failed_so_try_e801:

    mov ax,  0xe801
    int      0x15
    jc       .e801_failed_so_try88 ;若当前e801方法失败，就尝试0x88方法

;1.先算出低15MB的内存。ax和cx中是以KB为单位的内存数量，将其转换为以byte为单位

    mov cx,  0x400;cx和ax值一样，cx用作乘数
    mul cx
    shl edx, 16
    and eax, 0x0000FFFF
    or  edx, eax
    add edx, 0x100000;ax只是15MB，故要加1MB
    mov esi, edx;先把低15MB 的内存容量存入esi寄存器备份

;2.再将16MB以上的内存转换为byte为单位。寄存器bx和dx中是以64KB为单位的内存数量

    xor eax, eax
    mov ax,  bx
    mov ecx, 0x10000;0x10000十进制为64KB
    mul ecx;32位乘法，默认的被乘数是eax，积为64位。高32位存入edx，低32位存入eax
    add esi, eax
    ;由于此方法只能测出4GB以内的内存，故32位eax足够了。edx肯定为0，只加eax便可
    mov edx, esi ;edx 为总内存大小
    jmp      .mem_get_ok

;int 15h ah = 0x88获取内存大小，只能获取64MB之内
.e801_failed_so_try88:;int 15后，ax存入的是以KB为单位的内存容量

    mov ah,  0x88
    int      0x15
    ;jc       .error_hlt
    and eax, 0x0000FFFF
    mov cx,  0x400
    ;16位乘法，被乘数是ax，积为32位。积的高16位在dx中，积的低16位在ax中。0x400等于1024,将ax中的内存容量换为以byte为单位
    mul cx
    shl edx, 16;把dx移到高16位
    or  edx, eax;把积的低16位组合到edx，为32位的积
    add edx, 0x100000;0x88子功能只会返回1MB以上的内存，故实际内存大小要加上1MB

.mem_get_ok:

    mov [total_mem_bytes], edx;将内存换为byte单位后存入total_mem_bytes处

;准备进入保护模式
;1.打开A20
    in  al,   0x92
    or  al,   0000_0010B
    out 0x92, al
;2.加载GDT
    lgdt [gdt_ptr]
;3.CR0第0位置1。CR0是控制寄存器。
    mov eax,  cr0
    or eax,   0x00000001
    mov cr0,  eax

;刷新流水线。
;1.
;刷新段描述符寄存器中的缓存。在实模式下，32位及以上的CPU依然使用段描述符寄存器。
;段基址左移4位在计算后会被缓存到段描述符寄存器里，不再需要重复计算。
;但进入保护模式时，计算方式发生改变，故需要更新缓存。
;SELECTOR_CODE为之前构建好的正确的段选择子。
;2.
;防止流水线继续按照16位模式对32位指令译码。
;由于流水线重叠，指令在[bits 32]前和mov cr0, eax后已经进入保护模式。
;本指令使用dword会将指令强制转换为32位，并且使用远转移清空流水线，且改变了段描述符寄存器的缓存。
    jmp dword SELECTOR_CODE:p_mode_start

[bits 32]
p_mode_start:;正式进入保护模式

    ;mov ax,  SELECTOR_DATA
    ;mov ds,  ax
    ;mov es,  ax
    ;mov ss,  ax
    ;mov esp, LOADER_STACK_TOP
    ;mov ax,  SELECTOR_VIDEO
    ;mov gs,  ax
    ;mov byte [gs:160], 'P'
    ;jmp $

;创建页目录及页表并初始化页内存位图
    call      setup_page
;要将描述符表地址及偏移量写入内存gdt_ptr，一会儿用新地址重新加载
    sgdt      [gdt_ptr];存储到原来gdt所有的位置
;将gdt描述符中视频段描述符中的段基址+0xc0000000(挪到3-4GB处的内核空间)
    mov ebx,  [gdt_ptr + 2];跳过gdt_ptr前面2字节的偏移量
    or  dword [ebx + 0x18 + 4], 0xc0000000
;视频段是第3个段描述符，每个描述符是8字节，故0x18
;段描述符的高4字节的最高位是段基址的第31～24位
;将gdt的基址加上0xc0000000使其成为内核所在的高地址
    add dword [gdt_ptr + 2], 0xc0000000
    add esp,  0xc0000000;将栈指针同样映射到内核地址
;把页目录地址赋给cr3
    mov eax,  PAGE_DIR_TABLE_POS
    mov cr3,  eax
;打开cr0的pg位(第31位)
    mov eax,  cr0
    or  eax,  0x80000000
    mov cr0,  eax
;在开启分页后，用gdt新的地址重新加载
    lgdt      [gdt_ptr];重新加载
    mov byte  [gs:160], 'V';视频段段基址已经被更新，用字符v 表示virtual addr

    jmp $

;创建页目录表(二级页表)和页表
setup_page:

    mov ecx, 4096
    mov esi, 0

.clear_page_dir:;循环4096次，逐字节清0页目录表

    ;mov byte [0x10000], 0
    mov byte [PAGE_DIR_TABLE_POS + esi], 0
    inc esi
    loop .clear_page_dir

;开始创建页目录表(PDE)
;1.初始化参数，将页表地址写入页目录表
.create_pde:

    mov eax, PAGE_DIR_TABLE_POS
    add eax, 0x1000;此时eax为第一个页表的位置及属性
    mov ebx, eax;此处为ebx赋值，是为.create_pte做准备，ebx为基址

;下面将页目录项0和0xc00都存为第一个页表的地址，每个页表表示4MB内存。
;这样0xc03fffff以下的地址和0x003fffff以下的地址都指向相同的页表。这是为将地址映射为内核地址做准备。

    or  eax, PG_US_U | PG_RW_W | PG_P;页目录项的属性RW和P位为1，US为1，表示用户属性，所有特权级别都可以访问
    mov [PAGE_DIR_TABLE_POS + 0x0], eax;第0个目录项写入第一个页表的位置(0x101000)及属性
    mov [PAGE_DIR_TABLE_POS + 0xc00], eax;再写入第0xc00个目录项。
    ;这里是3GB-4GB的起始地址对应页表，也是操作系统即将占用的空间起始地址。
    ;也就是页表的0xc0000000-0xffffffff共计1GB属于内核。
    ;0x0-0xbfffffff共计3GB属于用户进程
    ;在页目录的最后一个页目录项里写入页表自己的物理地址
    sub eax, 0x1000;此时eax为第一个页表的前一个，也即是页目录表的地址
    mov [PAGE_DIR_TABLE_POS + 4092], eax;第0xfff个目录项即最后一个目录项，指向页目录表自己的地址

;2.创建页表页表项(PTE)

    mov ecx, 256;1M低端内存/每页大小=256(暂时只创建256个页表)
    mov esi, 0
    mov edx, PG_US_U | PG_RW_W | PG_P;属性为7，US=1，RW=1，P=1

.create_pte:

    mov [ebx+esi*4], edx;此时的ebx已经在上面通过eax赋值为0x101000，也就是第一个页表的地址
    add edx, 4096;一个页表4KB，加上4096就是跳到下一个页表的地址
    inc esi
    loop .create_pte

;3.创建内核其他页表的页目录项(PDE中769-1022项,768和1023项均已创建完成)
;目的：所有用户共享内核
;为用户进程创建页表时，将内核页表对应的768-1022项页目录项复制到用户进程页目录表的对应位置。
;这样每个用户进程都会将内核地址指向相同位置，从而共享内核。
;如果不提前指定好内核拥有的页表位置，则无法简单地让用户进程的页目录表中拥有同样的内核页表。

    mov eax, PAGE_DIR_TABLE_POS
    add eax, 0x2000;此时eax为第二个页表的位置
    or  eax, PG_US_U | PG_RW_W | PG_P;页目录项的属性US､RW 和P位都为1
    mov ebx, PAGE_DIR_TABLE_POS
    mov ecx, 254;范围为第769～1022的所有目录项数量
    mov esi, 769

.create_kernel_pde:

    mov [ebx+esi*4], eax
    inc esi
    add eax, 0x1000
    loop .create_kernel_pde
    ret