import os
from itertools import chain

# sudo snakemake --rerun-triggers mtime --cores 1
# sudo snakemake --touch --cores 1

MAX_MAIN_MEMORY = 128
NUMBER_OF_PROCESSORS = 32

# Avoid renaming these, because they are mostly not referenced but hard coded.
DIR = "./"
SOURCE = './source/'
SPLIT = './split/'
INPUT = './data/'
TEMP = './tmp/'
OUTPUT = './data_bwt/'
INDICATORS = './indicators/'
BENCHMARK = './bench/'
RESULT = './results/'

# Adjust tested settings here. Make sure if you add something, that you add a corresponding rule to provide the file or the approach
APPROACHES_SINGLE = [
    'ropebwt3',
    'bigBWT',
    'r_pfbwt',
    'grlBWT',
    'egap',
    'gsufsort',
    'divsufsort',
]
APPROACHES_MULTI = [
    'ibb',
    'bcr',
    'ropebwt',
    'ropebwt2'
]
APPROACHES = APPROACHES_MULTI + APPROACHES_SINGLE
DATA_TYPE = {
    'bcr': 'fq.gz',
    'ropebwt': 'fq.gz',
    'ropebwt2': 'fq.gz',
    'ropebwt3': 'fq.gz',
    'bigBWT': 'fa',
    'r_pfbwt': 'fa',
    'grlBWT': 'owpl',
    'egap': 'fa',
    'gsufsort': 'fq.gz',
    'divsufsort': 'fa',
    'ibb': 'fa',
    'partdna': 'fa'
}
DATA_SETS_SPLIT = [
    'GRCh38',
    'GRCm39',
    'TAIR10',
    'ASM584',
    'R64',
    'ASM19595',
    'JAGHKL01']
DATA_SETS = [
#    'hprc_pangenome',
#    'SRR5816161',
    'SRR11092057',
    'SRR062634',
    'influenza',
    'UB118CR3',
    'HGChr14',
    'zymowastewater',
]
DATA_TYPE_OF_DATA_SETS = {
    'SRR5816161':'fa',
    'SRR11092057':'fa',
    'SRR062634':'fa',
    'influenza':'fa',
    'UB118CR3':'fa',
    'HGChr14':'fa',
    'zymowastewater':'fa',
    'hprc_pangenome':'fa',
    'GRCh38':'fa',
    'GRCm39':'fa',
    'TAIR10':'fa',
    'ASM584':'fa',
    'R64':'fa',
    'ASM19595':'fa',
    'JAGHKL01':'fa'
}
R_VALUES = list(range(3, 6))
K_VALUES = list(range(1, 20))

FILES = [f'indicators/{file}.{DATA_TYPE[approach]}.{approach}'
         for approach in APPROACHES
         for file in DATA_SETS
         ] + [f'indicators/{file}.{DATA_TYPE[approach]}.{approach}'
         for approach in APPROACHES
         for file in DATA_SETS_SPLIT
         ] + [f'indicators/{file}_split_{r}.{DATA_TYPE[approach]}.{approach}'
         for approach in APPROACHES
         for file in DATA_SETS_SPLIT
         for r in R_VALUES
         ]

# Necessary to create directories because output files of bwt construction are not named in snakemake file.
for path in [BENCHMARK, SOURCE, SPLIT, INPUT, TEMP, OUTPUT, INDICATORS, RESULT] + [OUTPUT + approach for approach in APPROACHES]:
    os.makedirs(path, exist_ok=True)

rule target:
    input:
        bench = 'results/benchmark.csv',
        stats = 'results/file_stats.csv',
        length_distribution = 'results/length_distribution_GRCh38.csv',
        k_evaluation = 'results/k_benchmark.csv'

rule get_results:
    input:
        set = FILES
    output:
        bench = 'results/benchmark.csv'
    run:
        """
        python3 scripts/collect_benchmarks.py bench {output.bench}
        """
        from scripts.collect_benchmarks import combine
        combine(DATA_SETS + DATA_SETS_SPLIT, DATA_SETS_SPLIT, R_VALUES, APPROACHES, DATA_TYPE, output.bench)

