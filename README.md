# SimDev CloudReflect

SimDev CloudReflect is a sophisticated cloud synchronization tool designed to manage and synchronize data between local directories and Docker-based cloud services. It offers advanced logging capabilities, configurable sync pairs, and efficient permission handling, making it an ideal tool for personal cloud management.

## Features

- **Configurable Logging**: Set different log levels (`info`, `error`, `trace`) to suit your monitoring needs.
- **Docker Integration**: Works with Docker containers, allowing seamless synchronization with services like Nextcloud.
- **Sync Pairs Management**: Define source and target paths for synchronization in a flexible and straightforward manner.
- **Automatic Permission Handling**: Ensures correct permissions on synced files for hassle-free cloud service interaction.
- **Efficient Monitoring**: Utilizes `inotifywait` for real-time monitoring of file changes, triggering synchronization as needed.
- **Safe Operations**: Incorporates lock mechanisms to prevent concurrent operations from conflicting.

## Configuration (`config.sample`)

The configuration is managed through a `config.sample` file, which allows setting log levels, Docker container details, and defining sync pairs. Here's an example of the configuration structure:

```plaintext
LOG_LEVEL="info" # Possible values: info, error, trace
DOCKER_CONTAINER_NAME="nextcloud-app"
DOCKER_USERNAME="www-data"

# SYNC_PAIRS Configuration:
SYNC_PAIRS=(
    "/path/to/nextcloud/folder/app/data;/nextcloudUser/files/path/to/source/folder;/path/to/target/folder"
    # Additional path pairs can be added here in the same format
)

```

## Installation and Usage

1. Download the latest version of SimDev CloudReflect `.deb` package from the releases section.
2. Install the package using your package manager, for example:
   ```bash
   sudo dpkg -i simdev-cloudreflect_x.y.z.deb
   ```
    Replace x.y.z with the actual version number of the package.

3. Use the config.sample in `/etc/cloudreflect/`, adapt it to your requirements and rename it to config.

4. Start the service:
   ```bash
   sudo systemctl start cloudreflect.service
   ```

## Systemd Service

SimDev CloudReflect comes with a systemd service file for easy setup and management of the synchronization process as a system service.

## Contributions

Contributions to SimDev CloudReflect are welcome. Whether it's feature requests, bug reports, or code contributions, feel free to open an issue or pull request on the repository.

## License

SimDev CloudReflect is released under MIT License.

## Acknowledgements

Special thanks to all the contributors and users of SimDev CloudReflect for their support and feedback in making this tool better.
