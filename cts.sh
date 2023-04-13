#! /bin/bash

STOPPOINTS_RAW=""
CACHE_FILE=~/.config/cts/stoppoints_cache.json
CONFIG_FILE=~/.config/cts/config
BASIC_TOKEN=""

mkdir -p ~/.config/cts

usage () {
    echo -e "$0: invalid command\nTry 'cts -h' for more information." >&2
}

help () {
    echo -e "Usage: cts [OPTIONS] COMMAND\n\
A quick way to get any information you need about the CTS public transport network\n\
\n\
Commands:\n\
    station <STATION CODE>  \tShow realtime for a station\n\
    line <LINE> \t\tAfter \"station\", specifies line\n\
    dir <DIRECTION> \t\tAfter \"station\" and \"line\", specifies direction\n\
\n\
Options:\n\
    -h | --help \t\t\tDisplay this help message\n\
    -l | --list (<KEYWORD>)\t\tList all stations with related informations (with name matching KEYWORD)\n\
    -s | --select\t\t\tAllows search and select in terminal to easily find real time for a station\n\
    -u | --update-cache\t\t\tUpdate the station cache file\n\
    -t | --token\t\t\tUpdate the API token used for queries">&2

}

fail () {
    echo $1 >&2
    exit 1
}

get_stoppoints () {
    if [[ "$STOPPOINTS_RAW" = "" ]]; then
        STOPPOINTS_RAW=$(curl -X 'GET' -Ss  \
            'https://api.cts-strasbourg.eu/v1/siri/2.0/stoppoints-discovery?includeLinesDestinations=true' \
            -H 'accept: text/plain' \
            -H 'Authorization: Basic '$BASIC_TOKEN)
    fi
    echo $STOPPOINTS_RAW
}

get_stopmonitoring () {
    if [[ -z "$2" ]]; then
        echo $(curl -X 'GET' -Ss  \
            'https://api.cts-strasbourg.eu/v1/siri/2.0/stop-monitoring?MonitoringRef='$(echo $1) \
            -H 'accept: text/plain' \
            -H 'Authorization: Basic '$BASIC_TOKEN)
     else
         echo $(curl -X 'GET' -Ss  \
             'https://api.cts-strasbourg.eu/v1/siri/2.0/stop-monitoring?MonitoringRef='$(echo $1)'&LineRef='$(echo $2) \
         -H 'accept: text/plain' \
         -H 'Authorization: Basic '$BASIC_TOKEN)
     fi
}

get_logicalstopcodes () {
    get_stoppoints | jq '[ .StopPointsDelivery.AnnotatedStopPointRef[].Extension.LogicalStopCode ] | unique | .[]'
}

get_clean_stoppointslist () {
    echo $(get_stoppoints \
        | jq '.StopPointsDelivery.AnnotatedStopPointRef[] | . + {LogicalStopCode: .Extension.LogicalStopCode}' \
        | jq --slurp '. | group_by(.LogicalStopCode) | .[] | try (.[0] + {LinesShort: [.[].Lines[].LineRef] | unique}) catch null | try ({StopName: .StopName, StopCode: .LogicalStopCode, Lines: .LinesShort}) catch null')
}

count_stoppoints () {
    get_stoppoints | jq '[ .StopPointsDelivery.AnnotatedStopPointRef[].Extension.LogicalStopCode ] | unique | length'
}

update_stoppoints_cache () {
    printf "Station cache updating... (this can take a few minutes)\n"
    touch $CACHE_FILE
    get_clean_stoppointslist > $CACHE_FILE
}

list_stoppoints () {
    jq -e 'try (.StopName+" ("+.StopCode+") ["+(.Lines | join(", "))+"]") catch null' $CACHE_FILE | tr -d "\""
}

