# Tests for IBB library

This repository contains the [Snakefile](https://snakemake.github.io) to perform the tests of the [IBB]() paper. 
The snakefile will download all necessary repositories, 
install all necessary libraries ([SDSL](https://github.com/simongog/sdsl-lite), [divsufsort](https://github.com/y-256/libdivsufsort/tree/master)) 
and download the test datasets from [NCBI](https://www.ncbi.nlm.nih.gov/datasets/genome/). 
The order of steps might differ due to order in which the rules are performed, which can vary. 

Be aware that you might type your password or agree to an installation at any time during the process. 
This should not happen during BWT construction processes which are benchmarked.

## Requirements

You need to have at least 250GB disk space, and it will take about 19h to run all experiments.
If you want to perform fewer experiments, cancel out either APPROACHES, DATA_SETS or adjust the R_VALUES. 
If you want to add additional datasets, you need to add a rule to download that file into the source directory.
If you want to add a datasets from [NCBI](https://www.ncbi.nlm.nih.gov/datasets/genome/),
you can copy, for example, the fetch_ncbi_human_GRCh38 rule and adjust it.


## Preparation

Install [Snakemake](https://snakemake.github.io), 
you can of course use any package systems for installation.
Clone this GitHub project then:

```bash
git clone https://github.com/adlerenno/ibb-test
cd partDNAtest
```

To achieve the best results for your testing machine,
adjust the following values in 'Snakefile' to your local resources.

```
MAX_MAIN_MEMORY = 128
NUMBER_OF_PROCESSORS = 32
```

Note that we install the necessary libraries regardless if there is a preexisting installation,
because the installations might be at different locations on different platforms.

## Run

You can run all tests with:

```bash
sudo Snakemake -p --cores 1
```

## Cleanup

To clean up, run 

```bash
sudo Snakemake clean --cores 1
```

Note that this will neither delete the cloned GitHub projects of the tested approaches nor uninstall any installed library.
If you want to do so, you need to do this manually.

## Tested approaches

| Approach   | Repository-Link                               |
|------------|-----------------------------------------------|
| IBB        | https://github.com/adlerenno/ibb              |
| partDNA    | https://github.com/adlerenno/partDNA          |
| BCR        | https://github.com/giovannarosone/BCR_LCP_GSA |
| ropeBWT    | https://github.com/lh3/ropebwt                |
| ropeBWT2   | https://github.com/lh3/ropebwt2               |
| ropeBWT3   | https://github.com/lh3/ropebwt3               |
| BigBWT     | https://gitlab.com/manzai/Big-BWT             |
| r-pfbwt    | https://github.com/marco-oliva/r-pfbwt        |
| divsufsort | https://github.com/y-256/libdivsufsort        |
| grlBWT     | https://github.com/ddiazdom/grlBWT            |
| eGap       | https://github.com/felipelouza/egap           |
| gsufsort   | https://github.com/felipelouza/gsufsort       |



## Used Datasets

| filename | NCBI-Link                                                      |
|----------|----------------------------------------------------------------|
| GRCm39   | https://www.ncbi.nlm.nih.gov/datasets/genome/GCF_000001635.27/ |
| GRCh38   | https://www.ncbi.nlm.nih.gov/datasets/genome/GCF_000001405.40/ |
| JAGHKL01 | https://www.ncbi.nlm.nih.gov/datasets/genome/GCF_018294505.1/  |
