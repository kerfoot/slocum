#! /bin/bash --

PATH=/bin:/usr/bin;

app=$(basename $0);

# Usage message
USAGE="
NAME
    $app - return the dbd file open time as an epoch timestamp

SYNOPSIS
    $app [htf] DBD_FILE

DESCRIPTION

    Greps the ASCII header of the binary encoded dbd file for
    'fileopen_time:' and convert the timestamp (if found) to the unix epoch
    time (UTC).  If not found, -1 is returned

    -h
        show help message

    -t
        format timestamp as a date-time string

    -f
        append the filename and print as a csv record

";

# Process options
while getopts "htf" option
do
    case "$option" in
        "h")
            echo -e "$USAGE";
            exit 0;
            ;;
        "t")
            timestamp=1;
            ;;
        "f")
            filename=1;
            ;;
        "*")
            echo -e "Invalid option specified: $option\n$USAGE" >&2;
            exit 1;
            ;;
    esac
done

# Remove option from $@
shift $((OPTIND-1));

if [ "$#" -eq 0 ]
then
    echo "Please specify one or more dbd files to parse." >&2;
    echo -1;
    exit 1;
fi

status=0;
for dinkum in "$@"
do
    # Grep and clean the first 'Curr Time:' in the file
    # Example: fileopen_time:    Fri_Oct__5_14:24:03_2012
    ts=$(head -10 "$dinkum" | grep 'fileopen_time:' | sed -e 's/^fileopen_time: *//g' -e 's/_/ /g');
    # If not found, return -1 and exit status 0
    if [ -z "$ts" ]
    then
        echo "$dinkum: failed to parse fileopen_time" >&2;
        status=1;
        continue;
    fi
    
    # Convert the timestamp to epoch time
    epoch=$(date --utc +'%s' --date="$ts");
    # If conversion error, return -1 and exit status 1
    if [ -z "$epoch" ]
    then
        echo "$dinkum: failed to parse fileopen_time" >&2;
        status=1;
        continue;
    fi

    if [ -n "$timestamp" ]
    then
        if [ -n "$filename" ]
        then
            echo -n "$(date --utc +'%Y-%m-%dT%H:%M:%S' --date=@"$epoch"),";
        else
            echo "$(date --utc +'%Y-%m-%dT%H:%M:%S' --date=@"$epoch")";
        fi
    else
        if [ -n "$filename" ]
        then
            echo -n "${epoch},";
        else
            echo "${epoch}";
        fi
    fi

    [ -z "$filename" ] && continue;

    echo "$dinkum";

done

exit $status;

