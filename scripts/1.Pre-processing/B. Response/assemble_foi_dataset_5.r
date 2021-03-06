# Finds the value of the environmental covariates for each point (real and pseudo absence) in the dataset 

library(dplyr)

source(file.path("R", "utility_functions.R"))


# define paramaters -----------------------------------------------------------


base_info <- c("type",
               "date",
               "longitude",
               "latitude",
               "country",
               "ISO",
               "ID_0",
               "ID_1",
               "FOI",
               "R0_1",
               "R0_2",
               "R0_3")
  
foi_out_pt <- file.path("output", "foi")
  
foi_out_nm <- "All_FOI_estimates_and_predictors.csv"


# load data -------------------------------------------------------------------  


All_FOI_R0_estimates <- read.csv(file.path("output", 
                                           "foi", 
                                           "FOI_estimates_lon_lat_gadm_R0.csv"), 
                                 header = TRUE, 
                                 stringsAsFactors = FALSE)

pseudo_absence_points <- read.csv(file.path("output", 
                                            "datasets", 
                                            "pseudo_absence_points_2.csv"), 
                                  header = TRUE, 
                                  stringsAsFactors = FALSE)

adm1_covariates <- read.csv(file.path("output",
                                      "env_variables",
                                      "all_adm1_env_var.csv"),
                            header = TRUE, 
                            stringsAsFactors = FALSE)


# pre processing -------------------------------------------------------------- 


pseudo_absence_points$FOI <- 0
pseudo_absence_points$R0_1 <- 0
pseudo_absence_points$R0_2 <- 0
pseudo_absence_points$R0_3 <- 0
pseudo_absence_points$date <- NA
pseudo_absence_points$reference <- NA

All_FOI_R0_estimates <- All_FOI_R0_estimates[, base_info]
pseudo_absence_points <- pseudo_absence_points[, base_info]

foi_data <- rbind(All_FOI_R0_estimates, pseudo_absence_points)

foi_data_cov <- left_join(foi_data, adm1_covariates)

foi_data_cov <- cbind(data_id = seq_len(nrow(foi_data_cov)), foi_data_cov)


# save ------------------------------------------------------------------------


write_out_csv(foi_data_cov, foi_out_pt, foi_out_nm)
