# Lab 2 - Virtual Memory

In this lab you will be modifying the xv6 virtual memory system, making virtual
memory allocation to be far more efficient.  You will do so by modifying the xv6
memory system to provide much more efficient management of OS memory resources
through the virtual memory system.

Your primary goal in this lab will be to minimize both the amount of wasted
memory, and the unneeded copying done by xv6's current inefficient memory
management mechanism.

In particular, we're going to use two optimizations to reduce the amount of
memory used by xv6 using two powerful techniques:

- Copy-on-write forking
- Lazy zero-page allocation.


### Logistics


All of the code for this course will be distributed and turned in using the
[git](www.git-scm.com) revision system.  

This lab will use your private course xv6 repository.

```bash
git clone git@github.gatech.edu:cs3210-fall20/<your_uniquename>-xv6-public.git
```

For this lab, we will be using the lab2 branch within git.  You may switch to it
with:

```bash
git checkout lab2
```

## Part 1 - Copy-on-write forking

When xv6 forks a new process, it clones the parent's entire address space,
creating a newly allocated page in the child for every page in the parent.
This is an expensive and often unneeded operation.  Many times the child will
simply call `exec()`, throwing away the address space the parent just carefully
cloned.  Additionally, even in the instance the child doesn't fork, it will
rarely touch every page the parent had allocated, and any untouched page is a
wasted copy.

Instead, for this part of the lab we're going to delay page copying on fork
until it is absolutely necessary.  The key observation that enables this delay
in work is that at fork both the child and parent will have an identical address
space, and their address spaces will only diverge once either the child or
parent writes memory.

For this portion of the lab, you will build a copy-on-write implementation for
xv6, in which on fork you will not copy the contents of any user-pages, instead
lazily allocating them as needed (at the time of write).  Your solution is
expected to be transparent to the user-space (the behavior observed by the
user-space before and after your copy-on-write implementation will be
identical), with the exception that the new implementation will have far more
efficient `fork`s, and more available system memory.

**NOTE**: For simplicity in this lab you are required to create a unique
page-directory and unique page-tables per process (although this is not strictly
necessary), it is only the data pages that should follow copy-on-write
semantics.


### Copy-on-write forking advice

As well as the "General advice and hints" found later, for this portion of the
lab you'll have to get familiar with both the memory allocation system
(`kernel/src/kalloc.c`) and the virtual memory system used by the processes
(`kernel/src/vm.c`).  Currently, on fork (`kernel/src/proc.c`), `copyuvm`
(`kernel/src/vm.c`) is called to allocate a new virtual address space for the
user process.  You may consider how you would like to modify the code here
first.  When you receive a trap (e.g. a pagefault) the trap will be delivered
through the kernel, eventually to our c trap handler in `trap()`
(`kernel/src/trap.c`).

Think carefully about your design before you build it.  What structures need
what metadata?  What's the best way to store and organize that metadata?  What
is the ownership of a physical page?  Of a virtual page?

- You can find a somewhat in-depth explanation of the xv6 paging structure in
  chapter 2 of the
  [xv6 manual].  A more
  in-depth description is also available in the [intel manual] chapter 4.
- Consider complex parent-child relationships when designing your code.  Think
  of complex relationships, such as what should happen when a parent forks two
  children, when a parent dies before its child, or when a parent forks a child
  forks a grandchild.
- When you modify the permissions of a present virtual page in the page-table,
  you'll have to invalidate the TLB entry for that page, we've provided you a
  function to do so `invlpg(void *vaddr)` in `include/asm/x86.h`.  **NOTE:** you
  don't need to invalidate a page if it isn't present in the current virtual
  address space (as resetting cr3 will cause a TLB invalidation on its behalf).
- If you feel overwhelmed with this lab, don't give up.  We have an active
  Piazza, copious office hours and support structures to help you get through
  this we are willing to help you at all stages of implementation, from
  understanding the spec to debugging.  The hard part of this class is often in
  a concise design, not in a complex implementation (Prof. Devecsery's solution
  modifies under 300 LOC for this project, but the project isn't by any means
  easy).

# Part 2 - Zero Initialized Data

When the OS allocates a page for a process (e.g. through sbrk), that page is
zero-initialized (its data is read as zero).  So, if a user-process were to
allocate 1000 pages of virtual address space, each of those 1000 pages would be
allocated as all-zero data.  This duplication of user-space data presents
opportunity for optimization within the kernel.  A page that is zero-filled need
not be immediately allocated, as the kernel knows that its contents will be all
zero once accessed.  Furthermore, if a process only reads the zero data and
never writes it, then the all zero-filled pages can actually be backed by the
same physical page.

