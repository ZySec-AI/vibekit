---
description: Install, uninstall, start, stop, and monitor the vibekit autonomous daemon.
argument-hint: [install|uninstall|start|stop|status|logs]
model: sonnet
allowed-tools: Bash(gh:*), Bash(git:*), Bash(launchctl:*), Bash(chmod:*), Bash(mkdir:*), Read, Write, Edit
---

# /vb-daemon

Manages the vibekit autonomous daemon — a background process that polls for open GitHub issues every 3 minutes and runs `/vb-build --once` automatically. No Claude session needs to stay open.

## Arguments

```
$ARGUMENTS
```

- `install` — install the daemon (launchd on macOS, cron on Linux) and start it
- `uninstall` — stop and remove the daemon
- `start` — start a previously installed daemon
- `stop` — stop the running daemon without uninstalling
- `status` — show daemon status, last run time, recent log lines
- `logs` — tail the daemon log (last 50 lines)
- *(no args)* — show status

---

## Detect project

```bash
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
VIBEKIT_DIR="$PROJECT_ROOT/.vibekit"
REPO_NAME="$(basename "$PROJECT_ROOT" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
DAEMON_LABEL="com.vibekit.${REPO_NAME}.daemon"
PLIST_PATH="$HOME/Library/LaunchAgents/${DAEMON_LABEL}.plist"
# Support both global (~/.vibekit/daemon.sh) and project-local (.vibekit/daemon.sh)
if [ -f "$VIBEKIT_DIR/daemon.sh" ]; then
  DAEMON_SCRIPT="$VIBEKIT_DIR/daemon.sh"
elif [ -f "$HOME/.vibekit/daemon.sh" ]; then
  DAEMON_SCRIPT="$HOME/.vibekit/daemon.sh"
else
  DAEMON_SCRIPT="$VIBEKIT_DIR/daemon.sh"
fi
LOG_FILE="$VIBEKIT_DIR/daemon.log"
PLATFORM="$(uname -s)"
```

---

## `install`

### macOS (launchd)

1. Confirm `daemon.sh` exists:
```bash
[ -f "$DAEMON_SCRIPT" ] || { echo "ERROR: $DAEMON_SCRIPT not found. Run /vb-setup first."; exit 1; }
```

2. Resolve full paths for launchd (it runs without $PATH):
```bash
CLAUDE_BIN="$(which claude 2>/dev/null || echo "/usr/local/bin/claude")"
GH_BIN="$(which gh 2>/dev/null || echo "/usr/local/bin/gh")"
```

3. Write plist to `~/Library/LaunchAgents/`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${DAEMON_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${DAEMON_SCRIPT}</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${PROJECT_ROOT}</string>
  <key>StartInterval</key>
  <integer>180</integer>
  <key>RunAtLoad</key>
  <false/>
  <key>StandardOutPath</key>
  <string>${LOG_FILE}</string>
  <key>StandardErrorPath</key>
  <string>${LOG_FILE}</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key>
    <string>${HOME}</string>
  </dict>
  <key>ThrottleInterval</key>
  <integer>60</integer>
</dict>
</plist>
```

Replace `${DAEMON_LABEL}`, `${DAEMON_SCRIPT}`, `${PROJECT_ROOT}`, `${LOG_FILE}`, `${HOME}` with actual resolved values using bash variable substitution when writing the file.

4. Load and start:
```bash
launchctl load "$PLIST_PATH"
launchctl start "$DAEMON_LABEL"
```

5. Confirm:
```
Daemon installed: $DAEMON_LABEL
Polls every: 3 minutes
Log: $LOG_FILE
Run /vb-daemon status to verify.
```

### Linux (cron fallback)

If `$PLATFORM` is `Linux`:
```bash
CRON_LINE="*/3 * * * * cd $PROJECT_ROOT && bash $DAEMON_SCRIPT >> $LOG_FILE 2>&1"
( crontab -l 2>/dev/null | grep -v "com.vibekit.${REPO_NAME}"; echo "# com.vibekit.${REPO_NAME}"; echo "$CRON_LINE" ) | crontab -
```
Print: `Daemon installed via cron (every 3 minutes). Log: $LOG_FILE`

---

## `uninstall`

### macOS:
```bash
launchctl stop "$DAEMON_LABEL" 2>/dev/null || true
launchctl unload "$PLIST_PATH" 2>/dev/null || true
rm -f "$PLIST_PATH"
rm -f "$VIBEKIT_DIR/daemon.lock"
```
Print: `Daemon uninstalled.`

### Linux:
```bash
( crontab -l 2>/dev/null | grep -v "com.vibekit.${REPO_NAME}" ) | crontab -
```

---

## `start`

```bash
[ -f "$PLIST_PATH" ] || { echo "Daemon not installed. Run /vb-daemon install first."; exit 1; }
launchctl start "$DAEMON_LABEL"
echo "Daemon started."
```

---

## `stop`

```bash
launchctl stop "$DAEMON_LABEL" 2>/dev/null || true
rm -f "$VIBEKIT_DIR/daemon.lock"
echo "Daemon stopped."
```

---

## `status` (default)

```bash
echo "=== vibekit daemon — ${REPO_NAME} ==="
echo "Label:   $DAEMON_LABEL"
echo "Script:  $DAEMON_SCRIPT"
echo "Log:     $LOG_FILE"
echo ""

# Installed?
if [ -f "$PLIST_PATH" ]; then
  echo "Installed: yes ($PLIST_PATH)"
else
  echo "Installed: no — run /vb-daemon install"
fi

# Running?
if launchctl list 2>/dev/null | grep -q "$DAEMON_LABEL"; then
  LAST_EXIT=$(launchctl list 2>/dev/null | grep "$DAEMON_LABEL" | awk '{print $2}')
  echo "Status:    running (last exit: ${LAST_EXIT:-0})"
else
  echo "Status:    not running"
fi

# Lock file?
if [ -f "$VIBEKIT_DIR/daemon.lock" ]; then
  LOCK_PID=$(cat "$VIBEKIT_DIR/daemon.lock")
  echo "Lock:      held by pid $LOCK_PID"
fi

# Last run from log
if [ -f "$LOG_FILE" ]; then
  echo ""
  echo "Last 5 log lines:"
  tail -5 "$LOG_FILE"
fi
echo "======================================="
```

---

## `logs`

```bash
[ -f "$LOG_FILE" ] || { echo "No log file yet at $LOG_FILE"; exit 0; }
tail -50 "$LOG_FILE"
```

---

## Notes

- The daemon uses a lock file (`$VIBEKIT_DIR/daemon.lock`) to prevent overlapping runs
- Logs rotate automatically at 2000 lines
- The daemon auto-triggers `/vb-launch` when zero open bugs remain
- On macOS, `launchd` survives reboots — the daemon restarts automatically
- To check why a run failed: `/vb-daemon logs`
- The daemon runs with `claude --print` (non-interactive, exits after task)
