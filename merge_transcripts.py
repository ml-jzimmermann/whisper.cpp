import argparse
import re
import sys

def merge_files(input_files, output_file):
    """
    Merges multiple timestamped log files into a single, chronologically sorted file.

    Each line in the input files is expected to be in the format:
    '[<milliseconds>] <text_content>'
    """
    all_lines = []
    
    # Regex to capture the timestamp and the content
    line_regex = re.compile(r'^\[(\d+)\]\s*(.*)')

    for filepath in input_files:
        try:
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    match = line_regex.match(line)
                    if match:
                        # Timestamp is the first group, text is the second
                        timestamp = int(match.group(1))
                        text = match.group(2)
                        all_lines.append((timestamp, text))
                    else:
                        print(f"Warning: Skipping malformed line in {filepath}: {line.strip()}", file=sys.stderr)
        except FileNotFoundError:
            print(f"Error: Input file not found: {filepath}", file=sys.stderr)
            return
        except Exception as e:
            print(f"Error reading {filepath}: {e}", file=sys.stderr)
            return

    # Sort all lines from all files based on the integer timestamp
    all_lines.sort(key=lambda x: x[0])
    
    # Write the sorted text content to the output file
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            for _, text in all_lines:
                f.write(text + '\n')
        print(f"Successfully merged {len(input_files)} file(s) into {output_file}")
    except Exception as e:
        print(f"Error writing to output file {output_file}: {e}", file=sys.stderr)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Merge and sort timestamped transcription files."
    )
    parser.add_argument(
        'input_files', 
        nargs='+', 
        help="One or more input files to merge."
    )
    parser.add_argument(
        '-o', '--output', 
        required=True, 
        help="Path to the final merged output file."
    )
    
    args = parser.parse_args()
    
    merge_files(args.input_files, args.output)