rule stats:
    input:
        set = [f'split/{filename}.{DATA_TYPE_OF_DATA_SETS[filename]}' for filename in DATA_SETS + DATA_SETS_SPLIT]
              + [f'split/{filename}.{DATA_TYPE_OF_DATA_SETS[filename]}_split_{r}' for filename in DATA_SETS_SPLIT for r in R_VALUES]
    output:
        stats = 'results/file_stats.csv'
    shell:
        """
        python3 scripts/get_file_stats.py {output.stats} {input.set}
        """

rule length_distribution:
    input:
        file = 'split/GRCh38.fa_split_4'
    output:
        length_distribution = 'results/length_distribution_GRCh38.csv'
    run:
        from scripts.get_file_stats import length_distribution
        length_distribution(output.length_distribution, input.file)


rule k_benchmark:
    input:
        set = [f'indicators/zymowastewater.fa.{k}.ibb' for k in K_VALUES]
    output:
        bench = 'results/k_benchmark.csv'
    run:
        from scripts.collect_benchmarks import combine_k
        combine_k(['zymowastewater'], K_VALUES, output.bench)

rule clean:
    shell:
        """
        rm -rf ./bench
        rm -rf ./source
        rm -rf ./split
        rm -rf ./data
        rm -rf ./data_bwt
        rm -rf ./indicators
        rm -rf ./tmp
        rm -rf ./result
        """

rule prepare_files:
    input:
        in_file = 'split/{filename}.fa_split_{r}'
    output:
        'data/{filename}_split_{r}.fq',
        'data/{filename}_split_{r}.fa.gz',
        'data/{filename}_split_{r}.fq.gz',
        'data/{filename}_split_{r}.owpl',
        out_file = 'data/{filename}_split_{r}.fa',
    shell:
        """python3 ./scripts/prepare_files.py {input.in_file} {output.out_file}"""

rule prepare_files_2:
    input:
        in_file = 'split/{filename}.fa'
    output:
        'data/{filename}.fq',
        'data/{filename}.fa.gz',
        'data/{filename}.fq.gz',
        'data/{filename}.owpl',
        out_file = 'data/{filename}.fa',
    shell:
        """python3 ./scripts/prepare_files.py {input.in_file} {output.out_file}"""


rule partDNA:
    input:
        script = "partDNA/build/partDNA",
        in_file = "source/{filename}"
    output:
        out_file = "split/{filename}_split_{r}"
    #benchmark:
    #    "bench/{filename}_{r}.partdna.csv"
    shell:
        """
        {input.script} -i {input.in_file} -o {output.out_file} -r {wildcards.r} -p single
        """

rule copy_non_split:
    input:
        in_file = 'source/{filename}'
    output:
        out_file = 'split/{filename}'
    shell:
        """mv {input.in_file} {output.out_file}"""

rule ibb:
    input:
        script = 'ibb/build/IBB-cli',
        source = 'data/{filename}'
    output:
        indicator = 'indicators/{filename}.ibb'
    params:
        threads = NUMBER_OF_PROCESSORS,
        k = 5,
        tempdir = 'tmp/'
    benchmark: 'bench/{filename}.ibb.csv'
    shell:
        """if {input.script} -i {input.source} -o data_bwt/ibb/{wildcards.filename} -t {params.tempdir} -k {params.k} -p {params.threads}; then 
        echo 1 > {output.indicator}
        else
        echo 0 > {output.indicator}
        fi"""

rule ibb_k_test:
    input:
        script = 'ibb/build/IBB-cli',
        source = 'data/{filename}'
    output:
        indicator='indicators/{filename}.{k}.ibb'
    params:
        threads=NUMBER_OF_PROCESSORS,
        tempdir='tmp/'
    benchmark: 'bench/{filename}.{k}.ibb.csv'
    shell:
        """if {input.script} -i {input.source} -o data_bwt/ibb/{wildcards.filename}.{wildcards.k} -t {params.tempdir} -k {wildcards.k} -p {params.threads}; then 
        echo 1 > {output.indicator}
        else
        echo 0 > {output.indicator}
        fi"""

rule bcr:
    input:
        script = 'BCR_LCP_GSA/BCR_LCP_GSA',
        source = 'data/{filename}'
    output:
        indicator = 'indicators/{filename}.bcr'
    params:
        threads = NUMBER_OF_PROCESSORS
    benchmark: 'bench/{filename}.bcr.csv'
    shell:
        """if {input.script} {input.source} data_bwt/bcr/{wildcards.filename}; then
        echo 1 > {output.indicator}
        else
        echo 0 > {output.indicator}
        fi
        rm -f cyc.*.txt"""

