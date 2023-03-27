# print ENV variable
```
print(qatzstdEnv.Dump())

print("========================")
src_objs=FindSourceFiles()
for index, value in enumerate(src_objs):
        print(src_objs[index])
print("========================")

dict = qatzstdEnv.Dictionary()
keys = dict.keys()
keys.sort()
for key in keys:
    print "qatzstd construction variable = '%s', value = '%s'" % (key, dict[key])
```

# get OS environment
```
import os

osEnv = Environment(ENV = os.environ)
ICP_ROOT=osEnv['ENV']['ICP_ROOT']
print(ICP_ROOT)
```


# print target evaluated
```
Progress('Evaluating $TARGET\n')
```
