#!/bin/bash
# System einrichten (root). Reihenfolge zählt: der Bootloader kommt zuletzt, damit er die
# Bootparameter aus hardware/ und die snapper-Konfiguration schon vorfindet.
set -uo pipefail
. "$(dirname "$0")/../helpers/common.sh"
for part in locale keyboard hostname sudo zram services pacman snapper limine; do
    run_part "$ETUDE_INSTALL/config/$part.sh" 1 || exit 1
done
