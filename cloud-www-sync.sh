#!/bin/bash

SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/config"

# Funktion zum Synchronisieren von Inhalten
sync_content() {
    local source_path="$1"
    local target_path="$2"

    # Unison Synchronisation
    unison -auto -batch -prefer newer "$source_path" "$target_path"
}

# Funktion zum Aktualisieren von Berechtigungen
update_permissions() {
    local path="$1"

    # Berechtigungen und Besitzer ändern
    find "$path" -exec chmod 0664 {} \;
    chown -R 33:33 "$path"
}

# Funktion zur Überwachung und Synchronisation
monitor_and_sync() {
    while true; do
        # Warten auf Dateiänderungen
        inotifywait -r -e modify,create,delete,move "${NEXTCLOUD_DATA_PATH}${NEXTCLOUD_PATH}"

        # Synchronisation und Aktualisierung
        sync_content "${NEXTCLOUD_DATA_PATH}${NEXTCLOUD_PATH}/content" "${CONTAINER_PATH}/content"
        sync_content "${NEXTCLOUD_DATA_PATH}${NEXTCLOUD_PATH}/assets" "${CONTAINER_PATH}/assets"

        # Nextcloud-Dateien scannen
        docker exec --user www-data nextcloud-app php occ files:scan --path="${NEXTCLOUD_PATH}/"

        # Berechtigungen und Besitzer aktualisieren
        update_permissions "${CONTAINER_PATH}/content"
        update_permissions "${CONTAINER_PATH}/assets"
    done
}

# Hauptteil des Skripts
monitor_and_sync