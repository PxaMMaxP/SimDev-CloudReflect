# Makefile

# Verzeichnis, in dem sich das Makefile befindet
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Zielverzeichnisse für die Dateien, relativ zum Makefile-Verzeichnis
OPT_DIR := $(MAKEFILE_DIR)deb/opt/cloudreflect
ETC_DIR := $(MAKEFILE_DIR)deb/etc/cloudreflect
SYSTEMD_DIR := $(MAKEFILE_DIR)deb/etc/systemd/system
RELEASE_DIR := $(MAKEFILE_DIR)release
DEBIAN_DIR := $(MAKEFILE_DIR)deb/DEBIAN

# Pfad zur control-Datei
CONTROL_FILE := $(DEBIAN_DIR)/control

# Dateien, die kopiert werden sollen (mit relativen Pfaden)
OPT_FILES := cloudreflect.sh logging version
ETC_FILES := config.sample
SYSTEMD_FILES := cloudreflect.service

# Zielpfade für die Dateien
TARGET_OPT_FILES := $(addprefix $(OPT_DIR)/, $(OPT_FILES))
TARGET_ETC_FILES := $(addprefix $(ETC_DIR)/, $(ETC_FILES))
TARGET_SYSTEMD_FILES := $(addprefix $(SYSTEMD_DIR)/, $(SYSTEMD_FILES))

# Extrahieren der App-Namen und Version aus der 'version'-Datei, ohne Anführungszeichen
APP_NAME := $(shell grep 'APP_NAME=' version | cut -d'=' -f2 | tr -d '"')
VERSION := $(shell grep 'VERSION=' version | cut -d'=' -f2 | tr -d '"')

# Ziel zum Aktualisieren der control-Datei
update-control:
	@sed -i 's/^Version:.*/Version: $(VERSION)/' $(CONTROL_FILE)

# Debian-Paketziel
deb: update-control all
	@echo "Erstelle Debian-Paket in $(RELEASE_DIR)/$(APP_NAME)_$(VERSION).deb"
	@mkdir -p $(RELEASE_DIR)
	@dpkg-deb --build deb $(RELEASE_DIR)/$(APP_NAME)_$(VERSION).deb
	@echo "Debian-Paket $(APP_NAME)_$(VERSION).deb erstellt und im Release-Verzeichnis gespeichert."

# Standardziel: Kopieren und Berechtigungen festlegen
all: $(TARGET_OPT_FILES) $(TARGET_ETC_FILES) $(TARGET_SYSTEMD_FILES)
	@echo "Kopieren und Berechtigungen festlegen abgeschlossen."

# Regel zum Kopieren der Dateien nach ./deb/opt/cloudreflect/ und Festlegen der Berechtigungen
$(OPT_DIR)/%: %
	@mkdir -p $(@D)
	@cp $< $@
	@chmod 744 $@
	@echo "Kopiere $< nach $@ und setze Berechtigungen auf 744"

# Regel zum Kopieren der Datei config.sample nach ./deb/etc/cloudreflect/ und Festlegen der Berechtigungen
$(ETC_DIR)/%: %
	@mkdir -p $(@D)
	@cp $< $@
	@chmod 644 $@
	@echo "Kopiere $< nach $@ und setze Berechtigungen auf 644"

# Regel zum Kopieren der Datei cloudreflect.service nach ./deb/etc/systemd/system/ und Festlegen der Berechtigungen
$(SYSTEMD_DIR)/%: %
	@mkdir -p $(@D)
	@cp $< $@
	@chmod 644 $@
	@echo "Kopiere $< nach $@ und setze Berechtigungen auf 644"

# "clean"-Ziel: Löscht die kopierten Dateien und die übergeordneten Verzeichnisse
clean:
	@rm -rf $(OPT_DIR) $(ETC_DIR) $(SYSTEMD_DIR) $(RELEASE_DIR)
	@echo "Zielverzeichnisse gelöscht."

# "clean", "all" und "deb" als Phony-Ziele deklarieren
.PHONY: all clean deb
