#!/bin/bash
# ClamKeep Helper Daemon - runs as root via launchd
# Executes pmset commands triggered by the app

DAEMON_VERSION="1.3.0"
IPC_DIR="/Library/Application Support/com.m3etis.clamkeep"
TRIGGER_FILE="${IPC_DIR}/command"
RESULT_FILE="${TRIGGER_FILE}.result"

ALLOWED_COMMANDS="version enable disable display_enable display_disable status"

setup_ipc() {
    if [ ! -d "${IPC_DIR}" ]; then
        mkdir -p "${IPC_DIR}"
    fi
    chmod 1733 "${IPC_DIR}"
    chmod 600 "${TRIGGER_FILE}" 2>/dev/null || true
    chmod 644 "${RESULT_FILE}" 2>/dev/null || true
}

setup_ipc

save_display_settings() {
    local saved_file="${IPC_DIR}/displaysleep.saved"
    if [ -f "${saved_file}" ]; then
        return
    fi
    DISPLAYSLEEP=$(/usr/bin/pmset -g | awk '/displaysleep/ {print $2}')
    echo "${DISPLAYSLEEP:-10}" > "${saved_file}"
    chmod 600 "${saved_file}"
}

restore_display_settings() {
    local saved_file="${IPC_DIR}/displaysleep.saved"
    if [ -f "${saved_file}" ]; then
        SAVED=$(cat "${saved_file}")
        /usr/bin/pmset -a displaysleep "${SAVED}" 2>&1
        rm -f "${saved_file}"
    else
        /usr/bin/pmset -a displaysleep 10 2>&1
    fi
}

is_valid_command() {
    local cmd="$1"
    for allowed in ${ALLOWED_COMMANDS}; do
        if [ "${cmd}" = "${allowed}" ]; then
            return 0
        fi
    done
    return 1
}

while true; do
    if [ -f "${TRIGGER_FILE}" ]; then
        CMD=$(cat "${TRIGGER_FILE}")
        RESULT_FILE="${TRIGGER_FILE}.result"

        if ! is_valid_command "${CMD}"; then
            echo "error unknown_command" > "${RESULT_FILE}"
            chmod 644 "${RESULT_FILE}"
            rm -f "${TRIGGER_FILE}"
            sleep 0.2
            continue
        fi

        if [ "$CMD" = "version" ]; then
            echo "ok ${DAEMON_VERSION}" > "${RESULT_FILE}"
        elif [ "$CMD" = "enable" ]; then
            /usr/bin/pmset -a disablesleep 1 2>&1
            echo "ok $?" > "${RESULT_FILE}"
        elif [ "$CMD" = "disable" ]; then
            /usr/bin/pmset -a disablesleep 0 2>&1
            echo "ok $?" > "${RESULT_FILE}"
        elif [ "$CMD" = "display_enable" ]; then
            save_display_settings
            /usr/bin/pmset -a displaysleep 0 2>&1
            echo "ok $?" > "${RESULT_FILE}"
        elif [ "$CMD" = "display_disable" ]; then
            restore_display_settings
            echo "ok 0" > "${RESULT_FILE}"
        elif [ "$CMD" = "status" ]; then
            STATUS=$(/usr/bin/pmset -g | grep -c "SleepDisabled.*1")
            echo "ok ${STATUS}" > "${RESULT_FILE}"
        fi

        chmod 644 "${RESULT_FILE}"
        rm -f "${TRIGGER_FILE}"
    fi
    sleep 0.2
done