rule ropebwt:
    input:
        script = 'ropebwt/ropebwt',
        source = 'data/{filename}'
    output:
        indicator = 'indicators/{filename}.ropebwt'
    params:
        threads = NUMBER_OF_PROCESSORS
    benchmark: 'bench/{filename}.ropebwt.csv'
    shell:
        """if {input.script} -t -R -o data_bwt/ropebwt/{wildcards.filename} {input.source}; then
            if test -f data_bwt/ropebwt/{wildcards.filename}; then
                echo 1 > {output.indicator}
            else
                echo 0 > {output.indicator}
            fi
        else
        echo 0 > {output.indicator}
        fi"""

rule ropebwt2:
    input:
        script = 'ropebwt2/ropebwt2',
        source = 'data/{filename}'
    output:
        indicator = 'indicators/{filename}.ropebwt2'
    params:
        threads = NUMBER_OF_PROCESSORS
    benchmark: 'bench/{filename}.ropebwt2.csv'
    shell:
        """if {input.script} -R -o data_bwt/ropebwt2/{wildcards.filename} {input.source}; then
        echo 1 > {output.indicator}
        else
        echo 0 > {output.indicator}
        fi"""

rule ropebwt3:
    input:
        script = 'ropebwt3/ropebwt3',
        source = 'data/{filename}'
    output:
        indicator = 'indicators/{filename}.ropebwt3'
    params:
        threads = NUMBER_OF_PROCESSORS
    benchmark: 'bench/{filename}.ropebwt3.csv'
    shell:
        """if {input.script} build -R -t{params.threads} -do data_bwt/ropebwt3/{wildcards.filename} {input.source}; then
        echo 1 > {output.indicator}
        else
        echo 0 > {output.indicator}
        fi"""

rule bigBWT:
    input:
        script = 'Big-BWT/bigbwt',
        source = 'data/{filename}'
    output:
        indicator = 'indicators/{filename}.bigBWT'
    params:
        threads = NUMBER_OF_PROCESSORS
    benchmark: 'bench/{filename}.bigBWT.csv'
    shell:
        """if {input.script} {input.source} -t {params.threads}; then
            mv {input.source}.log data_bwt/bigBWT/{wildcards.filename}.log
            if mv {input.source}.bwt data_bwt/bigBWT/{wildcards.filename}.bwt; then
            echo 1 > {output.indicator}
            else
            echo 0 > {output.indicator}
            rm -f {input.source}.log {input.source}.bwt
            fi
        else
        echo 0 > {output.indicator}
        rm -f {input.source}.log {input.source}.bwt
        fi"""

rule grlBWT:
    input:
        script = 'grlBWT/build/grlbwt-cli',
        script2 = 'grlBWT/build/grl2plain',
        source = 'data/{filename}'
    output:
        indicator = 'indicators/{filename}.grlBWT'
    params:
        tempdir = 'tmp/',
        threads = NUMBER_OF_PROCESSORS
    benchmark: 'bench/{filename}.grlBWT.csv'
    shell:  #         rm -f {input.source}.rl_bwt; {input.script2} {input.source}.rl_bwt data_bwt/grlBWT/{wildcards.filename}
        """if {input.script} {input.source} -t {params.threads} -T {params.tempdir} -o data_bwt/grlBWT/{wildcards.filename}; then
        echo 1 > {output.indicator}
        else
        echo 0 > {output.indicator}
        fi
        """

rule egap:
    input:
        script = 'egap/eGap',
        source = 'data/{filename}'
    output:
        indicator = 'indicators/{filename}.egap'
    params:
        threads = NUMBER_OF_PROCESSORS
    benchmark: 'bench/{filename}.egap.csv'
    shell:
        """if {input.script} {input.source} -o data_bwt/egap/{wildcards.filename}; then
        echo 1 > {output.indicator}
        else
        echo 0 > {output.indicator}
        fi"""

rule gsufsort:
    input:
        script = 'gsufsort/gsufsort-64',
        source = 'data/{filename}'
    output:
        indicator = 'indicators/{filename}.gsufsort'
    params:
        threads = NUMBER_OF_PROCESSORS
    benchmark: 'bench/{filename}.gsufsort.csv'
    shell:
        """if {input.script} {input.source} --upper --bwt --output data_bwt/gsufsort/{wildcards.filename}; then
        echo 1 > {output.indicator}
        else
        echo 0 > {output.indicator}
        fi"""

