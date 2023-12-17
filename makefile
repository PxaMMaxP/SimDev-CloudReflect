# Makefile

# Verzeichnis, in dem sich das Makefile befindet
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Zielverzeichnisse für die Dateien, relativ zum Makefile-Verzeichnis
OPT_DIR := $(MAKEFILE_DIR)deb/opt/cloudreflect
ETC_DIR := $(MAKEFILE_DIR)deb/etc/cloudreflect
SYSTEMD_DIR := $(MAKEFILE_DIR)deb/etc/systemd/system
RELEASE_DIR := $(MAKEFILE_DIR)release

# Dateien, die kopiert werden sollen (mit relativen Pfaden)
OPT_FILES := cloudreflect.sh logging version
ETC_FILES := config.sample
SYSTEMD_FILES := cloudreflect.service

# Zielpfade für die Dateien
TARGET_OPT_FILES := $(addprefix $(OPT_DIR)/, $(OPT_FILES))
TARGET_ETC_FILES := $(addprefix $(ETC_DIR)/, $(ETC_FILES))
TARGET_SYSTEMD_FILES := $(addprefix $(SYSTEMD_DIR)/, $(SYSTEMD_FILES))

# Extrahieren der App-Namen und Version aus der 'version'-Datei
APP_NAME := $(shell grep 'APP_NAME=' version | cut -d'=' -f2)
VERSION := $(shell grep 'VERSION=' version | cut -d'=' -f2)

# Debian-Paketziel
deb: all
	@echo "Erstelle Debian-Paket in $(RELEASE_DIR)/$(APP_NAME)_$(VERSION).deb"
	@mkdir -p $(RELEASE_DIR)
	@dpkg-deb --build deb $(RELEASE_DIR)/$(APP_NAME)_$(VERSION).deb
	@echo "Debian-Paket $(APP_NAME)_$(VERSION).deb erstellt und im Release-Verzeichnis gespeichert."

# Standardziel: Kopieren und Berechtigungen festlegen
all: $(TARGET_OPT_FILES) $(TARGET_ETC_FILES) $(TARGET_SYSTEMD_FILES)
	@echo "Kopieren und Berechtigungen festlegen abgeschlossen."

# [Die restlichen Regeln bleiben gleich]

# "clean"-Ziel: Löscht die kopierten Dateien in den Zielpfaden
clean:
	@rm -rf $(TARGET_OPT_FILES) $(TARGET_ETC_FILES) $(TARGET_SYSTEMD_FILES) $(RELEASE_DIR)
	@echo "Zielverzeichnisse gelöscht."

# "clean", "all" und "deb" als Phony-Ziele deklarieren
.PHONY: all clean deb