In this part of the lab, your goal will be to add in zero-initialized data
deduplication, and lazy page zero allocation to your kernel.  These are the
following design principals you're expected to follow:

- Zero-filled virtual addresses should be lazily allocated, allocating a
  unique physical page only on write.
- All zero-initialized virtual pages should share read-only access to a single
  physical zero-page, that is never written.
- Any write to a zero-initialized page will cause a new physical page to be
  allocated and used in its place.

# Specification details

- You are expected to minimize the costs of operations.  Operations costs
  include page-faults (100s of cycles) and copies (1000s-10000s of cycles).  You
  should always prefer an additional page-fault to an unneeded copy.

- You are not to keep a mapping from physical pages to virtual address spaces
  (this gets complex quickly), as a result, you are allowed to take one extra
  page fault (but not a page copy) when a physical page becomes referenced by
  exactly one virtual page.

- Your lab should be generally efficient.  You may not waste excess memory
  unnecessarily, or preform particularly computationally inefficient activities
  (like scanning all page tables of all processes on page fault).

# General advice and hints

- You may need to store per-physical-page information as part of this lab.
- The page-table-entry structure of x86 has several "ignored" bits (bits 9-11).
  Feel free to use these to store virtual-page specific extra information about
  a virtual address needed for this lab. (references are Figure 2-1, pg 30 of
  the [xv6 book], and Figure 4-4, pg 4-11 of the [intel manual])
- The kernel may sometimes access a user-space page on the user's behalf (can
  you think of when?).  You should handle these instances gracefully.
- In order to get full credit for this lab you'll have to consider the corner
  cases of this design.  What extremes can you think of testing for?

# Lab-specific requirements

Your lab will be graded on both correctness (the correct output is observed),
and efficiency (you have a minimal number of page-faults, page-copies, and
page-zeros).  To facilitate the autograder in grading correctly, your lab2
branch has been modified to replace most user-space page zeros (see the note
below) with a call to our function `lab2_pgzero()`, and any page copies to
`lab2_pgcopy()`.  For full credit, you must continue to call `lab2_pgzero` and
`lab2_pgcopy` whenever your project zeros or copies a page respectively.  You
must also call the following function whenever you receive a pagefault:

```
lab2_report_pagefault(struct trapframe *tf);
```

The functions `lab2_pgcopy()` and `lab2_pgzero()` are defined as follows:

```
void lab2_pgcopy(void *dest, void *src, uint va);
Arguments:
dest - The destination (address) of the page to be copied to (must be page
aligned)
src - The source page to be copied from (must be page aligned)
va - The user-space virtual address about to be copied.

void lab2_pgzero(void *dest, uint va)
Arguments:
dest - The destination address to be zeroed (must be the start of a 4KB page)
va - The user-space address being zeroed
```

We've provided definitions of these functions in two files
`kernel/src/lab2_ag.c` and `kernel/src/lab2_ag_noprint.c`.  They may be switched
using your `kernel/Sources.cmake` file.  The intended purpose of these functions
and these files is to give the autograder some additional insight into how you
are handling the zero-initialize and copy-on-write filling of pages.  However,
the prints created by these functions can sometimes make it hard to tell what
the behavior of the test is, so we provided a `noprint` version which will not
add any additional prints.  You may select which version you would like to use
for testing (we recommend using both!).  The autograder will test with both.
You are *not* allowed to change the supplied `kernel/src/lab2_ag.c`,
`kernel/src/lab2_ag_noprint.c`, or `kernel/include/lab2_ag.h` files.

**NOTES:**
- You are not expected to call `lab2_pgcopy` or `lab2_pgzero` for the initial
  page of the first process created by the kernel (in `kernel/src/inituvm.c`),
  or for any kernel data-pages (e.g. va > KERNBASE).

# Submission

As usual, you will submit your project to the [autograder](TODO-AutograderLink), and 
you are expected to follow all instructions outlined in the
[syllabus](https://gatech.instructure.com/courses/140830/assignments/syllabus)
and [autograder
manual](https://github.gatech.edu/cs3210-fall20/xv6-public/blob/main/instructions/autograder_instructions.md).


[intel manual]: https://software.intel.com/content/www/us/en/develop/download/intel-64-and-ia-32-architectures-sdm-combined-volumes-3a-3b-3c-and-3d-system-programming-guide.html
[xv6 manual]: http://cs3210.cc.gatech.edu/r/xv6-rev9-book.pdf
