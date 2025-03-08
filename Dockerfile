# Use the official Ubuntu 22.04 image as the base for the container
# This provides a stable and secure foundation for our Docker image
FROM ubuntu:22.04

# Set environment variable to non-interactive mode to avoid prompts during package installation
# This ensures that the installation process is fully automated and doesn't require user input
ENV DEBIAN_FRONTEND=noninteractive

# Get the latest package lists
RUN apt-get update

# Install the required packages
RUN apt-get install curl gnupg sudo -y

# Import the MongoDB public GPG key
RUN curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor

# Create a list file for MongoDB
RUN echo "deb [ arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list

# Reload the package database.
RUN apt-get update

# Install MongoDB Community Server.
RUN apt-get install mongodb-org mongodb-org-tools -y

# Create the data directory
RUN mkdir -p /data/db

# Copy configuration files and scripts
# - supervisord_application.conf: Supervisor configuration file
COPY supervisord_application.conf /etc/supervisor/conf.d/supervisord_application.conf

# Create the MongoDB data directory
# - /data/db: Default directory for MongoDB data storage
RUN mkdir -p /data/db && chown -R mongodb:mongodb /data/db

# Replace 127.0.0.1 with 0.0.0.0 in the MongoDB config file
RUN sed -i "s/127.0.0.1/0.0.0.0/g" /etc/mongod.conf

# Expose the default MongoDB port
EXPOSE 27017

# Start Supervisor to manage and control processes
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
