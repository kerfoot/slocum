#! /bin/bash --
#
# processDbds.sh [hdrf] SOURCEDIR DESTDIR
#
# Convert and merge all binary *.[demnst]bd files in SOURCEDIR and write the 
# corresponding DBA data files to DESTDIR.  If present, the following files 
# pairs are merged:
#
#   dbd/ebd
#   mbd/nbd
#   sbd/tbd
#
# An exit status of 1 is returned if any part of the conversion or move fails.
# Otherwise, exit status of 0.
#
# ============================================================================
# $RCSfile: processDbds.sh,v $
# $Source: /home/kerfoot/cvsroot/glider/bash/processDbds.sh,v $
# $Revision: 1.6 $
# $Date: 2012/07/25 21:24:28 $
# $Author: kerfoot $
# $Name:  $
# ============================================================================
#

PATH=/bin:/usr/bin

# Permissions for cac files
cacPerms=775;

# Location of cache files - if commented out, you must specify the location
# (via the -c switch) you want the .cac files written to upon creation.  
# Otherwise, they are written to the temporary directory used to do the 
# conversions
CACHE_DIR='/home/coolgroup/gliderData/deployments-meta/cac';

# Path to the WRC executables (dbd2asc, dba2_orig_matlab, etc)
EXE_DIR='/home/coolgroup/gliderData/deployments-meta/linux-bin';

# Soure and destination default to current directory
dbdRoot=$(pwd);
ascDest=$(pwd);

app=$(basename $0);

# Usage message
USAGE="
$app

NAME 
    $app - Convert and merge Slocum glider binary files

SYNOPSIS
    $app [hdrf] SOURCEDIR DESTDIR

DESCRIPTION
    Convert and merge all binary *.[demnst]bd files in SOURCEDIR and write the
    corresponding Matlab data files to DESTDIR.  If present, the following 
    flight/science controller file pairs are merged:

     FLIGHT/SCIENCE
     --------------
        dbd/ebd
        mbd/nbd
        sbd/tbd
     --------------

    If the science file is not present, only the flight controller file is
    written.

    -h
        Print help and exit

    -f FILE
        Ignore sensors not contained in FILE, which is a whitespace separated
        file containing sensor names to include

    -r
        Assume merging and permanently delete flight controller and science 
        controller binary files that have been successfully merged.  If a 
        science counterpart file was not found, the flight controller file 
        is converted, but not deleted so that it may be merged with the
        science controller data file when it arrives.  USE WITH CAUTION!

    -c
        User specified location for writing .cac files.  Default location is:
            
            $CACHE_DIR

    -m
        Output matlab formatted ascii files instead of dba format.

";

# Process options
while getopts hrf:c:m option
do

    case "$option" in
        "h")
            # Print help message
            echo "$USAGE";
            exit 0;
            ;;
        "r")
            # Only delete files that have been merged
            echo "Running in REALTIME: non-merged binaries will be kept.";
            REALTIME=1;
            ;;
        "f") 
            sensorFilter=$OPTARG;
            ;;
        "c")
            CACHE_DIR=$OPTARG;
            ;;
        "m")
            matlab=1;
            ;;
        "?")
            exit 1;
            ;;
        *)
            echo "Unknown error while processing options";
            exit 1;
            ;;
    esac
done

# Remove options from ARGV
shift $((OPTIND-1));

EXIT_STATUS=1;

# Validate executables location
if [ ! -d "$EXE_DIR" ]
then
    echo "Invalid exe dir: $EXE_DIR" 1>&2;
    exit $EXIT_STATUS;
fi
# Make sure the required TWRC utilities are available
dbd2asc="${EXE_DIR}/dbd2asc";
if [ ! -x "$dbd2asc" ]
then
    echo "Missing utility: $dbd2asc" >&2;
    exit $EXIT_STATUS;
fi
dbaMerge="${EXE_DIR}/dba_merge";
if [ ! -x "$dbaMerge" ]
then
    echo "Missing utility: $dbdMerge" >&2;
    exit $EXIT_STATUS;
fi
dba2matlab="${EXE_DIR}/dba2_orig_matlab";
if [ ! -x "$dba2matlab" ]
then
    echo "Missing utility: $dba2matlab" >&2;
    exit $EXIT_STATUS;
fi
dba_sensor_filter="${EXE_DIR}/dba_sensor_filter";
if [ ! -x "$dba_sensor_filter" ]
then
    echo "Missing utility: $dba_sensor_filter" >&2;
    exit $EXIT_STATUS;
fi

