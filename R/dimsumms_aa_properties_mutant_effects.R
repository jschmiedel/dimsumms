
#' dimsumms_aa_properties_mutant_effects
#'
#' Calculate single and double mutant effects from AA PCA (using single mutants).
#'
#' @param toxicity_dt data.table with single and double mutant codes (required)
#' @param outpath output path for plots and saved objects (required)
#' @param aaprop_file path to amino acid properties file (required)
#' @param aaprop_file_selected path to file with selected subset of identifiers
#' @param colour_scheme colour scheme file (required)
#' @param report whether or not to save output and plots (default:F)
#'
#' @return A data.table with single and double mutant effects from AA PCA
#' @export
#' @import data.table
dimsumms_aa_properties_mutant_effects <- function(
  toxicity_dt,
  outpath,
  aaprop_file,
  aaprop_file_selected,
  colour_scheme,
  report = F
  ){

	# #Return previous results if analysis not executed
	# if(!execute){
	# 	load(file.path(outpath, "aa_properties_mutant_effects.RData"))
	# 	return(dms_dt_aaprop)
	# }

	# #Display status
	# message(paste("\n\n*******", "running stage: dimsumms_aa_properties_mutant_effects", "*******\n\n"))

	# #Create output directory
	# dimsumms__create_dir(dimsumms_dir = outpath)

	### AA properties PCA
	###########################

  #AA properties PCA
  exp_pca_list <- dimsumms__aa_properties_pca(
  	aa_properties_file = aaprop_file, 
  	selected_identifiers = unlist(fread(aaprop_file_selected, header = F)),
  	return_evidences = T)
  exp_pca <- exp_pca_list[["PCA"]]
  aa_evidences <- exp_pca_list[["evidences"]]

  #% variance explained by top 5 PCs
  top5pc_var <- sum((exp_pca$sdev^2/sum(exp_pca$sdev^2))[1:5])

  if(report){
		#Screeplot
		plot_df <- data.frame(perc_var = exp_pca$sdev^2/sum(exp_pca$sdev^2)*100, pc = 1:20)
		plot_df[,"pc"] <- factor(plot_df[,"pc"], levels = 1:20)
		d <- ggplot2::ggplot(plot_df, ggplot2::aes(pc, perc_var)) +
		  ggplot2::geom_bar(stat = "identity") +
		  ggplot2::geom_vline(xintercept = 5.5, linetype = 2) +
		  ggplot2::theme_bw() +
		  ggplot2::annotate("text", x = 10, y = 30, label = paste0("Var. explained by PC1-5 = ", round(top5pc_var*100, 0), "%"))
		ggplot2::ggsave(file=file.path(outpath, 'PCA_screeplot.pdf'), width=4, height=4)
  
		#Top features on top 5 PCs
		aa_evidences_name <- as.list(paste(names(aa_evidences), unlist(aa_evidences), sep = ": "))
		names(aa_evidences_name) <- names(aa_evidences)
		for(i in 1:5){
			output_file = file.path(outpath, paste0("PCA_loadings_PC", i, "_highlow.txt"))
		  lapply(aa_evidences_name[rownames(exp_pca$rotation)[order(exp_pca$rotation[,i], decreasing = T)[1:20]]], write, output_file, append=TRUE, ncolumns=1000)
		  write("...", file = output_file, append=TRUE)
		  lapply(rev(aa_evidences_name[rownames(exp_pca$rotation)[order(exp_pca$rotation[,i], decreasing = F)[1:20]]]), write, output_file, append=TRUE, ncolumns=1000)
		}
	}

	#Feature type
	temp_cols <- c("black", unlist(colour_scheme[["shade 0"]][1:4]), "grey")
	feature_type <- rep("6_Remainder", dim(exp_pca$rotation)[1])
	feature_type[grep("hydrophobic|Hydrophobic", unlist(aa_evidences))] <- "1_hydrophobic/Hydrophobic"
	feature_type[grep("helix|helical", unlist(aa_evidences))] <- "2_helix/helical"
	feature_type[grep("composition|Composition", unlist(aa_evidences))] <- "3_composition/Composition"
	feature_type[grep("linker|Linker", unlist(aa_evidences))] <- "4_linker/Linker"
	feature_type[grep("beta-sheet|beta-strand|Beta-sheet|Beta-strand", unlist(aa_evidences))] <- "5_beta-sheet/beta-strand/Beta-sheet/Beta-strand"
	names(temp_cols) <- unique(feature_type[order(feature_type)])

	if(report){
		dimsumms__plot_loadings(
			pca_obj=exp_pca, 
			output_file=file.path(outpath, paste0('PCA_biplots_5_symbols.pdf')),
			plot_categories=feature_type,
			plot_colours=temp_cols, 
			comps=1:5, 
			plot_symbol=19,
			width=15, height=15)

		dimsumms__plot_loadings(
			pca_obj=exp_pca, 
			output_file=file.path(outpath, paste0('PCA_biplots_5_symbols_PC1_PC2.pdf')),
			plot_categories=feature_type,
			plot_colours=temp_cols, 
			comps=1:2, 
			plot_symbol=19,
			width=10, height=5)
	}

	### Single mutant effects on AA properties 
	###########################

	singles_dt <- copy(toxicity_dt[Nham_aa==1 & !STOP,])
	#Add amino acid properties
	singles_dt <- dimsumms__aa_properties_pca_singles_loadings(
		input_dt = singles_dt, 
		aa_properties_file = aaprop_file, 
		selected_identifiers = unlist(fread(aaprop_file_selected, header = F)))
	names(singles_dt) <- gsub("_score", "", names(singles_dt))
	top_PCs <- 5
	top_PC_signs <- c(-1, -1, 1, -1, -1)
	top_PC_names <- c("Hydrophobicity", "Helix propensity", "Commonness", "Linker propensity", "Beta-sheet propensity")
	for(i in 1:top_PCs){singles_dt[, (paste0('PC', i)) := scale(.SD, scale=top_PC_signs[i], center=F),,.SDcols = paste0('PC', i)]}
	names(singles_dt)[grep("^PC", names(singles_dt))][1:5] <- paste0(names(singles_dt)[grep("^PC", names(singles_dt))][1:5], " (", top_PC_names, ")")

	### Double mutant effects on AA properties 
	###########################

	doubles_dt <- copy(toxicity_dt[Nham_aa==2 & !STOP,])
	#Add amino acid properties
	doubles_dt <- dimsumms__aa_properties_pca_doubles_loadings(
		input_dt = doubles_dt, 
		aa_properties_file = aaprop_file, 
		selected_identifiers = unlist(fread(aaprop_file_selected, header = F)))
	names(doubles_dt) <- gsub("_score_sum", "", names(doubles_dt))
	top_PCs <- 5
	top_PC_signs <- c(-1, -1, 1, -1, -1)
	top_PC_names <- c("Hydrophobicity", "Helix propensity", "Commonness", "Linker propensity", "Beta-sheet propensity")
	for(i in 1:top_PCs){doubles_dt[, (paste0('PC', i)) := scale(.SD, scale=top_PC_signs[i], center=F),,.SDcols = paste0('PC', i)]}
	names(doubles_dt)[grep("^PC", names(doubles_dt))][1:5] <- paste0(names(doubles_dt)[grep("^PC", names(doubles_dt))][1:5], " (", top_PC_names, ")")

	### Merge 
	###########################

	dms_dt_aaprop <- rbind(
		copy(toxicity_dt[!(Nham_aa==2 & !STOP) & !(Nham_aa==1 & !STOP)]),
		singles_dt,
		doubles_dt,
		fill = T)

	if(report){
		#RData object
		save(dms_dt_aaprop, file = file.path(outpath, "aa_properties_mutant_effects.RData"))
	}

	#Return normalised toxicity data.table
	return(dms_dt_aaprop)
}

