# Take mean, sd and 95% CI of foi, R0 and burden measures, for each 20 km square
# THIS IS FOR THE MAPS!

options(didehpc.cluster = "fi--didemrchnb")

CLUSTER <- TRUE

my_resources <- c(
  file.path("R", "utility_functions.r"),
  file.path("R", "burden_and_interventions", "calculate_mean_across_fits.r"))

my_pkgs <- NULL

context::context_log_start()
ctx <- context::context_save(path = "context",
                             packages = my_pkgs,
                             sources = my_resources)


# ---------------------------------------- define parameters


model_tp <- "boot_model_20km_4"

vars <- c("FOI", "FOI_r")
#vars <- c("FOI", "R0_r", "I_inc", "C_inc") 

scenario_ids <- 2

no_fits <- 200

col_names <- as.character(seq_len(no_fits))

base_info <- c("cell", "lat.grid", "long.grid", "population", "ADM_0", "ADM_1", "ADM_2")

in_path <- file.path("output", "predictions_world", model_tp)

out_path <- file.path("output", "predictions_world", model_tp, "means")

dts_tag <- "all_squares"


# ----------------------------------------


if (CLUSTER) {
  
  config <- didehpc::didehpc_config(template = "12and16Core")
  obj <- didehpc::queue_didehpc(ctx, config = config)
  
} else{
  
  context::context_load(ctx)
  context::parallel_cluster_start(8, ctx)
  
}



# ---------------------------------------- run one job


# t <- obj$enqueue(
#   average_foi_and_burden_predictions(
#     seq_along(vars)[2],
#     vars = vars,
#     in_path = in_path,
#     out_path = out_path,
#     scenario_ids = scenario_ids,
#     col_names = col_names,
#     base_info = base_info,
#     dts_tag = dts_tag))
  
  
# ---------------------------------------- run


if (CLUSTER) {

  means_all_scenarios <- queuer::qlapply(
    seq_along(vars),
    average_foi_and_burden_predictions,
    obj,
    vars = vars,
    in_path = in_path,
    out_path = out_path,
    scenario_ids = scenario_ids,
    col_names = col_names,
    base_info = base_info,
    dts_tag = dts_tag)

} else {

  means_all_scenarios <- loop(
    seq_along(vars)[2],
    average_foi_and_burden_predictions,
    vars = vars,
    in_path = in_path,
    out_path = out_path,
    scenario_ids = scenario_ids,
    col_names = col_names,
    base_info = base_info,
    dts_tag = dts_tag,
    parallel = FALSE)

}

if(!CLUSTER){
  context::parallel_cluster_stop()
}