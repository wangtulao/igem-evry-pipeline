#!/usr/bin/env Rscript

# A script that:
# - Predicts MHC-I affinity of antigen candidates
# - Gives a combined score with proteasome cleavage to candidate antigens
# Run this script after the proteasome cleavage prediction (needs its output file)

# usage: $ /path/to/mhcI_affinity.R -lt 500 -th 50 -l 9 input_file.tsv output_file.tsv

# TODO: delete the useless conversion to list before merging overlapping results between proteasome cleavage and mhc I affinity results.
# TODO: integrate genetic variant and differential analysis information for a more complex scoring function

# Load needed packages and variables needed for netMHCpan
library('argparse')
NETMHCPAN_PATH <- '/path/to/netMHCpan-2.8'
Sys.setenv('NETMHCpan' = NETMHCPAN_PATH)

# Store all HLA supertype representative alleles used for prediction
HLA_ALLELES <- c('HLA-A01:01', 'HLA-A02:01', 'HLA-A03:01', 'HLA-A24:02', 
                 'HLA-A26:01', 'HLA-B07:02', 'HLA-B08:01', 'HLA-B27:05', 
                 'HLA-B39:01', 'HLA-B40:01', 'HLA-B58:01', 'HLA-B15:01')

# Command-line arguments parsing
parser <- ArgumentParser() # Parser object
parser$add_argument('input_file', type = 'character', default = '', help = 'The path/name of your proteasome cleavage prediction, used as input for this script.', nargs = 1)
parser$add_argument('output_file', type = 'character', default = '', help = 'The path/name of the output file (predicted antigenes table with MHC-I affinity data)', nargs = 1)
parser$add_argument('-lt', '--lb-threshold', type = 'integer', default = '500', help = 'The maximum threshold for low binding peptides.')
parser$add_argument('-th', '--hb-threshold', type = 'integer', default = '50', help = 'The maximum threshold for high binding peptides. ')
parser$add_argument('-l', '--peptide-length', type = 'integer', default = '9', help = 'The peptide length used by NetMHCpan.')

args <- parser$parse_args() # Parse arguments

# Check if the input file exists
inputFile <- args$input_file
if(file.access(inputFile) == -1) {
    stop(sprintf('Input file (%s) for NetMHCpan does not exist.', inputFile))
}

# Retrieve peptide sequences of potential antigens for all proteins
antigenRawTable <- read.table(inputFile, header = TRUE)
allAGs <- as.character(na.omit(antigenRawTable[antigenRawTable!=colnames(antigenRawTable), ])[, 1])
#print(allAGs)

# Save as tmp file and call NetMHCpan with this input data
netMhcPanInput <- tempfile(pattern = 'netmhcpan_input', fileext = '.pep')
tmpResultFile <- tempfile(pattern = 'netmhcpan_result', fileext = '.out')
write(allAGs, file=netMhcPanInput)

# Call NetMHCpan
print('Calling NetMHCpan')
netmhcpanCommand <- paste(
    paste0(NETMHCPAN_PATH,'/netMHCpan'),   # NetMHCpan binary
    '-p',                                  # Peptide input
    '-xls','-xlsfile', tmpResultFile,      # Simpler tabulated output 
    '-s',                                  # Sort output by descending affinity
    '-a', paste(HLA_ALLELES,collapse=','), # HLA alleles
    '-th', args$hb_threshold,              # High-binding threshold
    '-lt', args$lb_threshold,              # Low-binding threshold
    '-l', args$peptide_length,             # Peptide length
    netMhcPanInput)
system(netmhcpanCommand, ignore.stdout=TRUE) # Execute command

# Parse NetMHCpan results
print('NetMHCpan run completed. Parsing results...')
resultTable <- read.table(tmpResultFile, skip = 1, header = TRUE, check.names = FALSE)
alleles <- strsplit(readLines(tmpResultFile, n = 2), split='\t')[[1]]
# Eliminate peptides with no binding affinity found. Keep scores, sequences and alleles only
resultTable <- resultTable[resultTable$NB != 0, c(2, which(colnames(resultTable)=='nM'))]
colnames(resultTable) <- c('Peptide', alleles[which(alleles!='')]) # Alleles as column names
print('Peptides filtered.')
# Reformat table nicely
row.names(resultTable) <- resultTable[, 1]
resultTable[, 1] <- NULL

# Get peptide, HLA allele with the lowest score and affinity
selectedPepList <- list()
for(row in 1:nrow(resultTable)) {
    currentRow <- unname(unlist(resultTable[row, ]))
    peptide <- row.names(resultTable)[row]
    score <- min(currentRow)
    hlaAllele <- colnames(resultTable)[which(currentRow == score)]
# netMHCpan keeps some peptides that have a score below threshold base on their rank. 
# Get rid of them and save selected peptides/score/associatged alleles in list
    if(score <= args$lb_threshold) {
        selectedPepList$pep[row] <- peptide
        selectedPepList$score[row] <- score
        selectedPepList$hla[row] <- hlaAllele
    }
}
selectedPepList <- lapply(selectedPepList, Filter, f = Negate(is.na))
selectedPepDf <- data.frame('antigene' = selectedPepList$pep, 'nmpScore' = selectedPepList$score, 'hlaAllele' = selectedPepList$hla)

# Get only peptide that binds to the MHC-I from the input and compute the combined score
finalTable <- merge(selectedPepDf,antigenRawTable) # Subset
scores <-  apply(finalTable, 1, FUN = function(x) sum(x$netchopScore, (args$lb_threshold - x$nmpScore)/(args$lb_threshold)))
finalTable[, 'combinedScore'] <- scores 
# Save final results
write.table(finalTable, file=args$output_file, quote = FALSE, col.names=FALSE, row.names=FALSE, sep='\t')
sprintf('Results saved in %s',args$output_file)
print('MHC-I affinity prediction and final scoring done.')
