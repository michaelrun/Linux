# PGO resources
[boost build](https://gist.github.com/Shauren/5c28f646bf7a28b470a8)\
[awesome-pgo](https://github.com/zamazan4ik/awesome-pgo/)


```
clang++ -std=c++11 -stdlib=libc++ -o my_program my_program.cpp
```
[mongodb PGO](https://github.com/zamazan4ik/awesome-pgo/blob/main/mongodb.md)

# build mongodb, third-party all with libc++ or libstdc++
elect options as appropriate for your environment. Please note that some flags may not be available on older versions.

Important note about C++11/C++14: The boost libraries do not offer a stable ABI across different versions of the C++ standard. As a result, you must ensure that your application, the C++ driver, and boost are all built with the same language standard. In particular, if you are building the C++ driver with C++11 enabled, you must also build your application with C++11 enabled, and link against a C++11 compiled boost. Note that on most systems, the system or package installed boost distribution is not built with C++11, and is therefore incompatible with a C++11 build of the legacy driver.

Important note about the C++ standard library: Much like the C++11 issues, it is again critical that all three components (your application, boost, and the C++ driver) be built against the same C++ runtime library. You cannot mix components that have linked against libc++ with those that have linked against libstdc++.

https://mongocxx.org/legacy-v1/installation/


# test linker options
C:
```
                    #include <stdlib.h>
                    #include <stdio.h>
                    int main() {
                        printf("Hello, World!");
                        return EXIT_SUCCESS;
                    }
```
C++:
```
                    #include <iostream>
                    #include <cstdlib>
                    int main() {
                        std::cout << "Hello, World!" << std::endl;
                        return EXIT_SUCCESS;
                    }
```
use different linker:
```
gcc -fuse-ld=lld -flto -o test test.c
gcc -fuse-ld=gold -flto -o test test.c
```

# how to build mongodb with LTO
gcc:\
`python3 buildscripts/scons.py LINKFLAGS="-fuse-ld=gold" --lto --opt=on --release=RELEASE -j 56 --disable-warnings-as-errors install-core MONGO_VERSION=4.4.19 `\
clang:\
`python3 buildscripts/scons.py CC=clang CXX=clang++ --lto --opt=on --release=RELEASE -j 56 --disable-warnings-as-errors install-core MONGO_VERSION=4.4.19 `

`clang` use the linker: `lld`, but `gcc` can't use linker `lld`, maybe `lld` don't recognize `gcc` `lto` options, but `gcc` needs to use `gold`

