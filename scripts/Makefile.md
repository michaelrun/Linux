# generate dependency header files
```
depend: .depend

.depend: qatseqprod.c
        $(CC) -c $(CFLAGS) -MM $(QATFLAGS) $(DEBUGFLAGS) $^ > $@
```

# generate dependency libararies:
```
gcc -Wl,--trace myprog.c -o myprog -L. -lmylib
-lmylib (./libmylib.a)
-lgcc_s (/usr/lib/x86_64-linux-gnu/gcc/x86_64-linux-gnu/4.5.2/libgcc_s.so)
...
```
The list of libraries then may be converted to Makefile rules using sed:
```
echo "myprog: " > myprog.dep
gcc -Wl,--trace myprog.c -o myprog -L. -lmylib \
    | sed -n 's/.*(\(.*\)).*/\1 \\/p' >> myprog.dep
```
So myprog.dep will have the following content:

```
myprog: \
./libmylib.a \
/usr/lib/x86_64-linux-gnu/gcc/x86_64-linux-gnu/4.5.2/libgcc_s.so \
...
```
[How to generate dependency file for executable (during linking) with gcc](https://stackoverflow.com/questions/33728510/how-to-generate-dependency-file-for-executable-during-linking-with-gcc)