# Validate source and destination directories
if [ ! -d "$dbdRoot" ]
then
    echo "Invalid source dir : $dbdRoot!" >&2;
    echo "Usage: $0 [-hdr] source_directory [destination_directory]" >&2
    exit $EXIT_STATUS;
fi
if [ ! -d "$ascDest" ]
then
    echo "Invalid destination: $ascDest!" >&2;
    echo "Usage: $0 [-hdr] source_directory [destination_directory]" >&2
    exit $EXIT_STATUS;
fi

# Display usage if no files are specified
if [ "$#" -eq 0 ]
then
    echo "Please specify an input directory.";
    echo "Usage: $0 [-hdr] source_directory [destination_directory]" >&2
    exit $EXIT_STATUS;
elif [ "$#" -eq 1 ]
then
    dbdRoot=$1;
    ascDest=$1;
elif [ "$#" -gt 1 ]
then
    dbdRoot=$1;
    ascDest=$2;
fi

# Validate source ($dbdRoot) and destination ($ascDest)
if [ ! -d "$dbdRoot" ]
then
    echo "Invalid source directory: $dbdRoot" >&2;
    exit $EXIT_STATUS;
fi
if [ ! -d "$ascDest" ]
then
    echo "Invalid destination directory: $ascDest" >&2;
    exit $EXIT_STATUS;
fi

# Get absolute paths for the source and destination directory
dbdRoot=$(readlink -e $dbdRoot);
ascDest=$(readlink -e $ascDest);

# Display fully qualified path
echo "Source     : $dbdRoot";
echo "Destination: $ascDest";

# If specified, validate the sensor list to filter by
if [ -n "$sensorFilter" ]
then
    if [ ! -f "$sensorFilter" ]
    then
        echo "Invalid sensor filter list: $sensorFilter!" >&2;
        exit $EXIT_STATUS;
    else
        # Get absolute path to the sensor filter file if it exists
        sensorFilter=$(readlink -e $sensorFilter);
        echo "dba filter : $sensorFilter";
    fi
fi

# Make a temporary directory for writing the intermediate dba files and
# (optionally) doing the dba->matlab conversions
tmpDir=$(mktemp -d -t ${app}.XXXXXXXXXX);
if [ "$?" -ne 0 ]
then
    echo "Exiting: Can't create temporary dbd directory" >&2;
    exit $EXIT_STATUS;
fi
echo "Changing to temporary directory: $tmpDir";
# Change to temporary directory
cd $tmpDir > /dev/null;
# Remove $tmpDir if SIG
trap "{ rm -Rf $tmpDir; exit 255; }" SIGHUP SIGINT SIGKILL SIGTERM SIGSTOP;

# If the location of the .CAC files has not been set, dbd2asc creates a
# directory, 'cache', in the curret working directory.  In this case, we'll
# create this directory in the $dbdRoot directory and explicitly set $CACHE_DIR
# to this location
if [ -z "$CACHE_DIR" -o ! -d "$CACHE_DIR" ]
then
    CACHE_DIR="${dbdRoot}/cache";
    if [ ! -d "$CACHE_DIR" ]
    then
        mkdir -m 775 $CACHE_DIR;
        [ "$?" -ne 0 ] && exit $EXIT_STATUS;
    fi
fi
echo "CAC file location: $CACHE_DIR";

