#!/usr/bin/env sh

#
# Copyright (C) 2019 by George Cave - gcave@stablecoder.ca
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

# Colours
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NO_COLOUR='\033[0m'

# Prints out usage/help information to the shell
usage() {
    echo "Usage: unused_dependencies.sh [OPTION]"
    echo
    echo "Using compiler-generated dependency files (.d), search through target"
    echo "directories and list desired file types that aren't used."
    echo "Such files can be generated via GCC/clang with the '-MD' option."
    echo
    echo " -e, --export    Exports the results to two files:"
    echo "                   1) Used dependencies to used.txt"
    echo "                   2) Unused dependencies to unused.txt"
    echo " -f, --filter    Adds the given regex to filter desired files"
    echo " -s, --source    DirectorSource directory that is searched for .d files"
    echo " -t, --target    A target directory of where desired headers being checked for"
    echo " -v, --verbose   Outputs more detailed information"
    echo " -h, --help      Displays this help blurb"
    echo
    echo "Multiple of each option can be applied to use more filters or directories."
    echo
    echo "Example: To only check h/hpp files, in the directory /usr/include, with"
    echo "         dependency data from /home/build"
    echo
    echo " unused_dependencies.sh -f \"\.h$\" -f \"\.hpp$\" -s /home/build -t /usr/include"
    exit 0
}

# Recusrively goes back through the directory path to find the given file
# $1 : The directory to start recurring down from
# $2 : The file/path to try to find
find_file() {
    CUR_DIR=$1
    FILE_PATH=$2

    while true; do
        # Check for the file
        if [ -f $CUR_DIR/$FILE_PATH ]; then
            printf "$CUR_DIR/$FILE_PATH"
            exit 0
        fi

        # Check if root, end of search
        if [ "$CUR_DIR" == "/" ]; then
            printf "${RED}ERROR${NO_COLOUR}: Could not find path of dependency file $FILE_PATH from $1\n"
            exit 1
        fi

        CUR_DIR=$(realpath $CUR_DIR/..)
    done
}

# Variables
FILE_EXPORT=0
FILTER_GREP=
VERBOSE=0

# Command Line Options
while [[ $# -gt 0 ]]; do
    KEY="$1"

    case $KEY in
    -e | --export)
        FILE_EXPORT=1
        shift
        ;;
    -f | --filter)
        FILTER_GREP="$FILTER_GREP -e $2"
        shift
        shift
        ;;
    -s | --source)
        DEPENDENCY_PATHS="$(realpath $2)"
        shift
        shift
        ;;
    -t | --target)
        TARGET_PATHS="$TARGET_PATHS $(realpath $2)"
        shift
        shift
        ;;
    -v | --verbose)
        VERBOSE=1
        shift
        ;;
    * | -h | --help)
        usage
        ;;
    esac
done

# Check inputs
if [ "$DEPENDENCY_PATHS" = "" ]; then
    printf " ${RED}>>$NO_COLOUR Error: No source directories for .d files defined!\n"
    exit 0
elif [ "$TARGET_PATHS" = "" ]; then
    printf " ${RED}>>$NO_COLOUR Error: No target filter paths defined!\n"
    exit 0
elif [ "$FILTER_GREP" = "" ]; then
    printf " $RED>>$NO_COLOUR Error: No grep filters defined!\n"
    exit 0
fi

# Convert target paths for grep usage
for ITEM in $TARGET_PATHS; do
    TARGET_PATHS_GREP="$TARGET_PATHS_GREP -e $ITEM"
done

# Determine the set of 'used' headers, using each file found which ends with '.d'
USED_HEADERS=
for DEP_DIR in $DEPENDENCY_PATHS; do
    # For each directory we're checking for dependency files

    for FILE in $(find -- "$DEP_DIR" | grep -e "\.d$"); do
        if [[ $VERBOSE -eq 1 ]]; then
            printf "${GREEN}Processing$NO_COLOUR: $(realpath $FILE)\n"
        fi

        # For each dependency, other than the first line itself, get that file's absolute path
        for ITEM in $(tail -n +2 $FILE); do
            # Skip plain '\' items
            if [ "$ITEM" == '\' ]; then
                continue
            fi

            if [ -f $ITEM ]; then
                # Found it, use it
                ABS_PATH=$(realpath $ITEM)
            else
                # Can't find the file, recursively search down to root to try to find it
                ABS_PATH=$(realpath $(find_file $(dirname $FILE) $ITEM))
                if [[ $? -ne 0 ]]; then
                    printf "$ABS_PATH\n"
                    exit 1
                fi
            fi

            # Filter out paths not wanted
            if ! grep $TARGET_PATHS_GREP <<<$ABS_PATH &>/dev/null; then
                continue
            fi

            # Filter out undesired file types
            if ! grep $FILTER_GREP <<<$(basename -- $ABS_PATH) &>/dev/null; then
                continue
            fi

            # If it's not in the USED_HEADERS list, add it
            USED_HEADERS="$ABS_PATH $USED_HEADERS"
        done
    done
done

# Remove duplicates
USED_HEADERS=$(awk 'BEGIN{RS=ORS=" "}!a[$0]++' <<<$USED_HEADERS)

# If Verbose, print out the used dependencies
if [[ $VERBOSE -eq 1 ]]; then
    printf "${YELLOW}Found dependencies$NO_COLOUR:\n"
    for ITEM in $USED_HEADERS; do
        echo $ITEM
    done
fi

# If export, do so now
if [[ $FILE_EXPORT -eq 1 ]]; then
    printf "" >used.txt
    for FILE in $USED_HEADERS; do
        printf "$FILE\n" >>used.txt
    done
fi

# Now, using the set of 'used' headers, go through all the headers in the same root search path and
# determine the set that exist but aren't used.
if [[ $VERBOSE -eq 1 ]]; then
    printf "${YELLOW}Unused files$NO_COLOUR:\n"
fi
if [[ $FILE_EXPORT -eq 1 ]]; then
    printf "" >unused.txt
fi
for TARGET_DIR in $TARGET_PATHS; do
    for FILE in $(find $TARGET_DIR); do
        ABS_PATH=$(realpath $FILE)

        # Filter out undesired file types
        if ! grep $FILTER_GREP <<<$(basename -- $ABS_PATH) &>/dev/null; then
            continue
        fi

        # If we can't find this file in the variable, then it isn't used
        if ! grep -w -- $ABS_PATH <<<$USED_HEADERS &>/dev/null; then
            printf "$FILE\n"
            if [[ $FILE_EXPORT -eq 1 ]]; then
                printf "$FILE\n" >>unused.txt
            fi
        fi
    done
done
