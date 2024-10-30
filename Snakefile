import os
from itertools import chain

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
    'ibb': 'fa',
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
}
DATA_SETS = [#'GRCh38', 'GRCm39', 'TAIR10', 'ASM584', 'R64', 'ASM19595', 'JAGHKL01'
    'SRR11092057', 'SRR062634',
]
DATA_TYPE_OF_DATA_SETS = {
    'SRR11092057':'fq',
    'SRR062634':'fq',
}
# R_VALUES = list(range(3, 6))

FILES = [f'indicators/{file}.{DATA_TYPE[approach]}.{approach}'
         for approach in APPROACHES
         for file in DATA_SETS
         ]

# Necessary to create directories because output files of bwt construction are not named in snakemake file.
for path in [BENCHMARK, SOURCE, SPLIT, INPUT, TEMP, OUTPUT, INDICATORS, RESULT] + [OUTPUT + approach for approach in APPROACHES_SINGLE + APPROACHES_MULTI]:
    os.makedirs(path, exist_ok=True)

rule target:
    input:
        bench = 'results/benchmark.csv',
        stats = 'results/file_stats.csv'

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
        combine(DATA_SETS, APPROACHES_SINGLE, DATA_TYPE, output.bench)

rule stats:
    input:
        set = [f'split/{filename}.{DATA_TYPE_OF_DATA_SETS[filename]}' for filename in DATA_SETS]
    output:
        stats = 'results/file_stats.csv'
    shell:
        """
        python3 scripts/get_file_stats.py {output.stats} {input.set}
        """


rule clean:  # TODO: Clear installations and build repositories.
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
        in_file = 'split/{filename}.fq'
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
        script = "partDNA/build/exc",
        in_file = "source/{filename}"
    output:
        out_file = "split/{filename}_split_{r}"
    benchmark:
        "bench/{filename}_{r}.partdna.csv"
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
        # script = 'ibb/ropebwt',
        source = 'data/{filename}'
    output:
        indicator = 'indicators/{filename}.ibb'
    params:
        threads = NUMBER_OF_PROCESSORS
    benchmark: 'bench/{filename}.ibb.csv'
    shell:
        """if ibb/build/BA {input.source} 5; then
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
        echo 1 > {output.indicator}
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
        script = 'ibb/build/BA'
    shell:
        """
        rm -rf ./ibb
        git clone https://github.com/adlerenno/ibb
        cd ibb
        mkdir -p build
        cd build
        cmake ..
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
        script = "partDNA/build/exc"
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

rule build_sra_toolkit:
    output:
        'sratoolkit.3.0.0-mac64/bin/fasterq-dump',
        'sratoolkit.3.0.0-mac64/bin/prefetch'
    shell:
        """
        rm -rf ./sratoolkit.3.0.0-mac64
        wget --output-document sratoolkit.tar.gz https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/current/sratoolkit.current-centos_linux64.tar.gz
        tar -vxzf sratoolkit.tar.gz
        """

rule fetch_ncbi_human_GRCh38:  # https://www.ncbi.nlm.nih.gov/assembly/GCF_000001405.40/
    output:
        'source/GRCh38.fa'
    shell:
        """
        cd source
        wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/405/GCF_000001405.26_GRCh38/GCF_000001405.26_GRCh38_genomic.fna.gz
        gzip -d GCF_000001405.26_GRCh38_genomic.fna.gz
        python3 ./../scripts/convert_grc_long.py GCF_000001405.26_GRCh38_genomic.fna GRCh38.fa
        """

rule fetch_ncbi_mouse_GRCm39:  # https://www.ncbi.nlm.nih.gov/assembly/GCF_000001635.27/
    output:
        'source/GRCm39.fa'
    shell:
        """
        cd source
        wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/635/GCF_000001635.27_GRCm39/GCF_000001635.27_GRCm39_genomic.fna.gz
        gzip -d GCF_000001635.27_GRCm39_genomic.fna.gz
        python3 ./../scripts/convert_grc_long.py GCF_000001635.27_GRCm39_genomic.fna GRCm39.fa
        """

