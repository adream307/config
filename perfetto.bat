adb wait-for-device
for /F "tokens=1,2,3 delims=-:./\ " %%i in ("%DATE%") do SET F1=%%i%%j%%k
for /F "tokens=1,2,3 delims=-:./\ " %%i in ("%TIME%") do SET F2=%%i.%%j.%%k

set FILE_NAME=%F1%_%F2%.ptrace
set CURRENT_PATH=%cd%

adb shell "setprop persist.traced.enable 1"
adb shell "echo 0 > /d/tracing/tracing_on"

adb shell perfetto -t 15s -b 1gb -s 2gb -o /data/misc/perfetto-traces/%FILE_NAME% gfx input view webview wm am sm audio video camera hal res dalvik rs bionic power pm ss database network adb vibrator aidl nnapi rro binder_driver binder_lock sched freq idle disk
::adb shell atrace -t 15s -b 1gb -s 2gb -o /data/misc/perfetto-traces/%FILE_NAME% gfx am input view sm wm res pm idle freq sched binder_driver bionic dalvik


adb pull /data/misc/perfetto-traces/%FILE_NAME% .
adb shell rm -rf /data/misc/perfetto-traces/%FILE_NAME%

pause

