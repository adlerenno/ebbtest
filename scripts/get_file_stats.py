import csv
import sys


def file_stats(output_file, input_file_list):

    with open(output_file, 'w') as out:
        writer = csv.writer(out, delimiter="\t")
        writer.writerow(['dataset', 'sequence_count', 'max_sequence_length', 'symbol_count', 'A', 'C', 'G', 'T'])
        for file in input_file_list:
            sequence_count = 0
            count_a = 0
            count_c = 0
            count_g = 0
            count_t = 0
            max_sequence_length = 0
            with open(file, 'r') as f:
                print(f"Analysing file {file}")
                for line in f:
                    if line.startswith('>'):
                        sequence_count += 1
                        continue
                    else:
                        max_sequence_length = max(max_sequence_length, len(line) - 1)
                        for char in line:
                            if char == 'A':
                                count_a += 1
                            elif char == 'C':
                                count_c += 1
                            elif char == 'G':
                                count_g += 1
                            elif char == 'T':
                                count_t += 1
                writer.writerow([file, sequence_count, max_sequence_length, count_a + count_c + count_g + count_t, count_a, count_c, count_g, count_t])


if __name__ == '__main__':
    file_stats(sys.argv[1], sys.argv[2:])
