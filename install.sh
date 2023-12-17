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
    echo "${SERVICE_NAME}"
}

# Function to update the SERVICE_NAME in the configuration file
update_service_name_in_config() {
    # Update or add SERVICE_NAME in the config file
    if grep -q "SERVICE_NAME=" "${CONFIG_FILE}"; then
        # Updating existing SERVICE_NAME
        if sed_output=$(sed -i "s/SERVICE_NAME=\".*\"/SERVICE_NAME=\"$SERVICE_NAME\"/" "${CONFIG_FILE}" 2>&1); then
            log_message "trace" "SERVICE_NAME updated in config: $CONFIG_FILE"
        else
            error=$sed_output
            log_message "error" "Error updating SERVICE_NAME in config: $error"
            return 1
        fi
    else
        # Adding new SERVICE_NAME
        if echo_output=$(echo "SERVICE_NAME=\"$SERVICE_NAME\"" >> "${CONFIG_FILE}" 2>&1); then
            log_message "trace" "SERVICE_NAME added to config: $CONFIG_FILE"
        else
            error=$echo_output
            log_message "error" "Error adding SERVICE_NAME to config: $error"
            return 1
        fi
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
    if [ -w "${input_dir:-$bin_dir}" ]; then 
        log_message "trace" "Binary path writable: ${input_dir:-$bin_dir}"
    else 
        log_message "error" "Binary path not writable: ${input_dir:-$bin_dir}"
        exit 1
    fi

    BIN_DIR=${input_dir:-$bin_dir}
}

# Function to request and set the service name
service_name_demand() {
    # Request and validate the service name
    read -p "Enter the name for the systemd service [$APP_NAME]: " service_name
    if systemctl list-unit-files "$service_name" &>/dev/null; then
        log_message "error" "Service exists: ${service_name}"
        exit 1
    else
        log_message "trace" "Service name available: ${service_name}"
        SERVICE_NAME=${service_name}
    fi
}

# Function to create a systemd service file
create_systemd_service_file() {
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    if cat_output=$(cat > "${SERVICE_FILE}" <<EOF
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
    ); then
        log_message "trace" "Systemd service file created: $SERVICE_FILE"
    else
        error=$?
        log_message "error" "Error creating systemd service file: $SERVICE_FILE. Status: $error"
        exit 1
    fi

    # Set permissions for the service file
    if chmod_output=$(chmod 644 "${SERVICE_FILE}" 2>&1); then
        log_message "trace" "Service file permissions set: $SERVICE_FILE"
    else
        error=$chmod_output
        log_message "error" "Error setting permissions: $SERVICE_FILE. Error: $error"
    fi

    # Reload systemd daemon
    if systemd_output=$(systemctl daemon-reload 2>&1); then
        log_message "trace" "Systemd daemon reloaded"
    else
        error=$systemd_output
        log_message "error" "Error reloading systemd daemon: $error"
    fi

    # Enable the service
    if systemctl_output=$(systemctl enable "${SERVICE_NAME}" 2>&1); then
        log_message "trace" "Service enabled: ${SERVICE_NAME}"
    else
        error=$systemctl_output
        log_message "error" "Error enabling service: ${SERVICE_NAME}. Error: $error"
    fi
}

# Install function
install() {
    # Confirm installation
    read -p "Confirm installation of ${APP_NAME} ${VERSION}? [y/N]: " confirmation
    if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
        echo "Installation canceled."
        exit 0
    fi

    echo "Installing ${APP_NAME} ${VERSION}..."
    bin_dir_demand
	
	if lnsf_output=$(ln -sf "${SCRIPT_DIR}/cloud-reflect.sh" "${BIN_DIR}/cloud-reflect.sh" 2>&1); then
        log_message "trace" "Create the symbolic link for the script successfully: Source:${SCRIPT_DIR}/cloud-reflect.sh; Target:${BIN_DIR}/cloud-reflect.sh."
    else
        error=$lnsf_output
        log_message "error" "Creating the symbolic link for the script was not successful: Source:${SCRIPT_DIR}/cloud-reflect.sh; Target:${BIN_DIR}/cloud-reflect.sh. Error: $error"
		exit 1
    fi
	
    service_name_demand
    create_systemd_service_file

    if ! update_service_name_in_config; then
        echo "Error updating service name in config."
        exit 1
    fi

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

    # Read service name from config
    SERVICE_NAME=$(read_service_name)
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

    # Stop and disable the service
    if systemctl_output=$(systemctl stop "${SERVICE_NAME}" 2>&1); then
        log_message "trace" "Service stopped: ${SERVICE_NAME}"
    else
        error=$systemctl_output
        log_message "error" "Error stopping service: ${SERVICE_NAME}. Error: $error"
    fi

    if systemctl_output=$(systemctl disable "${SERVICE_NAME}" 2>&1); then
        log_message "trace" "Service disabled: ${SERVICE_NAME}"
    else
        error=$systemctl_output
        log_message "error" "Error disabling service: ${SERVICE_NAME}. Error: $error"
    fi

    # Remove symbolic link and service file
    if rm_output=$(rm -f "${BIN_DIR}/cloud-reflect.sh" 2>&1); then
        log_message "trace" "Symbolic link removed: ${BIN_DIR}/cloud-reflect.sh"
    else
        error=$rm_output
        log_message "error" "Error removing symbolic link: ${BIN_DIR}/cloud-reflect.sh. Error: $error"
    fi

    if rm_output=$(rm -f "${SERVICE_FILE}" 2>&1); then
        log_message "trace" "Service file removed: ${SERVICE_FILE}"
    else
        error=$rm_output
        log_message "error" "Error removing service file: ${SERVICE_FILE}. Error: $error"
    fi

    # Reload systemd daemon
    if systemd_output=$(systemctl daemon-reload 2>&1); then
        log_message "trace" "Systemd daemon reloaded"
    else
        error=$systemd_output
        log_message "error" "Error reloading systemd daemon: $error"
    fi

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
        -l|--log) LOG_LEVEL="$2"; shift ;;
        --install) install; exit 0 ;;
        --uninstall) uninstall; exit 0 ;;
        *) echo "Unknown option: $1"; show_help ;;
    esac
    shift
done
