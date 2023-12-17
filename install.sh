#!/bin/bash

# Standardpfade
SCRIPT_DIR="$(dirname "$0")"
CONFIG_FILE="${SCRIPT_DIR}/config"
BIN_DIR="/usr/local/bin"

# Hilfe-Funktion
show_help() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -h, --help                   Show this help message and exit."
    echo "  --install                    Install the script and create systemd service."
    echo "  --uninstall                  Uninstall the script and systemd service."
    exit 0
}

# Service-Name aus der Konfigurationsdatei lesen
read_service_name() {
    source "${CONFIG_FILE}"
    echo "${SERVICE_NAME}"
}

# Install-Funktion
install() {
    echo "Starting installation..."

    # Service-Name abfragen
    read -p "Enter the name for the systemd service (e.g., cloud-sync): " SERVICE_NAME

    # Update SERVICE_NAME in der Konfigurationsdatei
	if grep -q "SERVICE_NAME=" "${CONFIG_FILE}"; then
		# SERVICE_NAME in der Datei aktualisieren
		sed -i "s/SERVICE_NAME=\".*\"/SERVICE_NAME=\"$SERVICE_NAME\"/" "${CONFIG_FILE}"
	else
		# SERVICE_NAME zur Datei hinzufügen
		echo "SERVICE_NAME=\"$SERVICE_NAME\"" >> "${CONFIG_FILE}"
	fi

    # Erstellen der systemd Service-Datei
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Cloud WWW Sync Service
After=docker.service network.target
PartOf=docker.service

[Service]
ExecStart=${BIN_DIR}/cloud-www-sync.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    # Setzen der Berechtigungen für die Service-Datei
    chmod 644 "${SERVICE_FILE}"

    # Systemd daemon neu laden
    systemctl daemon-reload
	
	# Erstellen des symbolischen Links für das Skript
    ln -sf "${SCRIPT_DIR}/cloud-www-sync.sh" "${BIN_DIR}/cloud-www-sync.sh"

    # Den Service nicht aktivieren
    systemctl enable "${SERVICE_NAME}"

    echo "Installation completed. Service created but and enabled."
}

# Uninstall-Funktion
uninstall() {
    echo "Uninstalling script and systemd service..."

     # Service-Name aus der Konfigurationsdatei lesen
    SERVICE_NAME=$(read_service_name)

    # Den Service stoppen und deaktivieren
    systemctl stop "${SERVICE_NAME}"
    systemctl disable "${SERVICE_NAME}"

    # Entfernen des symbolischen Links
    rm -f "${BIN_DIR}/cloud-www-sync.sh"

    # Service-Datei entfernen
    rm -f "${SERVICE_FILE}"

    # Systemd daemon neu laden
    systemctl daemon-reload

    echo "Uninstallation completed."
}

# Überprüfen, ob Argumente übergeben wurden
if [ "$#" -eq 0 ]; then
    show_help
    exit 0
fi

# Argumente verarbeiten
while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help) show_help ;;
        --install) install; exit 0 ;;
        --uninstall) uninstall; exit 0 ;;
        *) echo "Unknown option: $1"; show_help ;;
    esac
    shift
done