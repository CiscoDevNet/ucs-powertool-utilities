## Docker Instructions

### Build and Run the Container

If you wish to build the Docker image to run the compatibility check follow these steps:

1) Clone this repo

    `git clone https://github.com/dchosnek/imm-compatibility-checker.git`

2) Build the image

    `docker build -t imm-compatibility-checker .`

3) Run the container

    For this step you can choose to supply the credentials as environment variables to the container and run the container in the background or you can enter them interactively.

    **background:**

    ```
    docker run -it --rm \
    -e UCS_HOST=<hostname or IP> \
    -e UCS_USERNAME=<username> \
    -e UCS_PASSWORD=<password> \
    -v $PWD/log.csv:/app/log.csv \
    imm-compatibility-checker
    ```

    **interactively:**

    ```
    docker run -it --rm \
    -v $PWD/log.csv:/app/log.csv \
    imm-compatibility-checker
    ```

    > **_NOTE:_**  Either option requires a volume mount to retrieve the output csv of the compatibility test.
