#! /bin/bash

script=$(realpath $0);
app=$(basename $script);
workpath=$(dirname $script);

PATH=/bin:/usr/bin:${workpath}/..;

# Default values for options

# Usage message
USAGE="
NAME
    $app - decompress one or more dinkum compressed data glider files

SYNOPSIS
    $app [hxc] [-o DIRECTORY] [-e EXE_DIRECTORY]

DESCRIPTION

    Attempts to decompress each dinkum compressed data (*.*cd) file specified o the command line.
    Each decompressed file is written to the same location as the source compressed file.

    -h
        show help message

    -c
        User specified location for writing .cac files

    -e
        User specified location containing the slocum binary executables

    -o
        Specify an alternate location for decompressed files.

";

# Process options
while getopts "he:o:c" option
do
    case "$option" in
        "h")
            echo -e "$USAGE";
            exit 0;
            ;;
        "e")
            EXE_DIR=$OPTARG;
            ;;
        "o")
            output_path=$OPTARG;
            ;;
        "c")
            clobber=1;
            ;;
        "?")
            echo -e "$USAGE" >&2;
            exit 1;
            ;;
    esac
done

# Remove option from $@
shift $((OPTIND-1));

. logging.sh;
[ "$?" -ne 0 ] && exit 1;

if [ "$#" -eq 0 ]
then
    error_msg "No files specified";
    echo "$USAGE";
    exit 1;
fi

if [ -n "$output_path" ]
then
    if [ ! -d "$output_path" ]
    then
        error_msg "Invalid output path specified (-o): $output_path";
        exit 1;
    fi
fi

# Location of slocum executable files
if [ -z "$EXE_DIR" ]
then
    info_msg 'No slocum executables location specified. Checking for existence of $SLOCUM_EXE_ROOT environment variable';
    if [ -z "$SLOCUM_EXE_ROOT" ]
    then
        EXE_DIR=$(realpath $(pwd));
        warn_msg '$SLOCUM_EXE_ROOT not set.'
        info_msg "Setting to current working directory: $work_path";
    else
        EXE_DIR=$SLOCUM_EXE_ROOT;
    fi
fi

if [ ! -d "$EXE_DIR" ]
then
    error_msg "Invalid .exe location specified: $EXE_DIR" >&2;
    invalid=1;
fi

info_msg ".exe location: $EXE_DIR";
compexp_exe="${EXE_DIR}/compexp";
if [ ! -f "$compexp_exe" ]
then
    error_msg "TWRC compexp not found: $compexp_exe";
    exit 1;
fi
if [ ! -x "$compexp_exe" ]
then
    error_msg "TWRC compexp not executable: $compexp_exe";
    exit 1;
fi

cf_count=0;
dc_count=0;
for cf in "$@"
do

    cf_count=$(( cf_count+1 ));

    ext=${cf: -3};
#    info_msg "extension: $ext";

    # Must have a valid dinkum compressed data extension
    if [ "$ext" != 'dcd' \
        -a "$ext" != 'ecd' \
        -a "$ext" != 'mcd' \
        -a "$ext" != 'ncd' \
        -a "$ext" != 'scd' \
        -a "$ext" != 'tcd' \
        -a "$ext" != 'ncg' \
        -a "$ext" != 'mcg' ]
    then
        warn_msg "File does not appear to be compressed: $cf";
        continue;
    fi

    info_msg "Compressed file  : $cf";

    # Replace 'c' with 'b' in the extension
    if [ "$ext" == 'mcg' -o "$ext" == 'ncg' ]
    then
        new_ext=$(echo $ext | tr c l);
    else
        new_ext=$(echo $ext | tr c b);
    fi

    # Path to the compressed file
    cf_dir=$(dirname $cf);
    # If output_path not specified via -o, use $cf_dir as the path for the decompressed file
    [ -z "$output_path" ] && output_path=$cf_dir;

    # Create the fully qualified path to the decompressed file
    df=$(realpath "${output_path}/$(basename $cf $ext)$new_ext");
#    echo "decompressed: $df";

    # check if decompressed file already exists
    if [ -f "$df" -a -z "$clobber" ]
    then
        warn_msg "Skipping existing decompressed file: $df (use -c to clobber)";
        continue;
    fi

    # Decompress the file
    $compexp_exe x $cf $df;
    if [ "$?" -ne 0 ]
    then
        error_msg "Failed to decompress file: $cf";
        continue;
    fi

    dc_count=$(( count+1 ));
    info_msg "Decompressed file: $df";         

done

info_msg "${dc_count}/${cf_count} file successfully decompressed";

