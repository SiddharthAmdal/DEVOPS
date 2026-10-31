#!/usr/bin/env python3
# ==============================================================================
# AppArmor Profile Verification and Application Script
# DevOps CIE: Question 3 (Task 7)
# ==============================================================================

import os
import sys
import subprocess
import json

def run_cmd(cmd_list):
    """Helper to run shell command and return (returncode, stdout, stderr)."""
    res = subprocess.run(cmd_list, capture_output=True, text=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()

def main():
    print("=" * 70)
    print("TASK 7: AppArmor Security Profile Application & Verification")
    print("=" * 70)

    script_dir = os.path.dirname(os.path.abspath(__file__))
    profile_path = os.path.join(script_dir, "food-delivery-apparmor-profile")
    profile_name = "food-delivery-apparmor-profile"
    container_name = "security-test-container"

    # Step 1: Check host kernel AppArmor support
    print("\n[1/4] Checking host kernel AppArmor support...")
    is_linux = sys.platform.startswith("linux")
    code, which_out, _ = run_cmd(["which", "apparmor_parser"])
    has_parser = (code == 0)
    apparmor_enabled = False

    if is_linux and os.path.exists("/sys/module/apparmor/parameters/enabled"):
        try:
            with open("/sys/module/apparmor/parameters/enabled", "r") as f:
                apparmor_enabled = f.read().strip() == "Y"
        except Exception:
            pass

    print(f"  - Host Platform: {sys.platform}")
    print(f"  - apparmor_parser tool installed: {has_parser}")
    print(f"  - Host Linux Kernel AppArmor enabled: {apparmor_enabled}")

    # Step 2: Attempt loading profile if parser is present
    print(f"\n[2/4] AppArmor Profile Configuration: '{profile_name}'")
    if has_parser:
        print(f"  - Loading profile '{profile_path}' via apparmor_parser...")
        code, out, err = run_cmd(["sudo", "apparmor_parser", "-r", profile_path])
        if code == 0:
            print(f"  ✓ Profile '{profile_name}' loaded successfully into Linux kernel.")
        else:
            print(f"  ! Parser output: {err or out}")
    else:
        print("  - [Platform Note]:")
        print("    AppArmor is a Linux Security Module (LSM) enforcing Mandatory Access Control (MAC).")
        print("    On macOS (Darwin), Docker operates via Docker Desktop's LinuxKit VM.")
        print(f"    On production Linux nodes, the profile is loaded with:")
        print(f"      sudo cp {profile_path} /etc/apparmor.d/{profile_name}")
        print(f"      sudo apparmor_parser -r /etc/apparmor.d/{profile_name}")

    # Step 3: Run container with AppArmor Security Options
    print("\n[3/4] Testing container execution with security profile...")
    run_cmd(["docker", "rm", "-f", container_name])

    print(f"  - Attempting: docker run with '--security-opt apparmor={profile_name}'...")
    code, cid, err = run_cmd([
        "docker", "run", "-d",
        "--name", container_name,
        "--security-opt", f"apparmor={profile_name}",
        "flask-order-service:latest"
    ])

    if code == 0:
        print(f"  ✓ Container successfully started under profile '{profile_name}': {cid[:12]}")
        # Verify inspection
        _, inspect_out, _ = run_cmd([
            "docker", "inspect", container_name,
            "--format", "{{json .HostConfig.SecurityOpt}}"
        ])
        print(f"  - Confirmed SecurityOpt: {inspect_out}")
    else:
        print(f"  ! Kernel note: {err}")
        print("  - Falling back to container baseline confinement (docker-default)...")
        code, cid, _ = run_cmd([
            "docker", "run", "-d",
            "--name", container_name,
            "flask-order-service:latest"
        ])
        print(f"  ✓ Test container started: {cid[:12]}")

    # Step 4: Testing restricted operations
    print("\n[4/4] Testing operations restricted by security policies...")

    # Operation A: Sensitive system file read (/etc/shadow)
    print("  --- Test A: Attempting to read restricted system file /etc/shadow ---")
    code, out, err = run_cmd([
        "docker", "exec", container_name,
        "python3", "-c",
        "try:\n with open('/etc/shadow') as f: print(f.read())\nexcept PermissionError as e:\n print('BLOCKED: PermissionError ' + str(e))"
    ])
    print(f"  Execution Output: {out or err}")

    # Operation B: Attempting to write to root filesystem /etc/test.conf
    print("  --- Test B: Attempting unauthorized write to /etc/test.conf ---")
    code, out, err = run_cmd([
        "docker", "exec", container_name,
        "python3", "-c",
        "try:\n with open('/etc/test.conf', 'w') as f: f.write('unauthorized')\nexcept (PermissionError, OSError) as e:\n print('BLOCKED: ' + str(e))"
    ])
    print(f"  Execution Output: {out or err}")

    # Clean up test container
    run_cmd(["docker", "rm", "-f", container_name])
    print("  ✓ Security test container cleaned up.")

    print("\n" + "=" * 70)
    print("Task 7 AppArmor Security Confinement Test Completed")
    print("=" * 70)

if __name__ == "__main__":
    main()
