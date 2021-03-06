# Calculates the sd of each pixel prediction by interpolating the sd values, 
# calculated using bootstrap samples created with different grid sizes (or distances),
# based on the distance of the pixel to the closest data point


source(file.path("R", "utility_functions.R"))
source(file.path("R", "prepare_datasets", "calculate_mean_across_fits.R"))


# define parameters -----------------------------------------------------------


parameters <- list(id = c(5, 6, 7, 4, 8),
                   grid_size = c(0.5, 1, 2, 5, 10),
                   base_info = c("cell", 
                                 "latitude", 
                                 "longitude", 
                                 "population", 
                                 "ID_0", 
                                 "ID_1", 
                                 "ID_2", 
                                 "sd"))   

out_name <- "response_mean.rds"


# define variables ------------------------------------------------------------


model_type <- paste0("model_", parameters$id)

grid_sizes <- parameters$grid_size
  
base_info <- parameters$base_info
  
in_path <- file.path("output",
                     "predictions_world",
                     "bootstrap_models",
                     model_type,
                     "response_mean.rds")

out_path <- file.path("output",
                      "predictions_world",
                      "bootstrap_models",
                      "grid_size_interpolated")


# load data ------------------------------------------------------------------- 


all_sqr_covariates <- readRDS(file.path("output", 
                                        "env_variables", 
                                        "all_squares_env_var_0_1667_deg.rds"))

mean_predictions_all_gr_szs <- lapply(in_path, readRDS)


# start -----------------------------------------------------------------------


n <- nrow(mean_predictions_all_gr_szs[[1]])

all_sd <- vapply(seq_along(grid_sizes), 
                 get_grid_size_sd, 
                 numeric(n), 
                 pred_ls = mean_predictions_all_gr_szs)

new_col_names <- paste0("sd_", grid_sizes)

colnames(all_sd) <- new_col_names

all_sqr_covariates <- cbind(all_sqr_covariates, all_sd)

all_sqr_covariates$distance_log <- log(all_sqr_covariates$distance)

all_sqr_covariates$sd <- 0

# all_sqr_covariates <- all_sqr_covariates[302510:302520,]

N <- nrow(all_sqr_covariates)

for (i in seq_len(N)){

  all_sqr_covariates[i, "sd"] <- approx(grid_sizes, all_sqr_covariates[i, new_col_names], xout = all_sqr_covariates[i, "distance_log"])$y

}

write_out_rds(all_sqr_covariates[, base_info], out_path, out_name)
