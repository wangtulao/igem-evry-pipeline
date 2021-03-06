# This file describes the steps to obtain the gene counts table needed for RNAseq differential expression analysis
# Software requirements: fastqc, bowtie, samtools

# FASTQC quality control
fastqc normal_reads.fastq -o ./.
fastqc cancer_reads.fastq -o ./.

# Trim and clip adapters if needed 

# Map to the reference genome (example here with human_hg19)

# 1. Build bowtie indexes
bowtie-build human_hg19.fasta human_hg19

# 2. Bowtie mapping
bowtie -S human_hg19 normal_reads.fastq > normal_reads_bowtie_mapping.sam
bowtie -S human_hg19 cancer_reads.fastq > cancer_reads_bowtie_mapping.sam

# 3. SAM to BAM 
samtools view -bS normal_reads_bowtie_mapping.sam  > normal_reads_bowtie_mapping.bam
samtools sort normal_reads_bowtie_mapping.bam normal_reads_bowtie_mapping.sorted
samtools index normal_reads_bowtie_mapping.sorted.bam

samtools view -bS cancer_reads_bowtie_mapping.sam  > cancer_reads_bowtie_mapping.bam
samtools sort cancer_reads_bowtie_mapping.bam cancer_reads_bowtie_mapping.sorted
samtools index cancer_reads_bowtie_mapping.sorted.bam


# Read counts per gene
bedtools multicov -bams normal_reads_bowtie_mapping.sorted.bam -bed human_hg19_genes.gff > normal_reads_gene_counts.gff
sed 's/^.*ID=//' normal_reads_gene_counts.gff > normal_reads_counts.tab

bedtools multicov -bams cancer_reads_bowtie_mapping.sorted.bam -bed human_hg19_genes.gff > normal_reads_gene_counts.gff
sed 's/^.*ID=//' cancer_reads_gene_counts.gff > cancer_reads_counts.tab

# Create a table to sum up gene counts for differential expression analysis ('DE_analysis' directory)

