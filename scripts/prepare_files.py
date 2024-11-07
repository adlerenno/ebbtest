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


def prepare_files(file: str, output_basename: str):
    """Multiline=True means that there is only a single line per read.
    Use multiline=False if a read is divided into multiple lines."""
    # check for .gz file
    if file.endswith('.gz'):
        if os.path.isfile(file) and not os.path.isfile(file[:-3]):
            system(f'gzip -dk {file}')  # use -dk to decompress and keep the old file
        file = file[:-3]
        if not os.path.isfile(file):
            raise FileNotFoundError(f"Input file does not exist: {file}")

    # check for fasta and create one word per line file
    status = 0
    sequence_number = 0
    line_lengths = []
    if not os.path.isfile(output_basename + '.owpl'):
        print(f'Preparing file: {file}')
        with open(file) as input_file:
            with open(output_basename + '.owpl', 'w') as output_owpl:  # owpl = one word per line
                with open(output_basename + '.fa', 'w') as output_fasta:
                    with open(output_basename + '.fq', 'w') as output_fastq:
                        for line in input_file:
                            if line.startswith('>'):
                                output_fasta.write(line)
                                if status != 0:
                                    output_fastq.write(f'+ length={len(line)}\n')
                                    for length in line_lengths:
                                        output_fastq.write(':' * length + '\n')
                                    line_lengths.clear()
                                output_fastq.write(f'@{line[1:]}')
                                sequence_number += 1
                                status = 1
                            elif line.startswith(':'):
                                status = 2
                            elif status == 1:
                                line = ''.join(filter(lambda x: x in {'A', 'C', 'G', 'T'}, line.upper()))
                                assert len(line) > 0

                                output_owpl.write(line + '\n')

                                output_fasta.write(line + '\n')

                                output_fastq.write(line + '\n')
                                line_lengths.append(len(line))

                        if len(line_lengths) > 0:
                            output_fastq.write(f'+ length={len(line)}\n')
                            for length in line_lengths:
                                output_fastq.write(':' * length + '\n')
                            line_lengths.clear()
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
