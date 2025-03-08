# Import the base image from the Docker Hub repository (Ubuntu 24.04)
FROM ubuntu:24.04

# Set environment variables
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

# Expose the default MongoDB port
EXPOSE 27017

# Start the MongoDB service
CMD ["mongod"]