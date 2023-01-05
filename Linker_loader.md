# Linking
## About static linking
When your application links against a static library, the library's code becomes part of the resulting executable. This is performed only once at linking time, and these static libraries usually end with a .a extension.
A static library is an archive (`ar`) of object files. The object files are usually in the ELF format. ELF is short for `Executable and Linkable Format`, which is compatible with many operating systems.
## About dynamic linking


## The dynamic loader: ld.so
On Linux, you mostly are dealing with shared objects, so there must be a mechanism that detects an application's dependencies and loads them into memory.

ld.so looks for shared objects in these places in the following order:

1. The relative or absolute path in the application (hardcoded with the -rpath compiler option on GCC)
2. In the environment variable LD_LIBRARY_PATH
3. In the file /etc/ld.so.cache 

Keep in mind that adding a library to the system

[How to handle dynamic and static libraries in Linux](https://opensource.com/article/20/6/linux-libraries)


## rebuild shared object with SHSTK support enabled
Fix:\
`export GLIBC_TUNABLES=glibc.cpu.x86_ibt=off:glibc.cpu.x86_shstk=off`
![image](https://user-images.githubusercontent.com/19384327/210727790-21b705f3-22d2-4525-aef3-93823d807d70.png)

