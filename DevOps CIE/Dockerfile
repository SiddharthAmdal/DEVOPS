# Dockerfile for Food Delivery Flask Order Service
# DevOps CIE: Question 3
FROM python:3.9-slim

WORKDIR /app

# Install Python dependencies (Flask, PyMySQL, Redis, cryptography)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source
COPY app.py .

# Expose container internal port 5000
EXPOSE 5000

ENV PORT=5000 \
    PYTHONUNBUFFERED=1

CMD ["python", "app.py"]
