# MongoDB Docker Setup

This repository contains a Docker setup for running MongoDB in a containerized environment.

## Prerequisites

Ensure you have the following installed on your system:

- [Docker](https://www.docker.com/get-started)

## Building the Docker Image

To build the Docker image, navigate to the repository directory and run:

```sh
docker build -t my-mongodb .
```

This will build the image using the `Dockerfile` in the current directory and tag it as `my-mongodb`.

## Running the MongoDB Container

Once the image is built, you can run the container using:

```sh
docker run -d --name mongodb-container -p 27017:27017 my-mongodb
```

- `-d` runs the container in detached mode.
- `--name mongodb-container` assigns a name to the running container.
- `-p 27017:27017` maps the MongoDB port to your local machine.

## Accessing MongoDB

You can access the running MongoDB instance using a MongoDB client or via the command line:

```sh
docker exec -it mongodb-container mongosh
```

## Cleaning Up

To stop and remove the container:

```sh
docker stop mongodb-container && docker rm mongodb-container
```

To remove the Docker image:

```sh
docker rmi my-mongodb
```

## License

This project is licensed under the MIT License.
