# idle-sysinfo

Small helper for the optional «System status» view of idle.exe (off by default, opt-in in the settings).

While the view is open, idle.exe starts this helper and reads one JSON line per second from it:
CPU load, RAM, free space on the system drive, uptime, GPU load (Windows performance counters)
and GPU temperature (NVIDIA only, via `nvml.dll` from the driver). No CPU temperature.

The values are only displayed: never saved, never sent anywhere, no network access.
The helper exits by itself when idle.exe is gone (it gets the game's process id as argument).

## Build (Windows, MSYS2 UCRT64)

```bash
g++ -O2 -s -static -mwindows -Wall -Wextra -o idle-sysinfo.exe sysinfo.cpp -lpdh
```

- `-mwindows`: no console window pops up.
- `-static`: no MinGW DLLs needed next to the exe.

For the editor the exe stays here (`tools/sysinfo/idle-sysinfo.exe`). For a release it goes next to
`idle.exe` (the `tools/` folder is not exported).
