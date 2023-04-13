#! /bin/bash

case $1 in
    scalingo)
        if $(xrandr | grep --regex '^DP-1' | grep -q disconnected); then
            output="DP-3"
        else
            output="DP-1"
        fi
        xrandr --output eDP-1 --primary --mode 3456x2160 --pos 0x2880 --rotate normal --scale 1x1 \
               --output $output --mode 2560x1440 --pos 0x0 --rotate normal --scale 2x2
        i3-msg "workspace 4, move workspace to output up"
        i3-msg "workspace 5, move workspace to output up"
        ;;
    off)
        xrandr --output DP-1 --off \
               --output HDMI-1 --off \
               --output DP-2 --off \
               --output DP-3 --off \
               --output DP-4 --off
        ;;
    *)
        echo "Unrecognized input."
        ;;
esac

exit 0
