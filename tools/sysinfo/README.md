# idle-sysinfo

Small helper for the optional «System status» view of idle.exe (off by default, opt-in in the settings).

While the view is open, idle.exe starts this helper and reads one JSON line per second from it:
CPU load, RAM, free space on the system drive, uptime, GPU load (Windows performance counters)
and GPU temperature (NVIDIA only, via `nvml.dll` from the driver). No CPU temperature.

The values are only displayed: never saved, never sent anywhere, no network access.

Second mode, `idle-sysinfo.exe --watch <pid> [fullscreen] [notaskbar]`, runs as long as idle.exe:

- `fullscreen` (setting «Hide during fullscreen», on by default): once per second it checks whether the
  foreground window fills the monitor idle.exe is on (or Windows reports an exclusive fullscreen game)
  and prints `1` or `0` when that changes. It never reads window titles or contents.
- `notaskbar` (setting «Taskbar entry» off, the default): gives idle.exe's main window the tool-window
  style (`WS_EX_TOOLWINDOW`), so it has no taskbar button and doesn't show in Alt+Tab. Godot has no flag for that.
The helper exits by itself when idle.exe is gone (it gets the game's process id as argument).

Third mode, `idle-sysinfo.exe --autostart on <path to idle.exe>` / `--autostart off` (setting «Start with Windows»,
off by default): writes or removes the value `idle.exe` under
`HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run` (this user only, no admin rights).

## Build (Windows, MSYS2 UCRT64)

```bash
g++ -O2 -s -static -mwindows -Wall -Wextra -o idle-sysinfo.exe sysinfo.cpp -lpdh
```

- `-mwindows`: no console window pops up.
- `-static`: no MinGW DLLs needed next to the exe.

For the editor the exe stays here (`tools/sysinfo/idle-sysinfo.exe`). For a release it goes next to
`idle.exe` (the `tools/` folder is not exported).
