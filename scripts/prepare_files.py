import os
import subprocess
import sys
import time

dryrun = False


def system(cmd: str):
    """Returns time in nanoseconds (Remove _ns from time to return seconds)"""
    if cmd == '':
        raise ValueError('Command is only an empty string, please check that...')
    print(cmd)
    cmd_list = cmd.split(' ')
    t = 0
    if not dryrun:
        t = time.time_ns()  # process_time()
        proc = subprocess.run(cmd_list, stdout=subprocess.PIPE)
        t = (time.time_ns() - t)
        # if proc != 0:
        #    print("Command returned %d" % res)
    return t


def prepare_files(file: str, multiline: bool, output_basename: str):
    """Multiline=True means, that there is only a single line per read.
    Use multiline=False if a read is divided into multiple lines."""
    # check for .gz file
    if file.endswith('.gz'):
        if os.path.isfile(file) and not os.path.isfile(file[:-3]):
            system(f'gzip -dk {file}')  # use -dk to decompress and keep the old file
        file = file[:-3]
        if not os.path.isfile(file):
            raise FileNotFoundError(f"Input file does not exist: {file}")

    is_fasta = file.split('.')[-1] in {'fa', 'fasta'}
    # check for fasta and create one word per line file
    line_number = 0
    written_reads = 0
    if not os.path.isfile(output_basename + '.owpl'):
        print(f'Preparing file: {file}')
        with open(file) as input_file:
            with open(output_basename + '.owpl', 'w') as output_owpl:  # owpl = one word per line
                with open(output_basename + '.fa', 'w') as output_fasta:
                    with open(output_basename + '.fq', 'w') as output_fastq:
                        if not multiline:
                            output_fasta.write('>\n')
                        for line in input_file:
                            line = line.upper()
                            if (multiline and is_fasta and line_number % 2 == 1) \
                                    or (multiline and not is_fasta and line_number % 4 == 1):
                                assert line[0] not in {'>', '+', '@', ':', ';', 9, 8}
                                line = ''.join(filter(lambda x: x in {'A', 'C', 'G', 'T'}, line))

                                output_owpl.write(line + '\n')

                                output_fasta.write(f'>S{line_number}\n')
                                output_fasta.write(line + '\n')

                                output_fastq.write(f'@S{line_number} length={len(line)}\n')
                                output_fastq.write(line + '\n')
                                output_fastq.write(f'+ length={len(line)}\n')
                                output_fastq.write(':' * len(line) + '\n')
                            if not multiline:
                                assert line[0] not in {'+', '@', ':', ';', 9, 8}
                                if line[0] == '>':
                                    output_fasta.write('>\n')
                                    output_owpl.write('\n')
                                else:
                                    line = ''.join(filter(lambda x: x in {'A', 'C', 'G', 'T'}, line))

                                    output_owpl.write(line)

                                    output_fasta.write(line + '\n')

                                    # HINT: I do not support writing multiline fastq yet. Add id here otherwise.
                                    # output_fastq.write(f'@ length={len(line)}\n')
                                    # output_fastq.write(line + '\n')
                                    # output_fastq.write(f'+ length={len(line)}\n')
                                    # output_fastq.write(':' * len(line) + '\n')
                            line_number += 1
                        if multiline:
                            output_fasta.write('\n')
                        output_owpl.flush()
                        output_fasta.flush()
                        output_fastq.flush()

    # create fasta.gz and fastq.gz files
    if not os.path.isfile(f'{output_basename}.fa.gz'):
        system(f'gzip -k {output_basename}.fa')
    if not os.path.isfile(f'{output_basename}.fq.gz'):
        system(f'gzip -k {output_basename}.fq')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input_file> <output_file>")
    else:
        if '.fasta' in sys.argv[2]:
            sys.argv[2] = sys.argv[2].replace('.fasta', '')
        if '.fastq' in sys.argv[2]:
            sys.argv[2] = sys.argv[2].replace('.fastq', '')
        if '.fq' in sys.argv[2]:
            sys.argv[2] = sys.argv[2].replace('.fq', '')
        if '.fa' in sys.argv[2]:
            sys.argv[2] = sys.argv[2].replace('.fa', '')
        if '.gz' in sys.argv[2]:
            sys.argv[2] = sys.argv[2].replace('.gz', '')
        prepare_files(sys.argv[1], True, sys.argv[2])
