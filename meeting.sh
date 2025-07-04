#!/bin/bash

### better welcome message

echo "----------------------------------------------------"
echo "Please enter a title for this session."
echo "This will be used for the output filename."
echo "The current date (YYYY-MM-DD) will be automatically added as a prefix."
echo ""

# Create the full default title string.
default_title="$(date +'%Y-%m-%d_%H-%M')_meeting.txt"

# Prompt the user, showing the default title.
read -p "Enter a title [default: ${default_title}]: " user_title

# Decide which title to use.
if [ -z "$user_title" ]; then
    # The user did not enter anything, so use the default title.
    final_title="$default_title"
else
    # The user entered a custom title, so we build a new one.
    # Get the current date for the prefix.
    current_date=$(date +'%Y-%m-%d')
    # Sanitize the user's input by replacing spaces with underscores.
    sanitized_title=${user_title// /_}
    # Combine the date and the sanitized title.
    final_title="${current_date}_${sanitized_title}.txt"
fi

# Print a confirmation message for the final title.
echo ""
echo "Final filename set to: ${final_title}"
echo "----------------------------------------------------"
echo "Choose your audio device:"

# Execute the system_profiler command to list all audio devices.
# The output is sent directly to the terminal for the user to see.
system_profiler SPAudioDataType | grep "Input Source" | awk -F': ' '{print "  " NR-1 ": " $2}'

echo "----------------------------------------------------"

# Prompt the user for input.
#    -p "prompt text" displays the prompt without a trailing newline.
#    The user's input will be stored in the 'user_choice' variable.
read -p "Please enter the desired input device ID [default: 0]: " user_choice

# Set the final device ID.
device_id=${user_choice:-0}

# Print a confirmation message with the selected ID.
echo ""
echo "You have selected device: ${device_id}"

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
echo "Starting transcription... [Ctrl + C to stop]"

# Starting whisper-stream transcription using the paramters from above
./build/bin/whisper-stream -m ./models/ggml-base.bin -t 8 -l ${language_code} -c ${device_id} --step 500 --length 5000 -f "./meetings/raw/raw_${final_title}" > /dev/null 2>&1

echo "Transcription stopped."
echo "----------------------------------------------------"
echo "Processing output with LLM..."

# Trigger llm call with (cat prompt + cat raw file) and > save output in final_title
cat prompt_german.txt "./meetings/raw/raw_${final_title}" | llm -m github_copilot/gpt-4.1 > "./meetings/${final_title}"

# Show final output to the user
echo "----------------------------------------------------"
echo "Processed file saved to: ${final_title}:"
echo ""
echo ""
cat "./meetings/${final_title}"
echo ""
