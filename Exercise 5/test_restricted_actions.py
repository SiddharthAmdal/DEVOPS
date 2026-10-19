import docker

# Create a Docker client
client = docker.from_env()

print("Launching container with AppArmor profile enforcement...")
try:
    # Run the container with the AppArmor profile
    container = client.containers.run(
        "flask-apparmor",
        name="flask-apparmor-test",
        ports={'5000/tcp': 5000},
        security_opt=["apparmor=my-apparmor-profile"],
        detach=True
    )

    print(f"Container started: {container.short_id}\n")

    # Test 1: Testing restricted file read (blocked by: deny /etc/** r)
    print("--- Test 1: Testing restricted file read (cat /etc/passwd) ---")
    exit_code, output = container.exec_run("cat /etc/passwd")
    print(f"Attempt to read /etc/passwd: Exit Code {exit_code}, Output: {output.decode().strip()}")

    # Test 2: Testing restricted binary execution (blocked by: deny /bin/** rmix)
    print("\n--- Test 2: Testing restricted binary execution (/bin/bash) ---")
    exit_code, output = container.exec_run("/bin/bash")
    print(f"Attempt to execute /bin/bash: Exit Code {exit_code}, Output: {output.decode().strip()}")

    # Clean up test container
    print("\nStopping and cleaning up container...")
    container.stop()
    container.remove()
    print("Container stopped and removed successfully.")

except docker.errors.APIError as e:
    if "apparmor" in str(e).lower() and "profile not found" in str(e).lower():
        print(f"[NOTE] AppArmor profile 'my-apparmor-profile' must be loaded into the Linux kernel first.")
        print(f"Load command: sudo apparmor_parser -r /etc/apparmor.d/my-apparmor-profile")
        print(f"Details: {e}")
    else:
        raise e
