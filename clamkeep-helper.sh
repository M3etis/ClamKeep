#!/bin/bash
# ClamKeep Helper Daemon - runs as root via launchd
# Executes pmset commands triggered by the app

DAEMON_VERSION="1.2.0"
TRIGGER_DIR="/tmp/clamkeep"
TRIGGER_FILE="${TRIGGER_DIR}/command"
SCREENSAVER_PLIST_BASE="/Library/Preferences/com.apple.screensaver"
mkdir -p "${TRIGGER_DIR}"
chmod 1777 "${TRIGGER_DIR}"

save_display_settings() {
    # Save current display sleep value
    DISPLAYSLEEP=$(/usr/bin/pmset -g | awk '/displaysleep/ {print $2}')
    echo "${DISPLAYSLEEP:-10}" > "${TRIGGER_DIR}/displaysleep.saved"
    chmod 644 "${TRIGGER_DIR}/displaysleep.saved"
}

restore_display_settings() {
    if [ -f "${TRIGGER_DIR}/displaysleep.saved" ]; then
        SAVED=$(cat "${TRIGGER_DIR}/displaysleep.saved")
        /usr/bin/pmset -a displaysleep "${SAVED}" 2>&1
        rm -f "${TRIGGER_DIR}/displaysleep.saved"
    else
        /usr/bin/pmset -a displaysleep 10 2>&1
    fi
}

disable_screen_lock() {
    # Disable password requirement after screensaver/sleep for ALL users
    for USER_HOME in /Users/*; do
        [ -d "${USER_HOME}" ] || continue
        USER_NAME=$(basename "${USER_HOME}")
        [ "${USER_NAME}" = "Shared" ] && continue
        [ "${USER_NAME}" = ".localized" ] && continue
        # Write as the actual user to avoid ownership issues
        /usr/bin/sudo -u "${USER_NAME}" /usr/bin/defaults write com.apple.screensaver askForPassword -int 0 2>/dev/null
        /usr/bin/sudo -u "${USER_NAME}" /usr/bin/defaults write com.apple.screensaver askForPasswordDelay -int 0 2>/dev/null
    done
    # Force cfprefsd to re-read from disk
    killall cfprefsd 2>/dev/null || true
}

while true; do
    if [ -f "${TRIGGER_FILE}" ]; then
        CMD=$(cat "${TRIGGER_FILE}")
        RESULT_FILE="${TRIGGER_FILE}.result"

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
            disable_screen_lock
            echo "ok $?" > "${RESULT_FILE}"
        elif [ "$CMD" = "display_disable" ]; then
            restore_display_settings
            echo "ok 0" > "${RESULT_FILE}"
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
