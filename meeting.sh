#!/bin/bash

### better welcome message

echo "----------------------------------------------------"
echo "Please enter a title for this session."
echo "This will be used for the output filename."
echo "The current date (YYYY-MM-DD) will be automatically added as a prefix."
echo ""

# Create the full default title string.
default_title="$(date +'%Y-%m-%d_%H-%M')_meeting" # Removed .txt to make suffixing easier

# Prompt the user, showing the default title.
read -p "Enter a title [default: ${default_title}.txt]: " user_title

# Decide which title to use.
if [ -z "$user_title" ]; then
    # The user did not enter anything, so use the default title.
    final_title_base="$default_title"
else
    # The user entered a custom title, so we build a new one.
    # Get the current date for the prefix.
    current_date=$(date +'%Y-%m-%d')
    # Sanitize the user's input by replacing spaces with underscores.
    sanitized_title=${user_title// /_}
    # Combine the date and the sanitized title.
    final_title_base="${current_date}_${sanitized_title}"
fi

# Print a confirmation message for the final title.
echo ""
echo "Final filename will be based on: ${final_title_base}.txt"
echo "----------------------------------------------------"
echo "Choose your audio device(s):"

# Execute the system_profiler command with the advanced perl script
# to list only input devices with their proper names.
system_profiler SPAudioDataType | perl -lne '
    # This subroutine processes the data we have collected for the *previous* block.
    sub process_and_print {
        # Only print if we determined it was an input device.
        if ($is_input) {
            # Decide on the name. Use the specific source unless it is "Default".
            my $name_to_print = ($input_source ne "Default" ? $input_source : $device_name);
            printf "  %d: %s\n", $index++, $name_to_print;
        }
    }

    # FIX: Use a precise regex for a device header line.
    # It must start with exactly 8 spaces, then a non-space character, and end with a colon.
    if (/^\s{8}(\S.*):\s*$/) {
        # A new device header was found. First, process the one we just finished collecting.
        process_and_print();

        # Now, reset the state for the new device.
        $device_name = $1;
        $is_input = 0;
        $input_source = "Default"; # Assume "Default" until told otherwise
    }
    # Check for properties of the current device.
    elsif (/^\s+Input Channels:/) {
        $is_input = 1;
    }
    elsif (/^\s+Input Source:\s*(.*)/) {
        $input_source = $1;
    }

    # This special block runs once after the entire file has been read.
    END {
        # Process the very last device that was in the file.
        process_and_print();
    }
'

echo "----------------------------------------------------"

### Updated prompt to ask for multiple, comma-separated IDs.
read -p "Please enter desired input device ID(s) [default: 0]: " user_choices

# Set the final device IDs.
device_ids=${user_choices:-0}

# Print a confirmation message with the selected IDs.
echo ""
echo "You have selected device(s): ${device_ids}"

echo "----------------------------------------------------"
echo "Please select a language for transcription:"
echo "  0: English (en)"
echo "  1: German (de)"
echo ""

# Prompt the user for the language choice.
read -p "Enter your choice [default: 0 for English]: " user_lang_choice

# Set the default choice to 0 if the user just presses Enter.
user_lang_choice=${user_lang_choice:-0}

# Determine the language code based on the user's numeric input.
if [ "${user_lang_choice}" == "1" ]; then
    language_code="de"
else
    # Any other input (including 0 or invalid entries) defaults to English.
    language_code="en"
fi

# Print a confirmation message for the language.
echo ""
echo "You have selected language: ${language_code}"
echo "----------------------------------------------------"
echo "Starting transcription for channels: ${device_ids}"
echo "[Ctrl + C to stop all transcriptions]"

### Setup for concurrent processes and graceful shutdown.
# Array to store the process IDs (PIDs) of background jobs.
pids=()

# This function will be called when Ctrl+C (SIGINT) is pressed.
cleanup() {
    echo ""
    echo "Caught Ctrl+C. Stopping all transcription processes..."
    # Loop through all the stored PIDs and kill them.
    for pid in "${pids[@]}"; do
        # Use kill -TERM for a graceful termination signal.
        kill -TERM "$pid" 2>/dev/null
    done
    echo "All processes stopped."
}

# 'trap' sets up a command to run when a signal is received.
# Here, we tell it to run our 'cleanup' function on SIGINT.
trap cleanup SIGINT

### Loop through the comma-separated device IDs.
# This changes the Internal Field Separator to a comma for this command only,
# then reads the device_ids string into an array called CHANNELS.
IFS=',' read -ra CHANNELS <<< "$device_ids"

# Loop over the array of channel IDs.
for channel_id in "${CHANNELS[@]}"; do
    # Trim whitespace from the channel ID, just in case (e.g., "1, 2").
    channel_id=$(echo "$channel_id" | xargs)
    echo "  -> Starting whisper-stream for channel ${channel_id}..."

    # Define a unique output file for each channel.
    raw_output_file="./meetings/raw/raw_${final_title_base}_c${channel_id}.txt"

    # Start whisper-stream in the background (&) using the current channel ID.
    # We redirect stdout and stderr to prevent cluttering the terminal.
    ./build/bin/whisper-stream -m ./models/ggml-base.bin -t 8 -l ${language_code} -c "${channel_id}" -ts --step 500 --length 5000 -f "${raw_output_file}" > /dev/null 2>&1 &

    # Store the PID of the last backgrounded process ($!) in our array.
    pids+=("$!")
done

### Wait for all background PIDs to complete.
# The script will pause here. It will only continue if all jobs finish
# or if the 'trap' kills them, which satisfies the 'wait'.
wait

### Reset the trap to its default behavior.
trap - SIGINT

echo "----------------------------------------------------"
final_output_file="./meetings/${final_title_base}.txt"

### Use a wildcard to concatenate all raw channel files.
# This will find raw_*_c0.txt, raw_*_c1.txt, etc., in order.
# Merge and clean transcription files into one

python3 merge_transcripts.py ./meetings/raw/raw_${final_title_base}_c*.txt -o ./meetings/raw/raw_${final_title_base}.txt

echo "Processing output with LLM..."

# Run llm to refactor notes into final form
cat prompt_german.txt "./meetings/raw/raw_${final_title_base}.txt" | llm -m github_copilot/gpt-4.1 > "${final_output_file}"

# Show final output to the user
echo "----------------------------------------------------"
echo "Processed file saved to: ${final_output_file}:"
echo ""
echo ""
cat "${final_output_file}"
echo ""