import os
import random
import time
from prometheus_client import start_http_server, Summary, Gauge

# Prometheus Metrics Definitions
total_deliveries = Gauge("total_deliveries", "Total number of deliveries")
pending_deliveries = Gauge("pending_deliveries", "Number of pending deliveries")
on_the_way_deliveries = Gauge("on_the_way_deliveries", "Number of deliveries on the way")
average_delivery_time = Summary("average_delivery_time", "Average delivery time in seconds")


def simulate_delivery():
    # Check if high alert mode is active via environment variable
    simulate_high_alerts = os.getenv("SIMULATE_HIGH_ALERTS", "false").lower() in ("true", "1", "yes")

    if simulate_high_alerts:
        # Increased pending deliveries to exceed alert threshold (> 10)
        pending = random.randint(50, 100)
    else:
        # Standard delivery simulation
        pending = random.randint(10, 20)

    on_the_way = random.randint(5, 20)
    delivered = random.randint(30, 70)
    avg_time = random.uniform(15, 45)

    total = pending + on_the_way + delivered

    print(f"[DEBUG] Total deliveries: {total}")
    print(f"[DEBUG] Pending deliveries: {pending}")
    print(f"[DEBUG] On-the-way deliveries: {on_the_way}")
    print(f"[DEBUG] Average delivery time: {avg_time:.2f} seconds")

    total_deliveries.set(total)
    pending_deliveries.set(pending)
    on_the_way_deliveries.set(on_the_way)
    average_delivery_time.observe(avg_time)


if __name__ == "__main__":
    port = int(os.getenv("PORT", 8000))
    print(f"[INFO] Starting the HTTP server on port {port}...")
    start_http_server(port, addr="0.0.0.0")
    print(f"[INFO] HTTP server started. Simulating deliveries at http://0.0.0.0:{port}/metrics...")

    while True:
        simulate_delivery()
        print("[INFO] Sleeping for 1 seconds...")
        time.sleep(1)
