# Use the official lightweight Python image
FROM python:3.10-slim

# Set the working directory inside the container
WORKDIR /app

# Copy the requirements file first to cache dependencies
COPY requirements.txt .

# Install the Python libraries needed for Deep Intel Omni
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the backend files (like main.py) into the container
COPY . .

# Run the Uvicorn web service on container startup. 
# Google Cloud Run expects traffic on port 8080 by default.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]