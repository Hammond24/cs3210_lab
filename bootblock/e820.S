.code16                       # Assemble for 16-bit mode

magic:
  .long 0x0534d4150

e820:
  .long 0xe820

# Only 16 bit.
dest_addr:
  .word 0x0


# The desetination adder (where the data will be stored) is passed in eax
.globl do_e820
do_e820:
  mov %ax, (dest_addr)
  add $4, %ax
  mov %ax, %di
  xor %ebx, %ebx
  xor %bp, %bp
  mov (magic), %edx

.e820lp:
  mov (e820), %eax
  movl $1, %es:20(%di)
  mov $24, %ecx
  int $0x15
  jc .e820f
  mov (magic), %edx

  cmp %edx, %eax
  jne .e820f
  test %ebx, %ebx
  je .e820f
  jcxz .skipent
  cmp $20, %cl
  inc %bp		
  add $24, %di
.skipent:
  test %ebx, %ebx
  jne .e820lp
.e820f:
  xor %eax, %eax
  mov (dest_addr), %ax
  mov %bp, (%eax)
  ret

