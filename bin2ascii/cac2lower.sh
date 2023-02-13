#! /bin/bash --
#
# ============================================================================
# $RCSfile$
# $Source$
# $Revision$
# $Date$
# $Author$
# $Name$
# ============================================================================
#

PATH=${PATH}:/bin;

app=$(basename $0);

# Usage message
USAGE="
NAME
    $app - write lower cased slocum glider dbd .cac files

SYNOPSIS
    $app [h] file1[ file2 ...]

DESCRIPTION
    Create lower cased .cac files used to decode slocum binary *.*bd files

    -h
        show help message

    -d
        specify an alternate destination directory

";

# Default values for options
# Process options
while getopts "hd:" option
do
    case "$option" in
        "h")
            echo -e "$USAGE";
            exit 0;
            ;;
        "d")
            WRITE_DIR=$OPTARG;
            ;;
        "?")
            echo -e "$USAGE";
            exit 1;
            ;;
    esac
done

if [ -n "$WRITE_DIR" -a ! -d "$WRITE_DIR" ]
then
    echo "Invalid cache directory specified: $WRITE_DIR!" >&2;
    exit 1;
fi

# Remove option from $@
shift $((OPTIND-1));

for f in $@
do

    # Get extension
    ext=${f:(-4)};
    # Must be capitalized
    [ "$ext" != '.CAC' -a "$ext" != '.cac' ] && continue;

    # Get the path to the file
    p=$(dirname $f);
    # Get the filename
    cac=$(basename $f);

    # Translate all upper case letters to lower case
    lc=$(echo $cac | tr '[A-Z]' '[a-z]');
    [ -z "$lc" ] && continue;

    # Create the copy using the lower case name
    if [ -n "$WRITE_DIR" ]
    then
        destFile="${WRITE_DIR}/${lc}";
    else
        destFile="${p}/${lc}";
    fi

    if [ -f "$destFile" ]
    then
	    oldSize=$(stat --format=%s $f);
	    newSize=$(stat --format=%s $destFile);
        if [ "$oldSize" -eq "$newSize" ]
        then
            continue;
        fi
    fi

    echo "Writing $destFile";

    cp $f $destFile;

done
