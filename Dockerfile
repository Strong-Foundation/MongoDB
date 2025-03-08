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

# Generate random values for MongoDB credentials and database
RUN export MONGO_INITDB_DATABASE=$(openssl rand -hex 12) && \
    export MONGO_INITDB_ROOT_USERNAME=$(openssl rand -hex 8) && \
    export MONGO_INITDB_ROOT_PASSWORD=$(openssl rand -base64 16) && \
    mongod --config /etc/mongod.conf --dbpath /data/db --logpath /var/log/mongodb/mongod.log --logappend --fork && \
    mongosh --eval "db = db.getSiblingDB('$MONGO_INITDB_DATABASE'); db.createCollection('initialCollection');" && \
    mongosh --eval "db = db.getSiblingDB('$MONGO_INITDB_DATABASE'); db.createUser({user: '$MONGO_INITDB_ROOT_USERNAME', pwd: '$MONGO_INITDB_ROOT_PASSWORD', roles: [{role: 'readWrite', db: '$MONGO_INITDB_DATABASE'}]});" && \
    mongod --shutdown --config /etc/mongod.conf --dbpath /data/db && \
    echo "MongoDB database: $MONGO_INITDB_DATABASE" && \
    echo "MongoDB username: $MONGO_INITDB_ROOT_USERNAME" && \
    echo "MongoDB password: $MONGO_INITDB_ROOT_PASSWORD"

# Create MongoDB configuration file with authentication enabled
RUN sed -i '/^#security:/c\security:\n  authorization: "enabled"' /etc/mongod.conf

# Generate the server private key and self-signed certificate
RUN mkdir -p /etc/ssl && \
    openssl genrsa -out /etc/ssl/mongodb.key 2048 && \
    openssl req -new -x509 -key /etc/ssl/mongodb.key -out /etc/ssl/mongodb.crt -days 365 -subj "/C=US/ST=State/L=City/O=Organization/OU=Unit/CN=localhost/emailAddress=email@example.com"

# Generate a CA private key and self-signed certificate
RUN openssl genrsa -out /etc/ssl/ca.key 2048 && \
    openssl req -new -x509 -key /etc/ssl/ca.key -out /etc/ssl/ca.crt -days 3650 -subj "/C=US/ST=State/L=City/O=Organization/OU=CA Unit/CN=My CA/emailAddress=email@example.com"

# Combine the server private key and certificate into a single PEM file
RUN cat /etc/ssl/mongodb.key /etc/ssl/mongodb.crt > /etc/ssl/mongodb.pem

# Set ownership and permissions for the certificate files to ensure security
RUN chown mongodb:mongodb /etc/ssl/mongodb.key /etc/ssl/mongodb.crt /etc/ssl/mongodb.pem /etc/ssl/ca.key /etc/ssl/ca.crt && \
    chmod 600 /etc/ssl/mongodb.key /etc/ssl/ca.key && \
    chmod 644 /etc/ssl/mongodb.crt /etc/ssl/ca.crt

# Generate a client private key and certificate, signing it with the CA
RUN openssl genrsa -out /etc/ssl/client.key 2048 && \
    openssl req -new -key /etc/ssl/client.key -out /etc/ssl/client.csr -subj "/C=US/ST=State/L=City/O=Organization/OU=Unit/CN=client/emailAddress=email@example.com" && \
    openssl x509 -req -in /etc/ssl/client.csr -CA /etc/ssl/ca.crt -CAkey /etc/ssl/ca.key -CAcreateserial -out /etc/ssl/client.crt -days 365

# Combine the client certificate and key into a single PEM file
RUN cat /etc/ssl/client.crt /etc/ssl/client.key > /etc/ssl/client.pem

# Configure MongoDB to use TLS/SSL for secure connections
RUN sed -i '/^net:/,/^$/ { /^net:/ { N; N; N; s|^net:\n  port: 27017\n  bindIp: 0.0.0.0\n|net:\n  port: 27017\n  bindIp: 0.0.0.0\n  tls:\n    mode: requireTLS\n    certificateKeyFile: /etc/ssl/mongodb.pem\n    CAFile: /etc/ssl/ca.crt\n    allowConnectionsWithoutCertificates: false\n| } }' /etc/mongod.conf

# Expose the default port used by MongoDB
EXPOSE 27017

# Start Supervisor to manage and control processes
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
