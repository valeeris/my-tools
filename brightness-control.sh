#! /bin/zsh

max=400
min=1
current=$(brightnessctl -m | cut -d "," -f 3)

if [[ $1 == "up" ]]
then
	brightnessctl set $(expr $current + 25)
elif (( $current - 25 <= 2))
then
	brightnessctl set 1
else
	brightnessctl set $(expr $current - 25)	
fi

exit 0
