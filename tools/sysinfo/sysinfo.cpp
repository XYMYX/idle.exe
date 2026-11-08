// idle-sysinfo: helper for the «System status» panel of idle.exe.
//
// Prints one JSON line per second to stdout:
//   {"cpu":12.5,"ram_used":...,"ram_total":...,"disk_free":...,"disk_total":...,
//    "uptime":12345,"gpu":7.0,"gpu_temp":54}
// gpu = -1 / gpu_temp = -1 when unknown. Values are only displayed by the game,
// never saved and never sent anywhere. No CPU temperature (would need a kernel driver).
//
// Lifetime: idle.exe starts it while the panel is open and passes its own process id.
// The helper exits when that process is gone or when stdout can't be written anymore.
//
// Build (MSYS2 UCRT64 g++, see tools/sysinfo/README.md):
//   g++ -O2 -s -static -mwindows -o idle-sysinfo.exe sysinfo.cpp -lpdh

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <pdh.h>
#include <pdhmsg.h>
#include <cstdio>
#include <cstdlib>
#include <vector>

namespace {

unsigned long long to_u64(const FILETIME& f) {
	return (static_cast<unsigned long long>(f.dwHighDateTime) << 32) | f.dwLowDateTime;
}

// GetProcAddress returns a generic pointer; going through void* avoids cast warnings.
template <typename Fn>
Fn proc(HMODULE lib, const char* name) {
	return reinterpret_cast<Fn>(reinterpret_cast<void*>(GetProcAddress(lib, name)));
}

// --- CPU load from GetSystemTimes (kernel time includes idle time) ------------------
struct CpuLoad {
	FILETIME idle{}, kernel{}, user{};
	CpuLoad() { GetSystemTimes(&idle, &kernel, &user); }
	double sample() {
		FILETIME i, k, u;
		if (!GetSystemTimes(&i, &k, &u)) return -1.0;
		const unsigned long long di = to_u64(i) - to_u64(idle);
		const unsigned long long dt = (to_u64(k) - to_u64(kernel)) + (to_u64(u) - to_u64(user));
		idle = i; kernel = k; user = u;
		return dt ? (static_cast<double>(dt - di) * 100.0 / static_cast<double>(dt)) : 0.0;
	}
};

// --- GPU load from the «GPU Engine» performance counters (3D engines, all processes) ---
struct GpuLoad {
	PDH_HQUERY query = nullptr;
	PDH_HCOUNTER counter = nullptr;
	bool ok = false;
	GpuLoad() {
		if (PdhOpenQueryW(nullptr, 0, &query) != ERROR_SUCCESS) return;
		// English counter path: works on German and other Windows languages as well.
		if (PdhAddEnglishCounterW(query, L"\\GPU Engine(*engtype_3D)\\Utilization Percentage", 0, &counter)
				!= ERROR_SUCCESS) return;
		ok = PdhCollectQueryData(query) == ERROR_SUCCESS;
	}
	~GpuLoad() { if (query) PdhCloseQuery(query); }
	double sample() {
		if (!ok || PdhCollectQueryData(query) != ERROR_SUCCESS) return -1.0;
		DWORD size = 0, count = 0;
		PDH_STATUS st = PdhGetFormattedCounterArrayW(counter, PDH_FMT_DOUBLE, &size, &count, nullptr);
		if (st != static_cast<PDH_STATUS>(PDH_MORE_DATA) || size == 0) return 0.0;
		std::vector<unsigned char> buf(size);
		auto* items = reinterpret_cast<PDH_FMT_COUNTERVALUE_ITEM_W*>(buf.data());
		if (PdhGetFormattedCounterArrayW(counter, PDH_FMT_DOUBLE, &size, &count, items) != ERROR_SUCCESS) return -1.0;
		double sum = 0.0;
		for (DWORD n = 0; n < count; ++n) {
			if (items[n].FmtValue.CStatus == PDH_CSTATUS_VALID_DATA) sum += items[n].FmtValue.doubleValue;
		}
		return sum > 100.0 ? 100.0 : sum;
	}
};

// --- GPU temperature via NVML (NVIDIA driver only, loaded at runtime) ----------------
struct NvTemp {
	using InitFn = int (*)();
	using HandleFn = int (*)(unsigned int, void**);
	using TempFn = int (*)(void*, int, unsigned int*);
	using ShutdownFn = int (*)();
	HMODULE lib = nullptr;
	void* device = nullptr;
	TempFn get_temp = nullptr;
	ShutdownFn shutdown = nullptr;
	NvTemp() {
		// Only from System32 (no DLL search in the current folder), then the old driver folder.
		lib = LoadLibraryExW(L"nvml.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
		if (!lib) lib = LoadLibraryExW(L"C:\\Program Files\\NVIDIA Corporation\\NVSMI\\nvml.dll", nullptr,
				LOAD_WITH_ALTERED_SEARCH_PATH);
		if (!lib) return;
		auto init = proc<InitFn>(lib, "nvmlInit_v2");
		auto handle = proc<HandleFn>(lib, "nvmlDeviceGetHandleByIndex_v2");
		get_temp = proc<TempFn>(lib, "nvmlDeviceGetTemperature");
		shutdown = proc<ShutdownFn>(lib, "nvmlShutdown");
		if (!init || !handle || !get_temp || init() != 0 || handle(0, &device) != 0) {
			device = nullptr;
		}
	}
	~NvTemp() {
		if (device && shutdown) shutdown();
		if (lib) FreeLibrary(lib);
	}
	int sample() {
		unsigned int t = 0;
		return (device && get_temp(device, 0 /* NVML_TEMPERATURE_GPU */, &t) == 0) ? static_cast<int>(t) : -1;
	}
};

bool write_line(HANDLE out, const char* text, int len) {
	DWORD written = 0;
	return WriteFile(out, text, static_cast<DWORD>(len), &written, nullptr) && written == static_cast<DWORD>(len);
}

}  // namespace

int main(int argc, char** argv) {
	SetDllDirectoryW(L"");  // never load DLLs from the current folder
	HANDLE out = GetStdHandle(STD_OUTPUT_HANDLE);
	if (out == nullptr || out == INVALID_HANDLE_VALUE) return 1;

	const DWORD parent_pid = argc > 1 ? static_cast<DWORD>(std::strtoul(argv[1], nullptr, 10)) : 0;
	HANDLE parent = parent_pid ? OpenProcess(SYNCHRONIZE, FALSE, parent_pid) : nullptr;

	wchar_t root[MAX_PATH] = L"C:\\";
	if (GetWindowsDirectoryW(root, MAX_PATH) >= 3) root[3] = L'\0';  // «C:\» of the system drive

	CpuLoad cpu;
	GpuLoad gpu;
	NvTemp temp;

	for (;;) {
		// Wait one second; stop early when idle.exe is gone.
		if (parent) {
			if (WaitForSingleObject(parent, 1000) != WAIT_TIMEOUT) break;
		} else {
			Sleep(1000);
		}
		MEMORYSTATUSEX mem{};
		mem.dwLength = sizeof(mem);
		GlobalMemoryStatusEx(&mem);
		ULARGE_INTEGER disk_free{}, disk_total{};
		GetDiskFreeSpaceExW(root, &disk_free, &disk_total, nullptr);

		char line[512];
		const int len = std::snprintf(line, sizeof(line),
				"{\"cpu\":%.1f,\"ram_used\":%llu,\"ram_total\":%llu,\"disk_free\":%llu,\"disk_total\":%llu,"
				"\"uptime\":%llu,\"gpu\":%.1f,\"gpu_temp\":%d}\n",
				cpu.sample(), mem.ullTotalPhys - mem.ullAvailPhys, mem.ullTotalPhys,
				disk_free.QuadPart, disk_total.QuadPart, GetTickCount64() / 1000ULL,
				gpu.sample(), temp.sample());
		if (len <= 0 || !write_line(out, line, len)) break;  // pipe closed: the game stopped reading
	}
	if (parent) CloseHandle(parent);
	return 0;
}
