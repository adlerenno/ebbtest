import sys


def convert(input, output):
    count_smaller_symbols = 0
    symbols = 0
    with open(input, 'r') as f:
        with open(output, 'w') as out:
            for line in f:
                if line.startswith('>'):
                    if count_smaller_symbols == 0:
                        out.write(line)
                    count_smaller_symbols += 1
                    continue
                #if count_smaller_symbols > 50:
                #    break
                line = ''.join(filter(lambda x: x in {'A', 'C', 'G', 'T'}, line.upper()))
                symbols += len(line)
                if len(line) > 0:
                    out.write(line + '\n')
    print(f'Output file has {symbols} ACGT characters.')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input_file> <output_file>")
    else:
        convert(sys.argv[1], sys.argv[2])
