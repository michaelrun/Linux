#!/bin/bash

# Define Prefixes and Settings
DIR_PREFIX_TO_REMOVE="rocksdb_perf_"
FILE_PREFIX_TO_REMOVE="metrics_hex_readrandom_"
OUTPUT_DIR="/tmp/profilings" # All renamed files will be placed here.

# Function to process a single directory and copy/rename its files
process_directory() {
    local BASE_DIR="$1"
    local SOURCE_DIR="${BASE_DIR}/metrics/"

    # 1. Extract the base part of the directory name by removing the prefix.
    # Bash parameter expansion: ${variable#pattern} removes the shortest match from the front.
    local DIR_PART=${BASE_DIR#$DIR_PREFIX_TO_REMOVE}

    echo "--- Processing Directory: $BASE_DIR ---"

    # Check if the required 'metrics/' subdirectory exists
    if [ ! -d "$SOURCE_DIR" ]; then
        echo "Warning: Metrics directory '$SOURCE_DIR' does not exist. Skipping this base directory."
        return 0
    fi

    # Loop through all files in the SOURCE_DIR
    for original_file_path in "$SOURCE_DIR"*; do
        # Check if the path is a regular file
        if [ -f "$original_file_path" ]; then

            # Extract just the filename
            local BASE_FILENAME=$(basename "$original_file_path")

            # 2. Extract the base part of the filename by removing the prefix.
            if [[ "$BASE_FILENAME" == "$FILE_PREFIX_TO_REMOVE"* ]]; then
                # Remove the file prefix
                local FILE_PART=${BASE_FILENAME#$FILE_PREFIX_TO_REMOVE}

                # 3. Construct the new filename: [Dir Part]_[File Part]
                # The files are copied to the dedicated output directory.
                local NEW_FILENAME="${OUTPUT_DIR}/${DIR_PART}_${FILE_PART}"

                echo "  Processing: $BASE_FILENAME"
                echo "    -> To: $NEW_FILENAME"

                # Perform the copy operation
                cp "$original_file_path" "$NEW_FILENAME"
                echo "  [SUCCESS]"

            else
                echo "  Skipping: $BASE_FILENAME (Does not start with '$FILE_PREFIX_TO_REMOVE')"
            fi
        fi
    done
    echo "--- Finished processing $BASE_DIR ---"
}

# --- Main Execution ---

echo "Starting batch file copy and rename process..."

# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"
echo "All renamed files will be saved in the dedicated '$OUTPUT_DIR/' directory."
echo "------------------------------------------------------------------"

# Loop through all items in the current directory that start with the prefix.
MATCHING_DIRS=0
for BASE_DIR in "${DIR_PREFIX_TO_REMOVE}"*; do
    # Check if the item is an actual directory
    if [ -d "$BASE_DIR" ]; then
        process_directory "$BASE_DIR"
        MATCHING_DIRS=$((MATCHING_DIRS + 1))
    fi
done

echo "------------------------------------------------------------------"

if [ "$MATCHING_DIRS" -eq 0 ]; then
    echo "No directories matching '${DIR_PREFIX_TO_REMOVE}*' found in the current location. Nothing was copied."
else
    echo "Batch copy and rename process complete. Total directories processed: $MATCHING_DIRS"
fi