rule r_pfbwt:
    input:
        script = 'r-pfbwt/build/rpfbwt',
        script2 = 'pfp/build/pfp++',
        source = 'data/{filename}'
    output:
        indicator = 'indicators/{filename}.r_pfbwt'
    params:
        w1 = 10,
        p1 = 100,
        w2 = 5,
        p2 = 11,
        tempdir = 'tmp/',
        threads = NUMBER_OF_PROCESSORS
    benchmark: 'bench/{filename}.r_pfbwt.csv'
    shell:
        """
        if ./{input.script2} -f {input.source} -w {params.w1} -p {params.p1} --output-occurrences --threads {params.threads} && ./{input.script2} -i {input.source}.parse -w {params.w2} -p {params.p2} --threads {params.threads} && ./{input.script} --l1-prefix {input.source} --w1 {params.w1} --w2 {params.w2} --threads {params.threads} --tmp-dir {params.tempdir} --bwt-only; then
        echo 1 > {output.indicator}
        mv {input.source}.rlebwt data_bwt/r_pfbwt/{wildcards.filename} 
        mv {input.source}.rlebwt.meta data_bwt/r_pfbwt/{wildcards.filename}.meta
        else
        echo 0 > {output.indicator}
        fi
        rm -f {input.source}.parse {input.source}.parse.dict {input.source}.parse.parse {input.source}.occ {input.source}.dict
        """

rule divsufsort:
    input:
        script = 'divsufsort-dna/build/dss',
        source = 'data/{filename}'
    output:
        indicator = 'indicators/{filename}.divsufsort'
    params:
        threads = NUMBER_OF_PROCESSORS
    benchmark: 'bench/{filename}.divsufsort.csv'
    shell:
        """if {input.script} -i {input.source} -o data_bwt/divsufsort/{wildcards.filename}; then 
        echo 1 > {output.indicator}
        else
        echo 0 > {output.indicator}
        fi"""

rule build_ibb:
    output:
        script = 'ibb/build/IBB-cli'
    shell:
        """
        rm -rf ./ibb
        git clone https://github.com/adlerenno/ibb
        cd ibb
        mkdir -p build
        cd build
        cmake -DPOP_COUNT=AVX512 ..
        make
        """

rule build_bcr:
    output:
        script = 'BCR_LCP_GSA/BCR_LCP_GSA'
    shell:
        """
        rm -rf ./BCR_LCP_GSA/
        git clone https://github.com/giovannarosone/BCR_LCP_GSA
        cd BCR_LCP_GSA
        make
        """

rule build_ropebwt:
    output:
        script = 'ropebwt/ropebwt'
    shell:
        """
        rm -rf ./ropebwt
        git clone https://github.com/lh3/ropebwt
        cd ropebwt
        make
        """

rule build_ropebwt2:
    output:
        script = 'ropebwt2/ropebwt2'
    shell:
        """
        rm -rf ./ropebwt2
        git clone https://github.com/lh3/ropebwt2
        cd ropebwt2
        make
        """

rule build_ropebwt3:
    output:
        script = 'ropebwt3/ropebwt3'
    shell:
        """
        rm -rf ./ropebwt3
        git clone https://github.com/lh3/ropebwt3
        cd ropebwt3
        make
        """

rule build_bigbwt:
    output:
        script = 'Big-BWT/bigbwt'
    shell:
        """
        rm -rf ./Big-BWT
        pip install psutil
        git clone https://gitlab.com/manzai/Big-BWT.git
        cd Big-BWT
        make
        """

rule build_grlbwt:  # TODO: Avoid recompile of sublibs. test if sublibs already installed.
    output:
        script = 'grlBWT/build/grlbwt-cli',
        script2 = 'grlBWT/build/grl2plain',
    shell:
        """
        rm -rf ./sdsl-lite
        rm -rf ./grlBWT
        git clone https://github.com/simongog/sdsl-lite.git
        cd sdsl-lite
        ./install.sh /usr/local/
        cd ..
        git clone https://github.com/ddiazdom/grlBWT
        cd grlBWT
        mkdir build
        cd build
        cmake ..
        make
        """

rule build_egap:
    output:
        script = 'egap/eGap'
    shell:
        """
        rm -rf ./egap
        git clone https://github.com/felipelouza/egap.git
        cd egap
        make 
        """

