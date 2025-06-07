# Use an official Python runtime as a parent image, now with Python 3.10
FROM python:3.10-slim-buster

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Expose the port that Flask will listen on. Cloud Run uses port 8080 by default.
EXPOSE 8080

# Define environment variable
ENV FLASK_APP=app.py

# Command to run the Flask app. Cloud Run expects the app to listen on 0.0.0.0
# and on the port specified by the PORT environment variable (default 8080).
CMD exec flask run --host=0.0.0.0 --port=8080
