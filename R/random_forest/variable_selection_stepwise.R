# The following functions are used for running a stepwise variable ADDITION routine 
# to assess the importance of env variables as predictors in spatially cross-validated 
# random forest models

stepwise_addition_boot <- function(i, 
                                   boot_ls, 
                                   parms, 
                                   predictors, 
                                   foi_data,
                                   out_path){
  
  stepwise_addition <- function(j){
    
    ID_run <- j
    
    stepwise_dir <- "addition"

    my_out_path <- file.path(out_path, 
                             paste("sample", ID_sample, sep = "_"), 
                             stepwise_dir,
                             paste("run", ID_run, sep = "_"))

    multi_steps_wrapper(dataset = adm_dts_boot, 
                        predictors = predictors, 
                        parms = parms,
                        level_num = 1,
                        foi_data = foi_data,
                        out_path = my_out_path)
    
  }
  
  y_var <- parms$var_to_fit
  psAb_val <- parms$pseudoAbs_value[y_var]
  no_reps <- parms$no_reps
    
  ID_sample <- i
  
  adm_dts_boot <- boot_ls[[ID_sample]]
  
  adm_dts_boot[adm_dts_boot$type == "pseudoAbsence", y_var] <- psAb_val
  
  #lapply(seq_len(no_reps), stepwise_addition)
  final_out <- stepwise_addition(no_reps)
  
  stepwise_dir <- "addition"
  out_path_2 <- file.path(out_path, 
                          paste("sample", ID_sample, sep = "_"), 
                          stepwise_dir)
  out_fl_nm <- "output_from_addition.rds"
  write_out_rds(final_out, out_path_2, out_fl_nm)
  
  final_out

}

