FROM python:3.10-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY delivery_metrics.py .

EXPOSE 8000

CMD ["python", "delivery_metrics.py"]