get_clean_stopmonitoring () {
    data=""    
    if [[ -z "$2" ]]; then
        data=$(get_stopmonitoring $1)
    else
        data=$(get_stopmonitoring $1 $2)
    fi
    if [[ "$(echo $data | jq '(try .ServiceDelivery.StopMonitoringDelivery[].MonitoringRef[] catch "null")' | tr -d "\"")" -eq "null" ]]; then
        fail "Query failed. Are you sure your stopcode and/or lineref is right?"
    fi

    echo $data \
        | jq '.ServiceDelivery.StopMonitoringDelivery[].MonitoredStopVisit[].MonitoredVehicleJourney | .LineRef+" "+.DestinationName+" -- "+.MonitoredCall.ExpectedDepartureTime' \
        | sed --regexp-extended 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T([0-9]{2}:[0-9]{2}):[0-9]{2}\+02:00/\1/' \
        | tr -d "\"" \
        | while read x; do echo "$x -- $(date +%H:%M)"; done \
        | awk -F " -- " 'function time_details(A){split(A,X,":"); TOT=X[1] * 3600 + X[2] * 60 + X[3]; return TOT} {print $1 " -- " (time_details($2) - time_details($3))/60 " min"}'
}

update_token () {
    touch $CONFIG_FILE
    echo -n "$1:." | base64 > $CONFIG_FILE
}

check_token () {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        fail "No API token registered! Use $0 -t <TOKEN> to register yours."
        exit 0
    else
        BASIC_TOKEN=$(cat $CONFIG_FILE)
        if [[ -z "$BASIC_TOKEN" ]]; then
            fail "No API token registered! Use $0 -t <TOKEN> to register yours."
            exit 0
        fi
    fi
}

check_if_cache_outdated () {
    if [[ ! -f "$CACHE_FILE" ]] || [[ ! -s "$CACHE_FILE" ]] || [[ $((( ($(date +%s) - $(date -d "$(stat $CACHE_FILE | grep Modify | cut -d " " -f 2)" +%s)) / 86400 ))) -ge 7 ]]; then
        update_stoppoints_cache
    fi
}

check_arg_is_opt () {
    [[ "$1" = -* ]]
}

extract_stopcode_from_l () {
    echo $1 | cut -d "(" -f 2 | cut -d ")" -f 1
}

STATION=""
LINE=""
DIR=""
while [ "${1:-}" != "" ]; do
    case "$1" in
        "-h" | "--help")
            help
            exit 0
            ;;
        "-s" | "--select")
            check_token
            check_if_cache_outdated
            shift
            if $(check_arg_is_opt $1); then
                line=$(list_stoppoints | fzf) 
            elif [[ -z "$1" ]]; then
                line=$(list_stoppoints | fzf)
            else
                ret=$(list_stoppoints | grep --color -i $1)
                if [[ -z "$ret" ]]; then
                    fail "No station matching \"$1\". Are you sure your keyword is correct?"
                else
                    line=$(echo "$ret" | grep --color -i $1 | fzf)
                fi 
            fi
            STATION=$(extract_stopcode_from_l "$line")
            LINE=$(echo $line | cut -d "[" -f 2 | cut -d "]" -f 1 | tr -d " " | tr "," "\n" | fzf --tac)
            ;;
        "-l" | "--list")
            check_token
            check_if_cache_outdated
            shift
            if $(check_arg_is_opt $1); then
                list_stoppoints
            elif [[ -z "$1" ]]; then
                list_stoppoints
            else
                ret=$(list_stoppoints | grep --color -i $1)
                if [[ -z "$ret" ]]; then
                    fail "No station matching \"$1\". Are you sure your keyword is correct?"
                else
                    echo "$ret" | grep --color -i $1
                fi
            fi
            exit 0
            ;;
        "-u" | "--update-cache")
            check_token
            update_stoppoints_cache
            exit 0
            ;;
        "-t" | "--token")
            shift
            if $(check_arg_is_opt $1); then
                usage
                exit 1
            else
                update_token $1
                exit 0
            fi
            ;;
        "station")
            shift
            check_token
            if $(check_arg_is_opt $1); then
                usage
                exit 1
            else
                STATION=$1
            fi
            ;;
        "line")
            shift
            if $(check_arg_is_opt $1); then
                usage
                exit 1
            elif [[ -z "$STATION" ]]; then
                usage
                exit 1
            else
                LINE=$1
            fi
            ;;
        "dir")
            shift
            if $(check_arg_is_opt $1); then
                usage
                exit 1
            elif [[ -z "$STATION" ]]; then
                usage
                exit 1
            else
                DIR=$1
            fi
            ;;
        *)
            usage
            exit 1
            ;;
    esac
    shift
done


if [[ -z "$LINE" ]]; then
    get_clean_stopmonitoring $STATION | sort -s -k 1,2
else
    if [[ -z "$DIR" ]]; then
        get_clean_stopmonitoring $STATION $LINE | sort -s -k 1,2
    else
        ret=$(get_clean_stopmonitoring $STATION $LINE | grep --color -i $DIR)
        if [[ -z "$ret" ]]; then
            fail "No realtime matching \"$DIR\". Are you sure your keyword is correct?"
        else
            echo "$ret" | grep --color -i $DIR | sort -s -k 1,2
        fi
    fi
fi

exit 0