multi_steps_wrapper <- function(dataset, 
                                predictors, 
                                parms,
                                level_num,
                                foi_data,
                                out_path){
  
  #browser()
  
  # Transform character to numeric
  vector_of_predictors <- which(names(dataset) %in% predictors)

  y_var <- parms$var_to_fit
  addition <- parms$addition
  parallel_2 <- parms$parallel_2
  
  if (addition) {
    
    stepwise_dir <- "addition"
    
    no_steps <- length(vector_of_predictors) 
    
  } else {
    
    stepwise_dir <- "removal"
    
    no_steps <- length(vector_of_predictors)-1
  
  }
  
  cat("level of stepwise addition =", level_num, "\n")
  
  # create empty vectors to store selected predictors and corr coeff value 
  changed_predictor <- NULL
  changed_predictor_rmse <- NULL
  
  for (i in seq_len(no_steps)) {
    
    cat("step of change =", i, "\n")
    
    # create combination of predictors by removing one predictor at the time from the vector of selected predictors
    
    if (addition) {
      
      variables_to_change <- vector_of_predictors [!vector_of_predictors %in% changed_predictor]    
      
      get_combs_fun <- function(x, changed_predictor){
        out <- c(changed_predictor,x)
      }
      
      combinations_of_predictors <- lapply(as.list(variables_to_change), get_combs_fun, changed_predictor)
    
    } else {
      
      variables_to_change <- vector_of_predictors    
      
      get_combs_fun <- function(x, vector_of_predictors){
        vector_of_predictors <- as.numeric(vector_of_predictors)
        out <- vector_of_predictors[-which(vector_of_predictors==x)] 
      }
      
      combinations_of_predictors <- lapply(as.list(as.numeric(variables_to_change)), 
                                           get_combs_fun, 
                                           vector_of_predictors)
      
    }
    
    ret <- loop(combinations_of_predictors, 
                combs_predictor_wrapper, 
                parms = parms,
                dataset = dataset, 
                y_var = y_var, 
                foi_data = foi_data,
                parallel = parallel_2)
    
    # extract results 
    diagnostics <- do.call("rbind", ret)

    # create matrix of all combinations of predictors used
    combinations_of_predictors_mat <- do.call("rbind", combinations_of_predictors)
    combinations_of_predictors_mat <- cbind(combinations_of_predictors_mat, 
                                            as.numeric(variables_to_change), 
                                            rep(0, nrow(combinations_of_predictors_mat)))
    colnames(combinations_of_predictors_mat) <- 1:dim(combinations_of_predictors_mat)[2]
    colnames(combinations_of_predictors_mat) <- c(paste0("x", 1:length(combinations_of_predictors[[1]])), 
                                                  "changed_predictor", 
                                                  "rmse_valid")
    
    # combine together run outputs and matrix of predictor combs 
    combinations_of_predictors_mat[,"rmse_valid"] <- diagnostics[, "rmse.valid"]
    final_output_df <- as.data.frame(combinations_of_predictors_mat, stringsAsFactors = FALSE)
    
    # sort df by rmse value
    final_output_df_sorted <- final_output_df[order(final_output_df$rmse_valid, decreasing = FALSE),]
    
    # get column index in dataset of predictor which contributed to the smallest increase in rmse 
    most_important_predictor_col_index <- final_output_df_sorted[1,"changed_predictor"]
    cat("index of changed predictor =", most_important_predictor_col_index, "\n")
    
    # get name of predictor which contributed to the smallest rmse
    most_important_changed_predictor_name <- names(dataset)[most_important_predictor_col_index]
    cat("most important changed predictor name =", most_important_changed_predictor_name, "\n")
    
    if (addition) {
      NULL
    } else {
      vector_of_predictors <- vector_of_predictors[!vector_of_predictors %in% most_important_predictor_col_index]  
    }
    
    changed_predictor [i] <- most_important_predictor_col_index
      
    changed_predictor_rmse [i] <- final_output_df_sorted[1, "rmse_valid"] 
    
    
    # save --------------------------------
    
    
    # get name and save df
    df_name_ext <- sprintf("per_step_output_%s_%s%s", 
                           paste("level", level_num, sep="_"), 
                           paste("step", i, sep="_"), 
                           ".rds")
    
    # write_out_rds(final_output_df_sorted, out_path, df_name_ext)
  
    # h2o.removeAll()
    
  }
  
  data.frame(Step = seq_len(no_steps), 
             changed_predictor = changed_predictor, 
             name = names(dataset)[changed_predictor], 
             rmse_valid = changed_predictor_rmse,
             stringsAsFactors = FALSE)
  
}

get_changed_predictors <- function(x, no_steps){
  
  vapply(x, "[[", numeric(no_steps), "changed_predictor")
  
}

get_top_from_replicates <- function(x,tops){
  
  x[1:tops,]

}

calculate_sel_freq <- function(predictors, top_ones){
  
  #browser()
  sel_freq <- table(predictors)
  
  sel_freq_sorted <- sel_freq[order(sel_freq, decreasing = TRUE)]
  
  n <- length(sel_freq_sorted)
  
  top_ones <- ifelse(top_ones > n, n, top_ones) 
  
  as.numeric(names(sel_freq_sorted[1:top_ones]))
  
}

save_addition_best_preds <- function(i, results, names, out_pth){
  
  one_boot_results <- results[[i]]
  
  ret1 <- names[one_boot_results]  
  
  out <- data.frame(predictor = one_boot_results, name = ret1, stringsAsFactors = FALSE)
  
  out_nm <- "best_predictors_from_addition.rds"
  
  out_pth <- file.path(out_pth, paste0("sample_", i), "addition")
  
  write_out_rds(out, out_pth, out_nm)
  
}

save_removal_outputs <- function(i, results, out_pth){
  
  dts <- results[[i]]
  
  out_nm <- "output_from_removal.rds"
  
  out_pth <- file.path(out_pth, paste0("sample_", i), "removal")
  
  write_out_rds(dts, out_pth, out_nm)
  
}