rule build_gsufsort:
    output:
        script = 'gsufsort/gsufsort-64'
    shell:
        """
        rm -rf ./gsufsort
        git clone https://github.com/felipelouza/gsufsort.git
        cd gsufsort
        make 
        """

rule build_r_pf:
    output:
        script = 'r-pfbwt/build/rpfbwt'
    shell:
        """
        rm -rf ./r-pfbwt
        git clone https://github.com/marco-oliva/r-pfbwt.git
        cd r-pfbwt
        mkdir build && cd build
        cmake ..
        make -j
        """

rule build_pfp:
    output:
        script = 'pfp/build/pfp++'
    shell:
        """
        rm -rf ./pfp
        git clone https://github.com/marco-oliva/pfp.git
        cd pfp
        mkdir build && cd build
        cmake ..
        make
        """

rule build_divsufsort:
    output:
        script = 'divsufsort-dna/build/dss'
    shell:
        """
        rm -rf ./libdivsufsort
        rm -rf ./divsufsort-dna
        git clone https://github.com/y-256/libdivsufsort.git
        cd libdivsufsort
        mkdir -p build
        cd build
        cmake -DCMAKE_BUILD_TYPE="Release" -DCMAKE_INSTALL_PREFIX="/usr/local" -DBUILD_DIVSUFSORT64=ON -DUSE_OPENMP=ON ..
        make
        sudo make install
        cd ../..
        git clone https://github.com/adlerenno/divsufsort-dna
        cd divsufsort-dna
        mkdir -p build
        cd build
        cmake ..
        make
"""

rule build_part_dna:
    output:
        script = "partDNA/build/partDNA"
    shell:
        """
        rm -rf ./partDNA
        git clone https://github.com/adlerenno/partDNA.git
        cd partDNA
        unzip sais-2.4.1.zip
        cd sais-2.4.1
        mkdir -p build
        cd build
        cmake -DCMAKE_BUILD_TYPE="Release" -DCMAKE_INSTALL_PREFIX="/usr/local" -DBUILD_EXAMPLES=OFF -DBUILD_SAIS64=ON -DBUILD_SHARED_LIBS=OFF ..
        make
        sudo make install
        cd ../..
        mkdir -p build
        cd build
        cmake ..
        make
        """

#################### SINGLE-WORDS ######################################

rule fetch_ncbi_human_GRCh38:  # https://www.ncbi.nlm.nih.gov/assembly/GCF_000001405.40/
    output:
        'source/GRCh38.fa'
    shell:
        """
        cd source
        if [ ! -f GCF_000001405.26_GRCh38_genomic.fna ]; then
            wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/405/GCF_000001405.26_GRCh38/GCF_000001405.26_GRCh38_genomic.fna.gz
            gzip -df GCF_000001405.26_GRCh38_genomic.fna.gz
        fi
        python3 ./../scripts/convert_grc_long.py GCF_000001405.26_GRCh38_genomic.fna GRCh38.fa
        """

rule fetch_ncbi_mouse_GRCm39:  # https://www.ncbi.nlm.nih.gov/assembly/GCF_000001635.27/
    output:
        'source/GRCm39.fa'
    shell:
        """
        cd source
        if [ ! -f GCF_000001635.27_GRCm39_genomic.fna ]; then
            wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/635/GCF_000001635.27_GRCm39/GCF_000001635.27_GRCm39_genomic.fna.gz
            gzip -df GCF_000001635.27_GRCm39_genomic.fna.gz
        fi
        python3 ./../scripts/convert_grc_long.py GCF_000001635.27_GRCm39_genomic.fna GRCm39.fa
        """

rule fetch_ncbi_tiar10:  # https://www.ncbi.nlm.nih.gov/assembly/GCF_000001735.4/
    output:
        'source/TAIR10.fa'
    shell:
        """
        cd source
        if [ ! -f GCF_000001735.4_TAIR10.1_genomic.fna ]; then
            wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/735/GCF_000001735.4_TAIR10.1/GCF_000001735.4_TAIR10.1_genomic.fna.gz
            gzip -df GCF_000001735.4_TAIR10.1_genomic.fna.gz
        fi
        python3 ./../scripts/convert_grc_long.py GCF_000001735.4_TAIR10.1_genomic.fna TAIR10.fa
        """

