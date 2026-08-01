FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt.
RUN pip install --no-cache-dir -r requirements.txt

# Copy all code
COPY.

# Railway will set $PORT, but we expose 8000 for local
EXPOSE 8000

# Start command - Railway will override the port with $PORT
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]