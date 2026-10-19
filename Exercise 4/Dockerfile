# Use the official Python image from Docker Hub
FROM python:3.9-slim

# Set working directory inside container
WORKDIR /app

# Install system diagnostic utilities (ping, curl) required for network testing
RUN apt-get update && \
    apt-get install -y --no-install-recommends iputils-ping curl && \
    rm -rf /var/lib/apt/lists/*

# Copy dependency specifications and application code
COPY requirements.txt .
COPY app.py .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Expose container port
EXPOSE 5001

# Run the Flask application
CMD ["python", "app.py"]
