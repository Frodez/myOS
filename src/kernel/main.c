#include "print.h"
#include "init.h"
#include "debug.h"
#include "memory.h"
void main(void) {
   init_all();
   put_int(0x114514);
   void* addr = get_kernel_pages(3);
   put_str("\n get_kernel_page start vaddr is ");
   put_int((uint32_t)addr);
   put_str("\n");
   put_str("\n");
   while(1);
   return 0;
}