stepwise_removal_boot <- function(i, 
                                  boot_ls, 
                                  parms, 
                                  predictors,
                                  foi_data,
                                  out_path) {
  
  stepwise_dir <- "removal"
  
  y_var <- parms$var_to_fit
  psAb_val <- parms$pseudoAbs_value[y_var]
  
  ID_sample <- i  
  
  my_out_path <- file.path(out_path, 
                           paste("sample", ID_sample, sep="_"), 
                           stepwise_dir)
  
  adm_dts_boot <- boot_ls[[ID_sample]]
  
  adm_dts_boot[adm_dts_boot$type == "pseudoAbsence", y_var] <- psAb_val
  
  if(is.null(predictors)){
    
    predictor_file <- readRDS(file.path(out_path, 
                                        paste0("sample_", ID_sample), 
                                        "addition", 
                                        "best_predictors_from_addition.rds"))
    
    predictors <- predictor_file$name
    
  } 

  ret <- multi_steps_wrapper(dataset = adm_dts_boot, 
                             predictors = predictors, 
                             parms = parms,
                             level_num = 1,
                             foi_data = foi_data,
                             out_path = my_out_path)
  
  removed_predictors <- ret$name
  not_removed_predictor <- predictors[!predictors %in% removed_predictors] 
  
  list(not_removed_predictor, ret)

}

set_tol <- function(x, tol){
  
  x$rmse_valid <- round(x$rmse_valid, tol) 
  x

}

get_addition_results <- function(x){
  
  # browser()
  
  minimum <- which(x$rmse_valid == min(x$rmse_valid))[1]   
  
  x$name[1:minimum]
  
}  

get_removal_results <- function(x){
  
  minimum <- which(x[[2]]$rmse_valid == min(x[[2]]$rmse_valid))   
  
  end <- nrow(x[[2]])
  
  c(x[[2]]$name[(minimum+1):end], x[[1]])
  
}  
  
combs_predictor_wrapper <- function(i, 
                                    parms,
                                    dataset,
                                    y_var,
                                    foi_data) {
  
  cat("combination of predictors =", i, "\n") 
  
  my_preds <- names(dataset)[i]
  
  fit_predict_and_error(parms = parms,
                        dataset = dataset, 
                        y_var = y_var, 
                        my_preds = my_preds,
                        foi_data = foi_data)
  
}

plot_RMSE_addition <- function(i, res, out_path){
  
  dts <- res[[i]]
  
  my_out_path <- file.path(out_path, 
                           paste("sample", i, sep="_"))
  # browser()
  
  p <- ggplot(dts) +
    geom_point(aes(x = Step, y = rmse_valid)) +
    scale_x_continuous("Explanatory variable added", 
                       breaks = dts$Step, 
                       labels = dts$name) + 
    scale_y_continuous("RMSE") + 
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  dir.create(my_out_path, FALSE, TRUE)
  
  fl_nm <- "addition.png"
  
  png(file.path(my_out_path, fl_nm), 
      width = 17, 
      height = 10, 
      units = "cm",
      pointsize = 12,
      res = 200)
  
  print(p)
  
  dev.off()
  
}

plot_RMSE_removal <- function(i, res, out_path){
  
  #browser()
  
  my_out_path <- file.path(out_path, 
                           paste("sample", i, sep="_"))

  best <- res[[i]][[1]]
    
  dts <- res[[i]][[2]]
  
  p <- ggplot(dts) +
    geom_point(aes(x = Step, y = rmse_valid)) +
    scale_x_continuous("Step", breaks = dts$Step, labels = dts$name) + 
    scale_y_continuous("RMSE") + 
    geom_text(aes(x = max(dts$Step) - 3, y = sort(dts$rmse_valid, decreasing = TRUE)[2], label = best)) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  dir.create(my_out_path, FALSE, TRUE)
  
  fl_nm <- paste0("removal.png")
  
  png(file.path(my_out_path, fl_nm), 
      width = 17, 
      height = 10, 
      units = "cm",
      pointsize = 12,
      res = 200)
  
  print(p)
  
  dev.off()
  
}