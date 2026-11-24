"""Small, read-only hardware inventory; never records credentials or photos."""
import json
import platform
import shutil
import subprocess
from pathlib import Path


def command(args):
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL, timeout=10).strip()
    except (OSError, subprocess.SubprocessError):
        return None


def inventory():
    result = {"platform": platform.system(), "architecture": platform.machine(),
              "python": platform.python_version(), "disk_free_gib": round(shutil.disk_usage(Path(__file__).parent).free / 2**30, 2)}
    if platform.system() == "Linux":
        cpu = Path('/proc/cpuinfo').read_text()
        result['cpu'] = next((s.split(':', 1)[1].strip() for s in cpu.splitlines() if s.startswith('model name')), None)
        mem = dict(line.split(':', 1) for line in Path('/proc/meminfo').read_text().splitlines())
        result['ram_total_gib'] = round(int(mem['MemTotal'].split()[0]) / 2**20, 2)
        result['ram_available_gib'] = round(int(mem['MemAvailable'].split()[0]) / 2**20, 2)
        devices = command(['lspci']) or ''
        result['display_devices'] = [line for line in devices.splitlines() if any(s in line.lower() for s in ('vga compatible', '3d controller', 'display controller'))]
    elif platform.system() == "Darwin":
        result['cpu'] = command(['sysctl', '-n', 'machdep.cpu.brand_string'])
        memory = command(['sysctl', '-n', 'hw.memsize'])
        result['ram_total_gib'] = round(int(memory) / 2**30, 2) if memory else None
    result['nvidia'] = command(['nvidia-smi', '--query-gpu=name,memory.total', '--format=csv,noheader'])
    result['blender_on_path'] = shutil.which('blender')
    return result


if __name__ == '__main__':
    print(json.dumps(inventory(), indent=2, ensure_ascii=False))
