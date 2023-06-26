# Logging functions to print debug: info: warninng: error messages to STDOUT/STDERR
# Source this script to import

# Create datestamped log file name
function get_log_file() {
    if [ "$#" -eq 1 ]
    then
        echo "$(date --utc +%Y%m%d)-${1}.log";
    fi
}

# Error message function. Prints to STDERR
function error_msg() {
    if [ -z "$1" ]
    then
        msg='Unknown ERROR message';
    else
        msg=$1;
    fi
    echo "$(date --utc +%Y-%m-%dT%H:%M:%SZ):$app:ERROR:$msg [Line $BASH_LINENO]" >&2;
}
# Warning message function. Prints to STDERR
function warn_msg() {
    if [ -z "$1" ]
    then
        msg='Unknown WARNING message';
    else
        msg=$1;
    fi
#    echo "$(date --utc +%Y-%m-%dT%H:%M:%SZ):$app:[Line $BASH_LINENO]:WARN:$msg" >&2;
    echo "$(date --utc +%Y-%m-%dT%H:%M:%SZ):$app:WARN:$msg [Line $BASH_LINENO]" >&2;
}
# Message function. Prints to STDOUT
function info_msg() {
    if [ -z "$1" ]
    then
        msg='Unknown INFO message';
    else
        msg=$1;
    fi
#    echo "$(date --utc +%Y-%m-%dT%H:%M:%SZ):$app:[Line $BASH_LINENO]:INFO:$msg" >&2;
    echo "$(date --utc +%Y-%m-%dT%H:%M:%SZ):$app:INFO:$msg [Line $BASH_LINENO]" >&2;
}
# Message function. Prints to STDOUT
function debug_msg() {
    if [ -z "$1" ]
    then
        msg='Unknown DEBUG message';
    else
        msg=$1;
    fi
#    echo "$(date --utc +%Y-%m-%dT%H:%M:%SZ):$app:[Line $BASH_LINENO]:DEBUG:$msg" >&2;
    echo "$(date --utc +%Y-%m-%dT%H:%M:%SZ):$app:DEBUG:$msg [Line $BASH_LINENO]" >&2;
}