rule fetch_ncbi_tiar10:  # https://www.ncbi.nlm.nih.gov/assembly/GCF_000001735.4/
    output:
        'source/TAIR10.fa'
    shell:
        """
        cd source
        wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/735/GCF_000001735.4_TAIR10.1/GCF_000001735.4_TAIR10.1_genomic.fna.gz
        gzip -d GCF_000001735.4_TAIR10.1_genomic.fna.gz
        python3 ./../scripts/convert_grc_long.py GCF_000001735.4_TAIR10.1_genomic.fna TAIR10.fa
        """

rule fetch_ncbi_ecoli:  # https://www.ncbi.nlm.nih.gov/nuccore/U00096.3
    output:
        'source/ASM584.fa'
    shell:
        """
        cd source
        wget ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/005/845/GCA_000005845.2_ASM584v2/GCA_000005845.2_ASM584v2_genomic.fna.gz
        gzip -d GCA_000005845.2_ASM584v2_genomic.fna.gz
        python3 ./../scripts/convert_grc_long.py GCA_000005845.2_ASM584v2_genomic.fna ASM584.fa
        """

rule fetch_ncbi_bakeryeast:  # https://www.ncbi.nlm.nih.gov/assembly/GCF_000146045.2/
    output:
        'source/R64.fa'
    shell:
        """
        cd source
        wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/146/045/GCF_000146045.2_R64/GCF_000146045.2_R64_genomic.fna.gz
        gzip -d GCF_000146045.2_R64_genomic.fna.gz
        python3 ./../scripts/convert_grc_long.py GCF_000146045.2_R64_genomic.fna R64.fa
        """

rule fetch_ncbi_tuberculosis:  # https://www.ncbi.nlm.nih.gov/assembly/GCF_000195955.2/
    output:
        'source/ASM19595.fa'
    shell:
        """
        cd source
        wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/195/955/GCF_000195955.2_ASM19595v2/GCF_000195955.2_ASM19595v2_genomic.fna.gz
        gzip -d GCF_000195955.2_ASM19595v2_genomic.fna.gz
        python3 ./../scripts/convert_grc_long.py GCF_000195955.2_ASM19595v2_genomic.fna ASM19595.fa
        """

rule fetch_ncbi_triticum_aestivum:  # https://www.ncbi.nlm.nih.gov/datasets/genome/GCF_018294505.1/
    output:
        'source/JAGHKL01.fa'
    shell:
        """
        cd source
        wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/018/294/505/GCF_018294505.1_IWGSC_CS_RefSeq_v2.1/GCF_018294505.1_IWGSC_CS_RefSeq_v2.1_genomic.fna.gz
        gzip -d GCF_018294505.1_IWGSC_CS_RefSeq_v2.1_genomic.fna.gz
        python3 ./../scripts/convert_grc_long.py GCF_018294505.1_IWGSC_CS_RefSeq_v2.1_genomic.fna JAGHKL01.fa
        """

rule fetch_ncbi_SRR11092057:  # https://www.ncbi.nlm.nih.gov/sra/SRR11092057, https://www.ebi.ac.uk/ena/browser/view/SRR11092057
    output:
        'source/SRR11092057.fq'
    shell:
        # wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR110/057/SRR11092057/SRR11092057_2.fastq.gz
        """
        cd source
        wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR110/057/SRR11092057/SRR11092057_1.fastq.gz
        gzip -d SRR11092057_1.fastq.gz
        mv SRR11092057_1.fastq SRR11092057.fq
        """

rule fetch_ncbi_SRR062634:  # https://www.ebi.ac.uk/ena/browser/view/SRR062634
    output:
        'source/SRR062634.fq'
    shell:
        """
        cd source
        wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR062/SRR062634/SRR062634_1.fastq.gz
        gzip -d SRR062634_1.fastq.gz
        mv SRR062634_1.fastq SRR062634.fq
        """

rule fetch_ncbi_sra:
    input:
        script_prefetch='sratoolkit.3.0.0-mac64/bin/prefetch',
        script_fastq='sratoolkit.3.0.0-mac64/bin/fasterq-dump'
    output:
        'source/{filename}.fq'
    shell:
        """
        {input.script_prefetch} {wildcards.filename}
        {input.script_fastq} --concatenate-reads --outdir ./source/ {wildcards.filename}
        python3 ./../scripts/convert_grc_long.py {wildcards.filename}.fastq {wildcards.filename}.fq
        """
