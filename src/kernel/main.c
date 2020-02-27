#include "print.h"
#include "init.h"
#include "debug.h"
void main(void) {
   init_all();
   //put_str("I am kernel\n");
   //put_int(0x114514);
   asm volatile("sti");
   //ASSERT(1==2);
   while(1);
   return 0;
}