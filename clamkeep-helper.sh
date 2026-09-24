#!/bin/bash
# ClamKeep Helper Daemon - runs as root via launchd
# Executes pmset commands triggered by the app
#
# Security:
#   - single instance (lockf)
#   - trigger file must be a regular file owned by the installed UID
#   - trigger must not be world-writable
#   - command allowlist only (no shell interpolation)

DAEMON_VERSION="1.4.0"
IPC_DIR="/Library/Application Support/com.m3etis.clamkeep"
TRIGGER_FILE="${IPC_DIR}/command"
RESULT_FILE="${TRIGGER_FILE}.result"
ALLOWED_UID_FILE="${IPC_DIR}/allowed_uid"
LOCK_FILE="/var/run/clamkeep-helper.lock"

ALLOWED_COMMANDS="version enable disable display_enable display_disable status"

# --- singleton ----------------------------------------------------------------
# Re-exec under lockf so a stray user-owned copy cannot race the launchd daemon.
if [ -z "${CLAMKEEP_HELPER_LOCKED:-}" ]; then
    export CLAMKEEP_HELPER_LOCKED=1
    exec /usr/bin/lockf -s -t 0 "${LOCK_FILE}" "$0" "$@"
fi

setup_ipc() {
    if [ ! -d "${IPC_DIR}" ]; then
        mkdir -p "${IPC_DIR}"
    fi
    # 1733: sticky + owner/group/other write so the (non-root) app can drop a
    # trigger without being in staff. Authentication is ownership of the trigger
    # (see is_valid_trigger) — not directory ACLs. Sticky prevents deleting
    # another account's files.
    chown root:wheel "${IPC_DIR}" 2>/dev/null || true
    chmod 1733 "${IPC_DIR}"
    chmod 600 "${TRIGGER_FILE}" 2>/dev/null || true
    chmod 644 "${RESULT_FILE}" 2>/dev/null || true
    chmod 600 "${ALLOWED_UID_FILE}" 2>/dev/null || true
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

# Reject untrusted trigger files: wrong type, owner, or mode.
is_valid_trigger() {
    local file="$1"

    [ -f "${file}" ] || return 1
    [ ! -L "${file}" ] || return 1

    local owner_uid mode
    owner_uid=$(/usr/bin/stat -f%u "${file}" 2>/dev/null) || return 1
    mode=$(/usr/bin/stat -f%Lp "${file}" 2>/dev/null) || return 1

    # Must not be world-writable (tamperable by other accounts).
    # Check only the "others" write bit, not owner/group digits (600 has a 6).
    if [ $(( 0${mode} & 2 )) -ne 0 ]; then
        return 1
    fi

    # Prefer the UID captured at install time.
    if [ -f "${ALLOWED_UID_FILE}" ]; then
        local allowed_uid
        allowed_uid=$(cat "${ALLOWED_UID_FILE}" 2>/dev/null | tr -cd '0-9')
        if [ -n "${allowed_uid}" ] && [ "${owner_uid}" = "${allowed_uid}" ]; then
            return 0
        fi
        return 1
    fi

    # Fallback (no install fingerprint): accept only the active console user.
    local console_uid
    console_uid=$(/usr/bin/stat -f%u /dev/console 2>/dev/null) || return 1
    [ "${owner_uid}" = "${console_uid}" ] || return 1
    # And only a normal user account.
    [ "${owner_uid}" -ge 501 ] || return 1
    return 0
}

write_result() {
    local body="$1"
    # Atomic replace so a half-written result is never observed.
    local tmp="${RESULT_FILE}.$$"
    echo "${body}" > "${tmp}" 2>/dev/null || true
    chmod 644 "${tmp}" 2>/dev/null || true
    mv -f "${tmp}" "${RESULT_FILE}" 2>/dev/null || echo "${body}" > "${RESULT_FILE}"
    chmod 644 "${RESULT_FILE}" 2>/dev/null || true
}

while true; do
    if [ -f "${TRIGGER_FILE}" ]; then
        if ! is_valid_trigger "${TRIGGER_FILE}"; then
            write_result "error untrusted_trigger"
            rm -f "${TRIGGER_FILE}" 2>/dev/null || true
            sleep 0.2
            continue
        fi

        CMD=$(cat "${TRIGGER_FILE}" 2>/dev/null)
        # Collapse to a single line / token — never interpolate into a shell.
        CMD=$(printf '%s' "${CMD}" | tr -cd 'a-zA-Z0-9_-' | head -c 32)

        if ! is_valid_command "${CMD}"; then
            write_result "error unknown_command"
            rm -f "${TRIGGER_FILE}" 2>/dev/null || true
            sleep 0.2
            continue
        fi

        if [ "$CMD" = "version" ]; then
            write_result "ok ${DAEMON_VERSION}"
        elif [ "$CMD" = "enable" ]; then
            /usr/bin/pmset -a disablesleep 1 2>&1
            write_result "ok $?"
        elif [ "$CMD" = "disable" ]; then
            /usr/bin/pmset -a disablesleep 0 2>&1
            write_result "ok $?"
        elif [ "$CMD" = "display_enable" ]; then
            save_display_settings
            /usr/bin/pmset -a displaysleep 0 2>&1
            write_result "ok $?"
        elif [ "$CMD" = "display_disable" ]; then
            restore_display_settings
            write_result "ok 0"
        elif [ "$CMD" = "status" ]; then
            STATUS=$(/usr/bin/pmset -g | grep -c "SleepDisabled.*1")
            write_result "ok ${STATUS}"
        fi

        rm -f "${TRIGGER_FILE}" 2>/dev/null || true
    fi
    sleep 0.2
done
