#!/bin/bash
# Toggle a window to/from scratchpad by app name
# Usage: scratchpad-toggle.sh <app-pattern>

APP="$1"

# Check if there's a matching window in the scratchpad
IN_SCRATCHPAD=$(aerospace list-windows --workspace .scratchpad | grep -i "$APP" | head -1)

if [[ -n "$IN_SCRATCHPAD" ]]; then
    # Window is in scratchpad → move it here and focus
    WINDOW_ID=$(echo "$IN_SCRATCHPAD" | awk '{print $1}')
    aerospace move-node-to-workspace --window-id "$WINDOW_ID" --focus-follows-window "$(aerospace list-workspaces --focused)"
    aerospace layout --window-id "$WINDOW_ID" floating
else
    # Check if focused window matches the app
    FOCUSED=$(aerospace list-windows --focused | grep -i "$APP")
    if [[ -n "$FOCUSED" ]]; then
        # Move focused window to scratchpad
        aerospace move-node-to-workspace .scratchpad
    fi
fi
