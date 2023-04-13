#! /bin/bash

screens=$(xrandr | grep " connected" | egrep -o -i "[0-9]+x[0-9]+\+[0-9]+\+[0-9]+")
count=1
colors="yellow green red blue black white"
path="/home/gaelle/.custom-scripts/wallpaper-pics"
lockscreenid=$(xrandr | grep current |  cut -d "," -f 2 | egrep -o "[0-9]+ x [0-9]+" | tr -d " ")-$(echo $1 | rev | cut -d "/" -f 1 | rev | cut -d "." -f 1)

if [[ -f "$(echo $path)/lockscreen$(echo $lockscreenid).png" ]]; then
    echo "Lockscreen layout already exists. Exiting..."
    exit 0
fi

for screen in $screens; do
    if [[ "$1" == "color" ]]; then
        size=$(echo $screen | cut -d "+" -f 1)
        convert -size $size xc:$(echo $colors | cut -d " " -f $count) $(echo $path)/image$(echo $count).png
    elif [[ "$1" == *".jpg"* || $1 == *".png"* ]]; then
        width=$(echo $screen | cut -d "+" -f 1 | cut -d "x" -f 1)
        height=$(echo $screen | cut -d "+" -f 1 | cut -d "x" -f 2)
        convert $1 -resize "$width"x"$width" $(echo $path)/imagenocrop$(echo $count).png

        convert $(echo $path)/imagenocrop$(echo $count).png \
            -gravity center \
            -crop "$width"x"$height"+0+0 \
            +repage $(echo $path)/image$(echo $count).png
    fi
    count=$(expr $count + 1)
done

repages=""
count=1

for screen in $screens; do
    offsetw=$(echo $screen | cut -d "+" -f 2)
    offseth=$(echo $screen | cut -d "+" -f 3)
    repages="$repages ( $(echo $path)/image$count.png -repage +$offsetw+$offseth )"
    count=$(expr $count + 1)
done

convert $repages -layers merge $(echo $path)/lockscreen$(echo $lockscreenid).png
rm -f $(echo $path)/image*

exit 0

