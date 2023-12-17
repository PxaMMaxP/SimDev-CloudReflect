#!/bin/bash

# Define script directory and import configuration, logging, and version information
SCRIPT_DIR="$( cd "$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )" &> /dev/null && pwd )"
source "${SCRIPT_DIR}/logging"
source "${SCRIPT_DIR}/config"
source "${SCRIPT_DIR}/version"

# Initialize global variables
SERVICE_NAME=""
BIN_DIR=""

# Function to display help information
show_help() {
    echo "${APP_NAME} Version ${VERSION}"
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message and exit."
    echo "  -l, --log      Set log level (default: info). Possible values: info, error, trace"
    echo "  --install      Install the script and create a systemd service."
    echo "  --uninstall    Uninstall the script and systemd service."
    exit 0
}

# Function to read the service name from the configuration file
read_service_name() {
    source "${CONFIG_FILE}"
    echo "${SERVICE_NAME:-$APP_NAME}"
}

# Function to update the SERVICE_NAME in the configuration file
update_service_name_in_config() {
    # Update or add SERVICE_NAME in the config file
    if grep -q "SERVICE_NAME=" "${CONFIG_FILE}"; then
        # Updating existing SERVICE_NAME
        sed -i "s/SERVICE_NAME=\".*\"/SERVICE_NAME=\"$SERVICE_NAME\"/" "${CONFIG_FILE}"
    else
        # Adding new SERVICE_NAME
        echo "SERVICE_NAME=\"$SERVICE_NAME\"" >> "${CONFIG_FILE}"
    fi
}

# Function to request and set the binary directory
bin_dir_demand() {
    # Detect and set the binary directory
    local detected_bin_dir=$(echo $PATH | tr ':' '\n' | grep -m 1 '/usr/local/bin')
    local fallback_bin_dir="/usr/local/bin"
    local bin_dir=${detected_bin_dir:-$fallback_bin_dir}

    # Prompt the user to confirm or enter a new path
    read -p "Enter the installation directory for the script [$bin_dir]: " input_dir
    input_dir=${input_dir:-$bin_dir}
    if [ -w "$input_dir" ]; then 
        BIN_DIR=$input_dir
    else 
        log_message "error" "Binary path not writable: $input_dir"
        exit 1
    fi
}

# Function to request and set the service name
service_name_demand() {
    # Request and validate the service name
    read -p "Enter the name for the systemd service [$APP_NAME]: " service_name
    service_name=${service_name:-$APP_NAME}
    if systemctl status "$service_name" &>/dev/null; then
        log_message "error" "Service exists: $service_name"
        exit 1
    else
        SERVICE_NAME=$service_name
    fi
}

# Function to create a systemd service file
create_systemd_service_file() {
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=${APP_NAME} Sync Service
After=docker.service network.target
PartOf=docker.service

[Service]
ExecStart=${BIN_DIR}/cloud-reflect.sh
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

    # Set permissions for the service file
    chmod 644 "${SERVICE_FILE}"
    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}"
}

# Install function
install() {
    # Confirm installation
    read -p "Confirm installation of ${APP_NAME} ${VERSION}? [y/N]: " confirmation
    if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
        echo "Installation canceled."
        exit 0
    fi

    bin_dir_demand
    ln -sf "${SCRIPT_DIR}/cloud-reflect.sh" "${BIN_DIR}/cloud-reflect.sh"
    service_name_demand
    create_systemd_service_file
    update_service_name_in_config

    echo "${APP_NAME} ${VERSION} installed."
}

# Uninstall function
uninstall() {
    # Confirm uninstallation
    read -p "Confirm uninstallation of ${APP_NAME}? [y/N]: " confirmation
    if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
        echo "Uninstallation canceled."
        exit 0
    fi

    SERVICE_NAME=$(read_service_name)
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

    systemctl stop "${SERVICE_NAME}"
    systemctl disable "${SERVICE_NAME}"
    rm -f "${BIN_DIR}/cloud-reflect.sh"
    rm -f "${SERVICE_FILE}"
    systemctl daemon-reload

    echo "${APP_NAME} uninstalled."
}

# Check for passed arguments
if [ "$#" -eq 0 ]; then
    show_help
    exit 0
fi

# Process arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help) show_help ;;
        -l|--log) 
            if [ -z "$2" ]; then
                echo "Error: Missing argument for --log"
                exit 1
            fi
            LOG_LEVEL="$2"; shift ;;
        --install) install; exit 0 ;;
        --uninstall) uninstall; exit 0 ;;
        *) echo "Unknown option: $1"; show_help ;;
    esac
    shift
done
