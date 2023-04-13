#! /bin/bash

SDL_VIDEO_FULLSCREEN_HEAD=0

lockscreenid=$(xrandr | grep current |  cut -d "," -f 2 | egrep -o "[0-9]+ x [0-9]+" | tr -d " ")-$(echo $1 | rev | cut -d "/" -f 1 | rev | cut -d "." -f 1)

echo $lockscreenid
lockscreen-generator $1
i3lock -i /home/gaelle/.custom-scripts/wallpaper-pics/lockscreen$(echo $lockscreenid).png --nofork