rule fetch_ncbi_ecoli:  # https://www.ncbi.nlm.nih.gov/nuccore/U00096.3
    output:
        'source/ASM584.fa'
    shell:
        """
        cd source
        if [ ! -f GCA_000005845.2_ASM584v2_genomic.fna ]; then
            wget ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/005/845/GCA_000005845.2_ASM584v2/GCA_000005845.2_ASM584v2_genomic.fna.gz
            gzip -df GCA_000005845.2_ASM584v2_genomic.fna.gz
        fi
        python3 ./../scripts/convert_grc_long.py GCA_000005845.2_ASM584v2_genomic.fna ASM584.fa
        """

rule fetch_ncbi_bakeryeast:  # https://www.ncbi.nlm.nih.gov/assembly/GCF_000146045.2/
    output:
        'source/R64.fa'
    shell:
        """
        cd source
        if [ ! -f GCF_000146045.2_R64_genomic.fna ]; then
            wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/146/045/GCF_000146045.2_R64/GCF_000146045.2_R64_genomic.fna.gz
            gzip -df GCF_000146045.2_R64_genomic.fna.gz
        fi
        python3 ./../scripts/convert_grc_long.py GCF_000146045.2_R64_genomic.fna R64.fa
        """

rule fetch_ncbi_tuberculosis:  # https://www.ncbi.nlm.nih.gov/assembly/GCF_000195955.2/
    output:
        'source/ASM19595.fa'
    shell:
        """
        cd source
        if [ ! -f GCF_000195955.2_ASM19595v2_genomic.fna ]; then
            wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/195/955/GCF_000195955.2_ASM19595v2/GCF_000195955.2_ASM19595v2_genomic.fna.gz
            gzip -df GCF_000195955.2_ASM19595v2_genomic.fna.gz
        fi
        python3 ./../scripts/convert_grc_long.py GCF_000195955.2_ASM19595v2_genomic.fna ASM19595.fa
        """

rule fetch_ncbi_triticum_aestivum:  # https://www.ncbi.nlm.nih.gov/datasets/genome/GCF_018294505.1/
    output:
        'source/JAGHKL01.fa'
    shell:
        """
        cd source
        if [ ! -f GCF_018294505.1_IWGSC_CS_RefSeq_v2.1_genomic.fna ]; then
            wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/018/294/505/GCF_018294505.1_IWGSC_CS_RefSeq_v2.1/GCF_018294505.1_IWGSC_CS_RefSeq_v2.1_genomic.fna.gz
            gzip -df GCF_018294505.1_IWGSC_CS_RefSeq_v2.1_genomic.fna.gz
        fi
        python3 ./../scripts/convert_grc_long.py GCF_018294505.1_IWGSC_CS_RefSeq_v2.1_genomic.fna JAGHKL01.fa
        """

##################### MULTI-WORDS ##########################


rule fetch_ncbi_SRR11092057:  # https://www.ncbi.nlm.nih.gov/sra/SRR11092057, https://www.ebi.ac.uk/ena/browser/view/SRR11092057
    output:
        'source/SRR11092057.fa'
    shell:
        # wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR110/057/SRR11092057/SRR11092057_2.fastq.gz
        """
        cd source
        if [ ! -f SRR11092057_1.fastq ]; then
            wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR110/057/SRR11092057/SRR11092057_1.fastq.gz
            gzip -df SRR11092057_1.fastq.gz
        fi
        mv SRR11092057_1.fastq SRR11092057.fa
        """

rule fetch_ncbi_SRR062634:  # https://www.ebi.ac.uk/ena/browser/view/SRR062634
    output:
        'source/SRR062634.fa'
    shell:
        """
        cd source
        
        if [ ! -f SRR062634_1.fastq ]; then
        wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR062/SRR062634/SRR062634_1.fastq.gz
        gzip -df SRR062634_1.fastq.gz
        fi
        mv SRR062634_1.fastq SRR062634.fa
        """

rule fetch_ncbi_influenza:
    output:
        'source/influenza.fa'
    shell:
        """
        cd source
        if [ ! -f influenza.fna ]; then
            wget https://ftp.ncbi.nih.gov/genomes/INFLUENZA/influenza.fna.gz
            gzip -df influenza.fna.gz
        fi
        mv influenza.fna influenza.fa
        """

