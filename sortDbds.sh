#! /bin/bash --

PATH=${PATH}:/bin;

app=$(basename $0);

# Usage message
USAGE="
NAME
    $app - convert Slocum glider data file fileopen_times to epoch times

SYNOPSIS
    $app [hi]

DESCRIPTION
    Greps each file for the fileopen_time header line and converts the
    timestamp to a unix epoch time.  Prints the epoch time and filename to
    STDOUT.

    The list of filenames can be displayed in ascending chronological order by
    piping the output of this script to sort and then to awk and printing the
    second field as follows:

    > sortDbds.sh *.mrg | sort | awk '{print \$2}'
    
    -h
        show help message
    -i
        print parsed timestamps as ISO8601 formatted timestamps.  Use of this
        option will still result in proper sorting order via the pipe
        described above.
";

# Process options
while getopts "hi" option
do
    case "$option" in
        "h")
            echo -e "$USAGE";
            exit 0;
            ;;
        "i")
            ISO=1;
            ;;
        "?")
            echo -e "$USAGE" >&2;
            exit 1;
            ;;
    esac
done

# Remove option from $@
shift $((OPTIND-1));

# Make sure one or more files were specified
if [ "$#" -eq 0 ]
then
    echo "No files specified" >&2;
    exit 1;
fi

for dbd in $@
do

    # Grep the file for the fileopen_time header line
    openTime=$(grep fileopen_time $dbd | awk '{print $2}');
    # Skip if the header line is not found
    if [ -z "$openTime" ]
    then
        echo "$dbd: No fileopen_time header line found" >&2;
        continue;
    fi

    # Piece together the date/time pieces
    month=$(echo $openTime | awk 'BEGIN { FS = "__?" } ; { print $2 }');
    d=$(echo $openTime | awk 'BEGIN { FS = "__?" } ; { print $3 }');
    day=$(printf %02d $d);
    hms=$(echo $openTime | awk 'BEGIN { FS = "__?" } ; { print $4 }');
    year=$(echo $openTime | awk 'BEGIN { FS = "__?" } ; { print $5 }');

    if [ -z "$ISO" ] # Epoch timestamps
    then
	    # Create the timestamp
	    ts="${month} ${day} ${year} ${hms}";

	    # Convert the timestamp to epoch time and print it along with the filename
	    echo "$(date --utc +%s --date="$ts") $dbd";

    else # ISO8601 timestamps

        # Convert 3 letter month abbreviation to numeric equivalent
        if [ "$month" == 'Jan' ]
        then
            m='01'
        elif [ "$month" == 'Feb' ]
        then
            m='02'
        elif [ "$month" == 'Mar' ]
        then
            m='03'
        elif [ "$month" == 'Apr' ]
        then
            m='04'
        elif [ "$month" == 'May' ]
        then
            m='05'
        elif [ "$month" == 'Jun' ]
        then
            m='06'
        elif [ "$month" == 'Jul' ]
        then
            m='07'
        elif [ "$month" == 'Aug' ]
        then
            m='08'
        elif [ "$month" == 'Sep' ]
        then
            m='09'
        elif [ "$month" == 'Oct' ]
        then
            m='10'
        elif [ "$month" == 'Nov' ]
        then
            m='11'
        elif [ "$month" == 'Dec' ]
        then
            m='12'
        fi

        echo "${year}-${m}-${day}T${hms} $(basename $dbd)";

    fi

done

