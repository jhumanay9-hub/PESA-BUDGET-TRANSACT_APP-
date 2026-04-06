@echo off
adb shell dumpsys battery unplug
adb shell dumpsys battery set status 4
.\scrcpy.exe -m 1024 -b 4M --max-fps 30 --no-audio
adb shell dumpsys battery reset
pause