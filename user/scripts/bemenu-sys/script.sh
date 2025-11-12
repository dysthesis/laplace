#!/usr/bin/env bash

case "$(printf "Kill\nSuspend\nReboot\nShutdown" | bemenu -i -l 4)" in
Kill) ps -u $USER -o pid,comm,%cpu,%mem | tail -n +2 | bemenu -i -l 10 -p Kill: | awk '{print $1}' | xargs -r kill ;;
Suspend) slock systemctl suspend -i ;;
Reboot) systemctl reboot -i ;;
Shutdown) shutdown now ;;
*) exit 1 ;;
esac
