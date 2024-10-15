## gcc list system include path
```
gcc -xc -E -v -
gcc -xc++ -E -v -
```

## .ccls 
```
%compile_commands.json
%cpp -std=c++17
-isystem/usr/include/c++/11
-isystem/usr/include/x86_64-linux-gnu/c++/11
-isystem/usr/include/c++/11/backward
-isystem/usr/lib/gcc/x86_64-linux-gnu/11/include
-isystem/usr/local/include
-isystem/usr/include/x86_64-linux-gnu
-isystem/usr/include

```
