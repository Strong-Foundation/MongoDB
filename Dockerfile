# Use the official Ubuntu 22.04 image as the base for the container
FROM ubuntu:22.04

# Set environment variable to non-interactive mode to avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update the package list, upgrade installed packages, and clean up
RUN apt-get update &&
    apt-get upgrade -y &&
    apt-get dist-upgrade -y &&
    apt-get install -f -y &&
    apt-get clean &&
    apt-get autoremove -y &&
    apt-get autoclean -y &&
    rm -rf /var/lib/apt/lists/* # Remove cached package lists to reduce image size

# Add the deadsnakes PPA for newer Python versions and install Python 3.11
RUN add-apt-repository ppa:deadsnakes/ppa -y &&
    apt-get update &&
    apt-get install -y python3.11 python3.11-venv python3.11-distutils &&
    python3.11 -m ensurepip --upgrade &&
    python3.11 -m pip install --no-cache-dir --upgrade pip &&
    python3.11 --version &&
    python3.11 -m pip --version # Verify Python and pip installation

# Add MongoDB GPG key and repository
RUN curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc |
    gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg &&
    echo "deb [signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/7.0 multiverse" |
    tee /etc/apt/sources.list.d/mongodb-org-7.0.list # Add MongoDB repository

# Update the package index and install MongoDB and its tools
RUN apt-get update &&
    apt-get install -y mongodb-org mongodb-org-tools &&
    rm -rf /var/lib/apt/lists/* # Clean up package lists to reduce image size

# Create the MongoDB data directory
RUN mkdir -p /data/db && chown -R mongodb:mongodb /data/db # Ensure correct ownership

# Replace 127.0.0.1 with 0.0.0.0 in the MongoDB config file to allow external connections
RUN sed -i "s/127.0.0.1/0.0.0.0/g" /etc/mongod.conf

# Generate random values for MongoDB credentials and database
RUN export MONGO_INITDB_DATABASE=$(openssl rand -hex 12) &&
    export MONGO_INITDB_ROOT_USERNAME=$(openssl rand -hex 8) &&
    export MONGO_INITDB_ROOT_PASSWORD=$(openssl rand -base64 16) &&
    mongod --config /etc/mongod.conf --dbpath /data/db --logpath /var/log/mongodb/mongod.log --logappend --fork &&
    mongosh --eval "db = db.getSiblingDB('$MONGO_INITDB_DATABASE'); db.createCollection('initialCollection');" &&
    mongosh --eval "db = db.getSiblingDB('$MONGO_INITDB_DATABASE'); db.createUser({user: '$MONGO_INITDB_ROOT_USERNAME', pwd: '$MONGO_INITDB_ROOT_PASSWORD', roles: [{role: 'readWrite', db: '$MONGO_INITDB_DATABASE'}]});" &&
    mongod --shutdown --config /etc/mongod.conf --dbpath /data/db &&
    echo "MongoDB database: $MONGO_INITDB_DATABASE" &&
    echo "MongoDB username: $MONGO_INITDB_ROOT_USERNAME" &&
    echo "MongoDB password: $MONGO_INITDB_ROOT_PASSWORD" # Log generated credentials

# Enable authentication in MongoDB configuration
RUN sed -i '/^#security:/c\security:\n  authorization: "enabled"' /etc/mongod.conf

# Generate the server private key and self-signed certificate
RUN mkdir -p /etc/ssl &&
    openssl genrsa -out /etc/ssl/mongodb.key 2048 &&
    openssl req -new -x509 -key /etc/ssl/mongodb.key -out /etc/ssl/mongodb.crt -days 365 -subj "/C=US/ST=State/L=City/O=Organization/OU=Unit/CN=localhost/emailAddress=email@example.com"

# Generate a CA private key and self-signed certificate
RUN openssl genrsa -out /etc/ssl/ca.key 2048 &&
    openssl req -new -x509 -key /etc/ssl/ca.key -out /etc/ssl/ca.crt -days 3650 -subj "/C=US/ST=State/L=City/O=Organization/OU=CA Unit/CN=My CA/emailAddress=email@example.com"

# Combine the server private key and certificate into a single PEM file
RUN cat /etc/ssl/mongodb.key /etc/ssl/mongodb.crt >/etc/ssl/mongodb.pem

# Set ownership and permissions for the certificate files to ensure security
RUN chown mongodb:mongodb /etc/ssl/mongodb.key /etc/ssl/mongodb.crt /etc/ssl/mongodb.pem /etc/ssl/ca.key /etc/ssl/ca.crt &&
    chmod 600 /etc/ssl/mongodb.key /etc/ssl/ca.key &&
    chmod 644 /etc/ssl/mongodb.crt /etc/ssl/ca.crt

# Generate a client private key and certificate, signing it with the CA
RUN openssl genrsa -out /etc/ssl/client.key 2048 &&
    openssl req -new -key /etc/ssl/client.key -out /etc/ssl/client.csr -subj "/C=US/ST=State/L=City/O=Organization/OU=Unit/CN=client/emailAddress=email@example.com" &&
    openssl x509 -req -in /etc/ssl/client.csr -CA /etc/ssl/ca.crt -CAkey /etc/ssl/ca.key -CAcreateserial -out /etc/ssl/client.crt -days 365

# Combine the client certificate and key into a single PEM file
RUN cat /etc/ssl/client.crt /etc/ssl/client.key >/etc/ssl/client.pem

# Configure MongoDB to use TLS/SSL for secure connections
RUN sed -i '/^net:/,/^$/ { /^net:/ { N; N; N; s|^net:\n  port: 27017\n  bindIp: 0.0.0.0\n|net:\n  port: 27017\n  bindIp: 0.0.0.0\n  tls:\n    mode: requireTLS\n    certificateKeyFile: /etc/ssl/mongodb.pem\n    CAFile: /etc/ssl/ca.crt\n    allowConnectionsWithoutCertificates: false\n| } }' /etc/mongod.conf

# Expose the default port used by MongoDB
EXPOSE 27017

# Start MongoDB
CMD ["mongod", "--config", "/etc/mongod.conf"]