# Convert each file individually and move the created files to the location of
# the source binary files
dbdCount=0;
convertedCount=0;
for dbdSource in $dbdRoot/*
do

    # Set flag to 0 before attempting to convert each file.  This flag is only
    # set to 1
    convertOk=0;

    # Files only
    [ ! -f "$dbdSource" ] && continue;

    # Strip off extension
    dbdExt=${dbdSource: -3};
#    echo "Extension: $dbdExt";

    # Get the real filename from the binary file header
    dbdSeg=$(awk '/^full_filename:/ {print tolower($2)}' $dbdSource | sed '{s/-/_/g}');
    # Get the real extension from the binary file header
    fType=$(awk '/^filename_extension:/ {print $2}' $dbdSource);

    # Determine the other file type to look for based on this dbdExtension
    if [ "$dbdExt" == 'SBD' ]
    then
        sciExt='TBD';
    elif [ "$dbdExt" == 'sbd' ]
    then
        sciExt='tbd';
    elif [ "$dbdExt" == 'MBD' ]
    then
        sciExt='NBD';
    elif [ "$dbdExt" == 'mbd' ]
    then
        sciExt='nbd';
    elif [ "$dbdExt" == 'DBD' ]
    then
        sciExt='EBD';
    elif [ "$dbdExt" == 'dbd' ]
    then
        sciExt='ebd';
    else
        # We're only look for d,s or mbd files
        continue;
    fi

    dbdCount=$(( dbdCount + 1 ));

    # Check the header of this file and look for the .cac file name:
    # sensor_list_crc:    AAD1AE87
    # We'll need to chmod this file once we've created it to keep from getting
    # annoying permission errors.
    cac=$(awk '/^sensor_list_crc:/ {print tolower($2)}' $dbdSource);

    # Strip the extension off the file to the the segment name
    segment=$(basename $dbdSource .${dbdExt});

    # Echo and suppress the trailing newline
    echo '----';

    # Append the corresponding science dat file extension to the segment name
    # to create the science data file name.
    sciSource="${dbdRoot}/${segment}.${sciExt}";

    echo "DBD Source: $dbdSource";

    # Translate all characters in $dbdExt to lowercase for naming the created
    # ascii files
    asciiExt=$(echo $dbdExt | tr [[:upper:]] [[:lower:]]);

    # Create the flight data file .dba filename
    dbdDba="${tmpDir}/${dbdSeg}_${dbdExt}.dba";

    # Create the flight data file .dat filename, which will be created
    # regardless of whether we're outputting to matlab or ascii format
    datFile="${tmpDir}/${dbdSeg}_${asciiExt}.dat";

    # If the science data file exists, merge $dbdSource and $sciSource and
    # write the output format (dba or matlab).  If it does not exist, just
    # convert $dbdSource and write to the output format (dba or matlab)
    if [ -f "$sciSource" ]
    then
        echo "SCI Source: $sciSource";
        echo "Converting & Merging flight and science data files...";

        # Create the science data file .dba filename
        sciDba="${tmpDir}/${dbdSeg}_${sciExt}.dba";

        # Convert the $dbdSource binary to ascii and write to *.dba file
        if [ -n "$sensorFilter" ]
        then
            # Filter the sensors that will go into the file
            $dbd2asc -o \
                -c $CACHE_DIR \
                $dbdSource | \
                $dba_sensor_filter -f $sensorFilter \
                > $dbdDba;
        else
            # Include all sensors
            $dbd2asc -o \
                -c $CACHE_DIR \
                $dbdSource > \
                $dbdDba;
        fi

        # Exit status == 0 if successful or 1 if failed.  If failure, $dbdDba
        # will be empty, so we need to remove it
        if [ "$?" -ne 0 ]
        then
            echo "Skipping segment: $segment";
            rm $dbdDba;
            continue;
        fi

        # Convert the $sciSource binary to ascii and write to *.dba file
        if [ -n "$sensorFilter" ]
        then
            # Filter the sensors that will go into the file
            $dbd2asc -o \
                -c $CACHE_DIR \
                $sciSource | \
                $dba_sensor_filter -f $sensorFilter \
                > $sciDba;
        else
            # Include all sensors
            $dbd2asc -o \
                -c $CACHE_DIR \
                $sciSource > \
                $sciDba;
        fi

        # Exit status == 0 if successful or 1 if failed.  If failed, $sciDba
        # will be empty, so we need to remove it.  Since the science data file
        # conversion failed, continue on but write ONLY the flight controller
        # data to the output destination
        if [ "$?" -ne 0 ]
        then
            echo "Science conversion failed: Writing flight controller data ONLY...";
            rm $sciDba;
        fi

        # Finally, write the file to the desired output format.  If $matlab is
        # set, use dba2_orig_matlab to create the .m and .dat files.  If it is
        # not set, move $dbaOut to the same filename, but with a .dat
        # extension
        if [ -n "$matlab" ]
        then
            # If successful, the output of this command is the name of the
            # file that was created
            if [ -f "$sciDba" ]
            then
                mFile="${tmpDir}/$($dbaMerge $dbdDba $sciDba | $dba2matlab)";
                # Set convertOk to 1 for realtime switch processing
                convertOk=1;
            else
                mFile=$(cat $dbdDba | $dba2matlab);
            fi

            # Skip to the next file if an error occurred
            [ ! -f "$mFile" ] && continue;

            echo "M-File Created: $mFile";

            # Increment the successful file counter if both $datFile and
            # $mFile exist
            convertedCount=$(( convertedCount + 1 ));

            # Delete the individual dba files
            rm $dbdDba;
            [ -f "$sciDba" ] && rm $sciDba;

        else
            if [ -f "$sciDba" ]
            then
                $dbaMerge $dbdDba $sciDba > $datFile;

                # Skip to the next file if an error occurred
                [ "$?" -ne 0 ] && continue;

                # Set convertOk to 1 for realtime switch processing
                convertOk=1;
            else
                cat $dbdDba > $datFile;
            fi

            echo "Output File Created: $datFile";

            # Increment the successful file counter if the move was successful
            convertedCount=$(( convertedCount + 1 ));

            # Delete the individual dba files
            rm $dbdDba $sciDba;

        fi

    else
        echo "Converting flight data file ONLY...";

        # Convert to ascii and write to *.dba file
        if [ -n "$sensorFilter" ]
        then
            # Filter the sensors that will go into the file
            $dbd2asc -o \
                -c $CACHE_DIR \
                $dbdSource | \
                $dba_sensor_filter -f $sensorFilter \
                > $dbdDba;
        else
            # Include all sensors
            $dbd2asc -o \
                -c $CACHE_DIR \
                $dbdSource > \
                $dbdDba;
        fi

        # Exit status == 0 if successful or 1 if failed
        if [ "$?" -ne 0 ]
        then
            echo "Skipping segment: $segment";
            rm $dbdDba;
            continue;
        fi

        # Finally, write the file to the desired output format.  If $matlab is
        # set, use dba2_orig_matlab to create the .m and .dat files.  If it is
        # not set, move $dbaOut to the same filename, but with a .dat
        # extension
        if [ -n "$matlab" ]
        then
            # If successful, the output of this command is the name of the
            # file that was created
            mFile="${tmpDir}/$(cat $dbdDba | $dba2matlab)";
            # Remove the dba file
            rm $dbdDba;

            # Skip to the next file if an error occurred
            [ ! -f "$mFile" ] && continue;

            echo "M-File Created: $mFile";

            convertOk=1;

            # Increment the successful file counter if both $datFile and
            # $mFile exist
            convertedCount=$(( convertedCount + 1 ));

        else
            mv $dbdDba $datFile;

            # Skip to the next file if an error occurred
            [ "$?" -ne 0 ] && continue;

            echo "Output File Created: $datFile";

            convertOk=1;

            # Increment the successful file counter if the move was successful
            convertedCount=$(( convertedCount + 1 ));
        fi

    fi

    # If successful, change the permissions on the .cac file to rwx for
    # owner and group
    cacFile="${CACHE_DIR}/${cac}.cac";
    if [ -f "$cacFile" ]
    then 
        echo "Updating $asciiExt ${cac}.cac permissions ($cacPerms)";
        oldPerms=$(stat --format=%a $cacFile);
        chmod $cacPerms $cacFile;
        newPerms=$(stat --format=%a $cacFile);
    fi

    # Search for the .cac file for the science binary to change
    # permissions on this one as well
    if [ -f "$sciSource" ]
    then
        sciCac=$(awk '/^sensor_list_crc:/ {print tolower($2)}' $sciSource);
        sciCacFile="${CACHE_DIR}/${sciCac}.cac";
        if [ -f "$sciCacFile" ]
        then 
            echo "Updating $sciExt ${sciCac}.cac permissions ($cacPerms)";
            oldPerms=$(stat --format=%a $sciCacFile);
            chmod $cacPerms $sciCacFile;
            newPerms=$(stat --format=%a $sciCacFile);
        fi
    fi

    # Source binary delete options:
    # -r (REALTIME mode): deletes the binary files only if both were present
    #   and were successfully merged.  The -d switch is ignored.  This allows
    #   for merging at a future time if/when the companion file shows up.
    if [ -n "$REALTIME" ]
    then

        [ "$convertOk" -ne 1 ] && continue;

        if [ ! -f "$sciSource" ]
        then
            echo ">> REALTIME MODE: Missing science file: $sciSource";
            echo ">> REALTIME MODE: Keeping flight file (Waiting for science file).";
        else

            echo ">> REALTIME MODE: Deleting merged flight and science binaries ONLY.";
            rm $dbdSource $sciSource;

        fi

    fi

done

# Move all remaining file in $tmpDir to $ascDest
# Default exit status
if [ "$dbdCount" -gt 0 ]
then
    echo -e "\n------------------------------------------------------------------------------";
    echo -n "Moving output files to destination: $ascDest...";
    status=$(mv ${tmpDir}/*.* $ascDest 2>&1);
    if [ "$?" -eq 0 ]
    then
        echo "Done.";
        # Set status to 0 to signal successful conversion
        STATUS=0;
    else
        echo "Failed.";
    fi
fi
# Remove $tmpDir
rm -Rf $tmpDir;

echo -e "==============================================================================\n";
echo "$convertedCount/$dbdCount files successfully converted.";
echo '=============================================================================='

exit $STATUS;
