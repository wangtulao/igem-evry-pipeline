#################################
# Simple variant calling script #
#################################

# This file describes the steps to obtain the initial VCF files for variant analysis
# Variant are called using samtools and bcftools, using sorted .bam files as input
# Software requirements: samtools, bcftools
 
# 1. Index genome assembly (.faidx)
samtools faidx /path/to/human_ref_genome.fasta

# 2. samtools mpileup to generate bcf format file (roughly: conversion from .bam to .bcf)
samtools mpileup -g -f /path/to/human_ref_genome.fasta .sorted.bam sample_1.sorted.bam sample_2.sorted.bam sample_n.sorted.bam > my_var_raw.bcf

# 3. Actual variant calling + basic filtering and converison to .vcf
bcftools call -o my_var.bcf -O b -vm melanocytes_melanomes_var_raw.bcf
bcftools view my_var.bcf | vcfutils.pl varFilter - > my_var.vcf

# Variants are ready to be filtered and analyzed using the scripts in the 'variants' directory

