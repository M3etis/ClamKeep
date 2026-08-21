#!/bin/bash
# ClamKeep Helper Daemon - runs as root via launchd
# Executes pmset commands triggered by the app

TRIGGER_DIR="/tmp/clamkeep"
TRIGGER_FILE="${TRIGGER_DIR}/command"
mkdir -p "${TRIGGER_DIR}"
chmod 1777 "${TRIGGER_DIR}"

while true; do
    if [ -f "${TRIGGER_FILE}" ]; then
        CMD=$(cat "${TRIGGER_FILE}")
        RESULT_FILE="${TRIGGER_FILE}.result"

        if [ "$CMD" = "enable" ]; then
            /usr/bin/pmset -a disablesleep 1 2>&1
            echo "ok $?" > "${RESULT_FILE}"
        elif [ "$CMD" = "disable" ]; then
            /usr/bin/pmset -a disablesleep 0 2>&1
            echo "ok $?" > "${RESULT_FILE}"
        elif [ "$CMD" = "status" ]; then
            STATUS=$(/usr/bin/pmset -g | grep -c "SleepDisabled.*1")
            echo "ok ${STATUS}" > "${RESULT_FILE}"
        else
            echo "error unknown_command" > "${RESULT_FILE}"
        fi

        chmod 644 "${RESULT_FILE}"
        rm -f "${TRIGGER_FILE}"
    fi
    sleep 0.2
done
