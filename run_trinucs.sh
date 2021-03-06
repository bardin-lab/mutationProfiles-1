#!/usr/bin/bash

usage() {
    echo "
  usage:   run_trinucs.sh [options]
  options:
    -v    process varscan calls
    -m    process mutect2 calls
    -e    process ensemble calls (somaticSeq + Freebayes)
    -i    process indel calls
    -a    annotate variants
    -c    clean up old files
    -g    path to genome.fasta
    -f    path to feature.gtf
    -h    show this message
  "
}

varscan=0
mutect=0
indel=0
annotate=0
normalise=0
somaticSeq=0
ensemble=0
clean=


genome=/Users/Nick_curie/Documents/Curie/Data/Genomes/dmel_6.12.fa
#genome=/Users/Nick/Documents/Curie/Data/Genomes/Dmel_v6.12/Dmel_6.12.fasta # home

features=/Users/Nick_curie/Documents/Curie/Data/Genomes/Dmel_v6.12/Features/dmel-all-r6.12.gtf
#features=/Users/Nick/Documents/Curie/Data/Genomes/Dmel_v6.12/Features/dmel-all-r6.12.gtf # home

while getopts 'nvmsaeichg:f:' flag; do
  case "${flag}" in
    v)  varscan=1 ;;
    m)  mutect=1 ;;
    s)  somaticSeq=1 ;;
    e)  ensemble=1 ;;
    n)  normalise=1 ;;
    i)  indel=1 ;;
    c)  clean=1 ;;
    g)  genome=${OPTARG};;
    f)  features=${OPTARG};;
    a)  annotate=1 ;;
    h)  usage
        exit 0 ;;
  esac
done

if [[ $# -eq 0 ]]
then
  usage
  exit 0
fi

if [[ -f "data/combined_snvs.txt" && $clean && $varscan -eq 1 || $mutect -eq 1 || $ensemble -eq 1 ]]
then
  echo "Cleaning up old snv files"
  rm data/combined_snvs.txt
fi

if [[ -f "data/combined_indels.txt" && $clean && $indel -eq 1 ]]
then
  echo "Cleaning up old indel files"
  rm data/combined_indels.txt
fi

mu_dir=data/raw/snpEff
mu_ext=_mutect_ann

if [[ $normalise -eq 1 ]]
then
  source ~/miniconda2/etc/profile.d/conda.sh
  conda activate mutationProfiles
  if hash bcftools
  then
    echo "${mu_dir}, ${mu_ext}"
    for vcf in ${mu_dir}/*${mu_ext}.vcf
    do
      # bname=echo ${vcf##*/}
      # name=${bname%_mutect_ann.vcf}
      name=$(basename "$vcf" | cut -d '_' -f1)
      echo "bcftools norm -Ov -m-any $vcf > data/${name}_mutect_norm.vcf"
      bcftools norm -Ov -m-any $vcf > data/${name}_mutect_norm.vcf
    done
    mu_dir=data
    mu_ext=mutect_norm
  else
    echo "bcftools not installed"
  fi
fi


if [[ $mutect -eq 1 ]]
then
  conda deactivate
  echo "${mu_dir}, ${mu_ext}"
  for vcf in ${mu_dir}/*${mu_ext}.vcf
  do
    # bname=echo ${vcf##*/}
    # name=${bname%_mutect_ann.vcf}
    name=$(basename "$vcf" | cut -d '_' -f1)
    #
    # if hash bcftools
    # then
    #   echo "bcftools norm -Ov -m-any $vcf > data/${name}_mutect_norm.vcf"
    #   bcftools norm -Ov -m-any $vcf > data/${name}_mutect_norm.vcf
    #   echo "perl script/vcffilter.pl -v data/${name}_mutect_norm.vcf -s mutect -o data"
    #   perl script/vcffilter.pl -v data/${name}_mutect_norm.vcf -s mutect -o data
    # else
    echo "perl script/vcffilter.pl -v $vcf -s mutect -o data"
    perl script/vcffilter.pl -v $vcf -s mutect -o data
    # fi

  done

  for filt_vcf in data/*mutect_filt.vcf
  do
    echo "perl script/trinucs.pl -g $genome -v $filt_vcf -c mutect -d data"
    perl script/trinucs.pl -g $genome -v $filt_vcf -c mutect -d data
  done
fi


if [[ $varscan -eq 1 ]]
then
  for vcf in data/raw/snpEff/*_varscan_ann.vcf
  do
    echo "perl script/vcffilter.pl -v $vcf -s varscan -o data"
    perl script/vcffilter.pl -v $vcf -s varscan -o data
  done

  for filt_vcf in data/*varscan_filt.vcf
  do
    echo "perl script/trinucs.pl -g $genome -v $filt_vcf -d data"
    perl script/trinucs.pl -g $genome -v $filt_vcf -d data
  done
fi


if [[ $somaticSeq -eq 1 ]]
then
  for filt_vcf in data/raw/snpEff/*_consensus_filt_ann.vcf
  do
    echo "perl script/trinucs.pl -g $genome -v $filt_vcf -c somaticSeq -d data"
    # perl script/trinucs.pl -g $genome -v $filt_vcf -d data
  done
fi


if [[ $ensemble -eq 1 ]]
then
  for filt_vcf in data/raw/snpEff/*_ann.vcf
  do
    echo "perl script/trinucs.pl -g $genome -v $filt_vcf -c consensus -d data"
    perl script/trinucs.pl -g $genome -v $filt_vcf -c consensus -d data
  done
fi


if [[ $indel -eq 1 ]]
then
  for vcf in data/raw/indel/snpEff/*_ann.vcf
  do
  #   echo "perl script/vcffilter.pl -v $vcf -s indel -o data"
  #   perl script/vcffilter.pl -v $vcf -s indel -o data
  # done
  #
  # for filt_vcf in data/*indel_filt.vcf
  # do
    echo "perl script/trinucs.pl -g $genome -v $vcf -c consensus -t indel -d data -o combined_indels.txt"
    perl script/trinucs.pl -g $genome -v $vcf -c consensus -t indel -d data -o combined_indels.txt
  done
fi


if [[ $annotate -eq 1 ]]
then
  if [[ $indel -eq 1 ]]
  then
    echo "Annotating indels"
    echo "perl script/snv2gene.pl -i data/combined_indels.txt -f $features -t indel"
    perl script/snv2gene.pl -i data/combined_indels.txt -f $features -t indel
  else
    echo "Annotating SNVs"
    echo "perl script/snv2gene.pl -i data/combined_snvs.txt -f $features"
    perl script/snv2gene.pl -i data/combined_snvs.txt -f $features
  fi
fi
