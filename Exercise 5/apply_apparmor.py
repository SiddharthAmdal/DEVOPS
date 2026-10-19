import os
import sys
import docker

# Create a Docker client
client = docker.from_env()

# Directory containing Dockerfile and app source
script_dir = os.path.dirname(os.path.abspath(__file__))

print("Building image from Dockerfile...")
client.images.build(path=script_dir, tag="flask-apparmor", rm=True)
print("Successfully built flask-apparmor\n")

print("Running container with AppArmor profile...")
try:
    # Run the container with the AppArmor profile
    container = client.containers.run(
        "flask-apparmor",
        name="flask-apparmor-instance",
        ports={'5000/tcp': 5000},
        security_opt=["apparmor=my-apparmor-profile"],
        detach=True
    )

    print(f"Container started: {container.short_id}\n")

    print("Inspecting container to verify AppArmor profile...")
    # Verify AppArmor profile applied
    container_info = client.api.inspect_container(container.id)
    apparmor_profile = container_info['HostConfig']['SecurityOpt']

    print(f"AppArmor profile applied: {apparmor_profile}\n")

    print("Stopping the container...")
    # Stop the container
    container.stop()
    container.remove()
    print("Container stopped and removed.")

except docker.errors.APIError as e:
    if "apparmor" in str(e).lower() and "profile not found" in str(e).lower():
        print(f"[NOTE] AppArmor profile 'my-apparmor-profile' must be loaded into the Linux kernel first.")
        print(f"Load command: sudo apparmor_parser -r /etc/apparmor.d/my-apparmor-profile")
        print(f"Error details: {e}")
    else:
        raise e
