#!/bin/bash

# Determine the script's directory
SCRIPT_DIR="$( cd "$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )" )" &> /dev/null && pwd )"
source "${SCRIPT_DIR}/logging"
source "${SCRIPT_DIR}/config"
source "${SCRIPT_DIR}/version"

# Cleanup actions for script termination
cleanup() {
    log_message "info" "Script is being terminated, performing cleanup..."
    # (Insert cleanup actions here)
	
	log_message "info" "### Start ${APP_NAME} Version ${VERSION} ###"
}

# Trap signals for cleanup
trap cleanup SIGINT SIGTERM

# Parse sync pairs from configuration
parse_paths() {
    local pair="$1"
    IFS=';' read -ra PATHS <<< "$pair"

    log_message "trace" "Parsed paths: ${PATHS[*]}"

    echo "${PATHS[@]}"
}

# Check for necessary commands and paths
check_requirements() {
    local error_code=0

    # Check if Docker command exists
    if ! command -v docker &> /dev/null; then
        log_message "error" "Docker command not found."
        ((error_code |= 1))
    fi

    # Check if specified Docker container exists and is active
    if [ "$(docker ps -q -f name="$DOCKER_CONTAINER_NAME")" == "" ]; then
        log_message "error" "Docker container '$DOCKER_CONTAINER_NAME' not found or not active."
        ((error_code |= 2))
    fi

    # Check if Unison command exists
    if ! command -v unison &> /dev/null; then
        log_message "error" "Unison command not found."
        ((error_code |= 4))
    fi

    # Check if inotifywait command exists
    if ! command -v inotifywait &> /dev/null; then
        log_message "error" "inotifywait command not found."
        ((error_code |= 8))
    fi

    # Check if source and target paths exist
    local pair_num=0
    for pair in "${SYNC_PAIRS[@]}"; do
        read -ra parsed_paths <<< "$(parse_paths "$pair")"
        SOURCE_PATH="${parsed_paths[0]}${parsed_paths[1]}"
        TARGET_PATH="${parsed_paths[2]}"
		echo "$SOURCE_PATH"
		echo "$TARGET_PATH"
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
    fi
}

# Sync content between source and target paths
sync_content() {
    local source_path="$1"
    local target_path="$2"
    local output
    local error

    # Perform Unison synchronization and capture its output and error
    if output=$(unison -auto -batch -prefer newer "$source_path" "$target_path" 2>&1); then
        log_message "trace" "Synchronization successful: $source_path to $target_path. Output: $output"
    else
        local exit_status=$?
        error=$output
        log_message "error" "Synchronization failed with status $exit_status: $source_path to $target_path. Error: $error"
    fi
}


# Update permissions of the target path
update_permissions() {
    local path="$1"
    local find_output
    local chown_output
    local error

    # Change permissions and capture output and error
    if find_output=$(find "$path" -exec chmod 0766 {} \; 2>&1); then
        log_message "trace" "Permissions updated successfully for path: $path. Output: $find_output"
    else
        error=$find_output
        log_message "error" "Error updating permissions for path: $path. Error: $error"
    fi

    # Change ownership and capture output and error
    if chown_output=$(chown -R 33:33 "$path" 2>&1); then
        log_message "trace" "Ownership updated successfully for path: $path. Output: $chown_output"
    else
        error=$chown_output
        log_message "error" "Error updating ownership for path: $path. Error: $error"
    fi
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
                if inotify_output=$(inotifywait -r -e modify,create,delete,move "$SOURCE_PATH" "$TARGET_PATH" 2>&1); then
                    log_message "trace" "inotifywait success: $inotify_output"
                else
                    log_message "error" "inotifywait failed: $inotify_output"
                    continue
                fi

                # Perform synchronization
                sync_content "$SOURCE_PATH" "$TARGET_PATH"
                
				# Execute the scanning of new or changed files by Nextcloud.
				if docker_output=$(docker exec --user $DOCKER_USERNAME $DOCKER_CONTAINER_NAME php occ files:scan --path="$NEXTCLOUD_PATH" 2>&1); then
                    log_message "trace" "Docker command success: $docker_output"
                else
                    log_message "error" "Docker command failed: $docker_output"
                    continue
                fi
				
				# Update permissions
                update_permissions "$TARGET_PATH"
            done
        ) &
    done
    wait
}

# Log start of script and check requirements
log_message "info" "### Start script ${APP_NAME} Version ${VERSION} ###"
check_requirements
monitor_and_sync
cleanup