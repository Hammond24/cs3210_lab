project(user ASM)

include_directories(include)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -static -fno-builtin -nostdinc -nostartfiles -nodefaultlibs -fno-pic -m32")
set(CMAKE_ASM_FLAGS "${CMAKE_C_FLAGS}")
#set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -N -e main -Ttext 0")
# FIXME: Maybe use... unclear
set(CMAKE_C_LINK_EXECUTABLE "ld -m elf_i386 -N -e main -Ttext 0 <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")

# We need to do several things --
# Need ulib sources (easy enough)
# Need to compile the programs
#  -- binary should add a _...
# Need to create disassembly
# Need to create symbol files

set(ulib_SOURCES
  asm/usys.S

  src/ulib.c
  src/umalloc.c
  src/printf.c
  )

# Start with just init...
set(user_SOURCES
  src/init.c
  src/sh.c
  src/ls.c
  )

set_property(GLOBAL PROPERTY user_programs)

add_library(ulib OBJECT
  ${ulib_SOURCES})

function(add_user_program program_src)
  # Strip out src/ and .c
  get_filename_component(prog_base ${program_src} NAME_WE)
  # Add _
  set(output_exe "_${prog_base}")
  message("Have output_exe ${output_exe}")

  get_property(l_user_programs GLOBAL PROPERTY user_programs)
  list(APPEND l_user_programs "${output_exe}")
  set_property(GLOBAL PROPERTY user_programs ${l_user_programs})

  # First, build the program
  add_executable(${output_exe} ${program_src} $<TARGET_OBJECTS:ulib>)
  # Second, disassemble the program
  # Third, get symbols
endfunction(add_user_program)

foreach(prog_src ${user_SOURCES})
  add_user_program(${prog_src})
endforeach(prog_src)

get_property(l_user_programs GLOBAL PROPERTY user_programs)
message("USER_PROGRAMS includes: ${l_user_programs}")

configure_file(${CMAKE_SOURCE_DIR}/README ${CMAKE_CURRENT_BINARY_DIR}/README COPYONLY)

add_custom_command(
  OUTPUT fs.img
  COMMAND ${CMAKE_CURRENT_BINARY_DIR}/../tools/mkfs fs.img README ${l_user_programs}
  DEPENDS mkfs ${CMAKE_SOURCE_DIR}/README ${l_user_programs}
)

add_custom_target(
  makeuserfs ALL
  DEPENDS fs.img)

