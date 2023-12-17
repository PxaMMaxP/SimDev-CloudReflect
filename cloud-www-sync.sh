#!/bin/bash

# Determine the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )" &> /dev/null && pwd )"
source "${SCRIPT_DIR}/config"
source "${SCRIPT_DIR}/version"

log_message() {
    local level="$1"
    local message="$2"

    case "$LOG_LEVEL" in
        "trace")
            echo "[TRACE] $message"
            ;;
        "info")
            if [[ "$level" == "info" || "$level" == "error" ]]; then
                echo "[$level] $message"
            fi
            ;;
        "error")
            if [[ "$level" == "error" ]]; then
                echo "[ERROR] $message"
            fi
            ;;
    esac
}

cleanup() {
	log_message "info" "Script is being terminated, performing cleanup..."
	
	
	log_message "info" "### Start script 'cloud-www-sync' Version ${VERSION} ###"
}

# Set trap for SIGINT (Ctrl+C) and SIGTERM (system service termination)
trap cleanup SIGINT SIGTERM

# Parse sync pairs from configuration
parse_paths() {
    local pair="$1"
    IFS=';' read -ra PATHS <<< "$pair"
    echo "${PATHS[@]}"
}

# Check for necessary commands and paths
check_requirements() {
    local error_code=0

    # 0. Check if the docker command exists
    if ! command -v docker &> /dev/null; then
		log_message "error" "Docker command not found."
        ((error_code |= 1))
    fi

    # 1. Check if the specified Docker container exists and is active
    if [ "$(docker ps -q -f name="$DOCKER_CONTAINER_NAME")" == "" ]; then
        log_message "error" "Docker container '$DOCKER_CONTAINER_NAME' not found or not active."
        ((error_code |= 2))
    fi

    # 2. Check if the unison command exists
    if ! command -v unison &> /dev/null; then
        log_message "error" "Unison command not found."
        ((error_code |= 4))
    fi

    # 3. Check if the inotifywait command exists
    if ! command -v inotifywait &> /dev/null; then
        log_message "error" "inotifywait command not found."
        ((error_code |= 8))
    fi

    # 4+^2. Check if the source and target paths exist
    local pair_num=0
    for pair in "${SYNC_PAIRS[@]}"; do
        read -ra parsed_paths <<< "$(parse_paths "$pair")"
        SOURCE_PATH="${parsed_paths[0]}${parsed_paths[1]}"
        TARGET_PATH="${parsed_paths[2]}"

        local path_error=0
        if [ ! -d "$SOURCE_PATH" ]; then
            log_message "error" "Source directory '$SOURCE_PATH' does not exist."
            path_error=1
        fi
        if [ ! -d "$TARGET_PATH" ]; then
            log_message "error" "Target directory '$TARGET_PATH' does not exist."
            ((path_error+=2))
        fi
        ((error_code |= path_error << (4 + 2 * pair_num)))
        ((pair_num++))
    done

    # Exit if any errors were found
    if [ $error_code -ne 0 ]; then
        log_message "error" "Errors found with code: $error_code."
        exit $error_code
    else
        log_message "trace" "All checks passed successfully."
    fi
}


# Sync content between source and target paths
sync_content() {
    local source_path="$1"
    local target_path="$2"

    # Perform unison synchronization
    unison -auto -batch -prefer newer "$source_path" "$target_path"
}

# Update permissions of the target path
update_permissions() {
    local path="$1"

    # Change permissions and ownership
    find "$path" -exec chmod 0766 {} \;
    chown -R 33:33 "$path"
}

# Monitor and sync directories specified in SYNC_PAIRS
monitor_and_sync() {
    for pair in "${SYNC_PAIRS[@]}"; do
        (
            read -ra parsed_paths <<< "$(parse_paths "$pair")"
            SOURCE_PATH="${parsed_paths[0]}${parsed_paths[1]}"
            TARGET_PATH="${parsed_paths[2]}"
            NEXTCLOUD_PATH="${parsed_paths[1]}"

            while true; do
                # Wait for file changes in source and target directories
                inotifywait -r -e modify,create,delete,move "$SOURCE_PATH" "$TARGET_PATH"

                # Perform synchronization and update permissions
                sync_content "$SOURCE_PATH" "$TARGET_PATH"
                docker exec --user $DOCKER_USERNAME $DOCKER_CONTAINER_NAME php occ files:scan --path="$NEXTCLOUD_PATH"
                update_permissions "$TARGET_PATH"
            done
        ) &
    done
    wait
}

log_message "info" "### Start script 'cloud-www-sync' Version ${VERSION} ###"

# Run the main part of the script
check_requirements
monitor_and_sync

cleanup