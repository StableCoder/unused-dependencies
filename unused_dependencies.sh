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
CYAN='\033[0;36m'
NO_COLOUR='\033[0m'

# Determine the absolute path of a file
absolute_path() {
    pushd $(dirname -- $1) &>/dev/null
    echo $(pwd)/$(basename -- $1)
    popd &>/dev/null
}

usage() {
    echo "Usage: unused_dependencies.sh [OPTION]"
    echo
    echo "Using compiler-generated dependency files (.d), search through target"
    echo "directories and list desired file types that aren't used."
    echo "Such files can be generated via GCC/clang with the '-MD' option."
    echo
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

# Variables
VERBOSE=0
FILTER_GREP=

# Command Line Options
while [[ $# -gt 0 ]]; do
    KEY="$1"

    case $KEY in
    -f | --filter)
        FILTER_GREP="$FILTER_GREP -e $2"
        shift
        shift
        ;;
    -s | --source)
        DEPENDENCY_PATHS="$2"
        shift
        shift
        ;;
    -t | --target)
        TARGET_PATHS="$TARGET_PATHS $2"
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
            printf "${GREEN}Processing$NO_COLOUR: $(absolute_path $FILE)\n"
        fi

        # For each dependency, other than the first line itself, get that file's absolute path
        for ITEM in $(tail -n +2 $FILE); do
            # Skip plain '\' items
            if [ "$ITEM" == '\' ]; then
                continue
            fi

            ABS_PATH=$(absolute_path $ITEM)

            # Filter out paths not wanted
            if ! grep $TARGET_PATHS_GREP <<<$ABS_PATH &>/dev/null; then
                continue
            fi

            # Filter out undesired file types
            if ! grep $FILTER_GREP <<<$(basename -- $ABS_PATH) &>/dev/null; then
                continue
            fi

            # If it's not in the USED_HEADERS list, add it
            if ! grep -w -- $ABS_PATH <<<$USED_HEADERS &>/dev/null; then
                if [[ $VERBOSE -eq 1 ]]; then
                    printf "  ${CYAN}Added$NO_COLOUR: $ABS_PATH\n"
                fi
                USED_HEADERS="$USED_HEADERS $ABS_PATH"
            fi
        done
    done
done

# Now, using the set of 'used' headers, go through all the headers in the same root search path and
# determine the set that exist but aren't used.
if [[ $VERBOSE -eq 1 ]]; then
    printf "${YELLOW}Unused files$NO_COLOUR:\n"
fi
for TARGET_DIR in $TARGET_PATHS; do
    for FILE in $(find $TARGET_DIR); do
        ABS_PATH=$(absolute_path $FILE)

        # Filter out undesired file types
        if ! grep $FILTER_GREP <<< $(basename -- $ABS_PATH) &>/dev/null; then
            continue
        fi

        if ! grep -w -- $ABS_PATH <<<$USED_HEADERS &>/dev/null; then
            printf "$FILE\n"
        fi
    done
done
