"""Waits for the phone to come back, then installs the current build.

The device dropped off the network mid-mission. This loop is observation and
control only: it tries to reach the phone, and when it does it installs the APK
that was built from the current source and says so. It never touches a foreign
application and never sends input to any screen.

    python3 tool/wait_for_device.py <serial> <apk> [minutes]
"""

import subprocess
import sys
import time

SERIAL = sys.argv[1] if len(sys.argv) > 1 else "192.168.29.138:36373"
APK = sys.argv[2] if len(sys.argv) > 2 else "build/app/outputs/flutter-apk/app-debug.apk"
MINUTES = float(sys.argv[3]) if len(sys.argv) > 3 else 90.0


def run(*args: str, timeout: int = 60) -> subprocess.CompletedProcess:
    """One adb call, with its own timeout.

    `adb connect` to a host that is gone does not fail — it hangs until the
    socket gives up, which can be minutes. A timeout here is the expected answer
    while the phone is away, not a reason for the loop to fall over.
    """
    try:
        return subprocess.run(
            ["adb", *args], capture_output=True, text=True, shell=False, timeout=timeout
        )
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(
            args=["adb", *args], returncode=1, stdout="", stderr="timed out"
        )


def online() -> bool:
    out = run("devices", timeout=20).stdout
    for line in out.splitlines()[1:]:
        parts = line.split()
        if len(parts) >= 2 and parts[0] == SERIAL and parts[1] == "device":
            return True
    return False


def main() -> int:
    deadline = time.time() + MINUTES * 60
    print(f"[device] waiting for {SERIAL} for up to {MINUTES:.0f} minutes", flush=True)
    while time.time() < deadline:
        if not online():
            run("connect", SERIAL, timeout=25)
        if online():
            print(f"[device] {time.strftime('%H:%M:%S')} {SERIAL} is back; installing", flush=True)
            result = run("-s", SERIAL, "install", "-r", APK, timeout=600)
            print(result.stdout.strip()[-400:], flush=True)
            print(result.stderr.strip()[-200:], flush=True)
            if "Success" in result.stdout:
                print("[device] the current build is installed", flush=True)
                return 0
            print("[device] install did not report success; will retry", flush=True)
        time.sleep(20)
    print("[device] the phone never came back", flush=True)
    return 2


if __name__ == "__main__":
    sys.exit(main())