rule fetch_ncbi_UB118CR3:
    output:
        'source/UB118CR3.fa'
    shell :
        """
        cd source
        if [ ! -f UB118CR3_HWN5KCCXX_L4_2.clean.fq ]; then
            wget http://ftp.sra.ebi.ac.uk/vol1/run/ERR194/ERR1942989/UB118CR3_HWN5KCCXX_L4_2.clean.fq.gz
            gzip -df UB118CR3_HWN5KCCXX_L4_2.clean.fq.gz
        fi
        mv UB118CR3_HWN5KCCXX_L4_2.clean.fq UB118CR3.fa
        """


"""Avg Read length: 101bp
Insert length: 155bp
# of reads: 36,504,800"""
"https://gage.cbcb.umd.edu/data/Hg_chr14/Data.original/frag_1.fastq.gz"
"https://gage.cbcb.umd.edu/data/Hg_chr14/Data.original/frag_2.fastq.gz"
rule fetch_gage_HGChr14:
    output:
        'source/HGChr14.fa'
    shell :
        """
        cd source
        if [ ! -f frag_1.fastq ]; then
            wget https://gage.cbcb.umd.edu/data/Hg_chr14/Data.original/frag_1.fastq.gz
            gzip -df frag_1.fastq.gz
        fi
        mv frag_1.fastq HGChr14.fa
        """

rule fetch_pacbio_wastewater:
    output:
        'source/zymowastewater.fa'
    shell:
        """
        cd source
        if [ ! -f Raw_influent_L01_R2_Sample_Library.fastq ]; then
            wget https://downloads.pacbcloud.com/public/dataset/Onso/Zymo_wastewater/fastqs/Raw_influent_L01_R2_Sample_Library.fastq.gz
            gzip -df Raw_influent_L01_R2_Sample_Library.fastq.gz
        fi
        mv Raw_influent_L01_R2_Sample_Library.fastq zymowastewater.fa
        """


################## OTHER ####################

rule fetch_ncbi_SRR5816161:  # Uses ncbi_sra to download.
    input:
        'source/SRR5816161.fastq'
    output:
        'source/SRR5816161.fa'
    shell:
        """
        mv source/SRR5816161.fastq source/SRR5816161.fa
        """

rule fetch_pangenome:
    input:
        '/usr/local/bin/datasets',
        '/usr/local/bin/dataformat'
    output:
        'hprc_pangenome.fa'
    shell:
        """
        set -e
        cd source
        datasets download genome accession PRJEB33226 --include genome --filename hprc_dataset.zip
        unzip hprc_dataset.zip -d hprc_data
        datasets rehydrate --directory hprc_data/
        cd hprc_data/ncbi_dataset/data
        # Combine all FASTA files into a single file
        cat *.fna > hprc_pangenome.fna
        mv hprc_pangenome.fna ../../../hprc_pangenome.fa
        rm -r hprc_data/
        """

###################### Download Tools ############################

rule build_sra_toolkit:  # TODO: Make more general, currently works with exact version number.
    output:
        'sratoolkit/sratoolkit.3.1.1-centos_linux64/bin/fasterq-dump',
        'sratoolkit/sratoolkit.3.1.1-centos_linux64/bin/prefetch'
    shell:
        """
        rm -rf ./sratoolkit
        wget --output-document sratoolkit.tar.gz https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/current/sratoolkit.current-centos_linux64.tar.gz
        tar -vxzf sratoolkit.tar.gz
        mv sratoolkit.3.1.1-centos_linux64 sratoolkit
        """

rule fetch_ncbi_sra:
    input:
        script_prefetch='sratoolkit/sratoolkit.3.1.1-centos_linux64/bin/prefetch',
        script_fastq='sratoolkit/sratoolkit.3.1.1-centos_linux64/bin/fasterq-dump'
    output:
        'source/{filename}.fastq'
    shell:
        """
        {input.script_prefetch} {wildcards.filename}
        {input.script_fastq} --concatenate-reads --outdir ./source/ {wildcards.filename}
        """

rule fetch_ncbi_datatools:
    output:
        '/usr/local/bin/datasets',
        '/usr/local/bin/dataformat'
    shell:
        """
        # Download and install NCBI Datasets command-line tools
        wget https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/v2/linux-amd64/datasets
        wget https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/v2/linux-amd64/dataformat
        chmod +x datasets dataformat
        sudo mv datasets dataformat /usr/local/bin/
        """
