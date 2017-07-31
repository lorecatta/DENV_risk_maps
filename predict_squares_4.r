# Reshapes the combined df of square predictions from long to wide 

library(data.table)
library(fields)


# ---------------------------------------- define parameters 


x <- file.path(
  "output",
  "predictions",
  "best_model_20km_cw",
  "world_0_1667_deg",
  "pred_0_1667_deg_long.txt")

out_pt <- file.path(
  "output", 
  "predictions",
  "best_model_20km_cw",
  "world_0_1667_deg")

out_fl_nm <- "pred_0_1667_deg_wide.txt"

gr_size <- 20

res <- (1 / 120) * gr_size

lats <- seq(-90, 90, by = res)
lons <- seq(-180, 180, by = res)


# ---------------------------------------- load data 


all_preds <- fread(x,
                   header = TRUE, 
                   sep = ",",              
                   fill = TRUE, 
                   data.table = FALSE)
				   
all_preds$lat.int=floor(all_preds$lat.grid*6+0.5)
all_preds$long.int=floor(all_preds$long.grid*6+0.5)
all_preds$foi=ifelse(all_preds$mean_pred<0.01,0,all_preds$mean_pred)

lats.int=lats*6
lons.int=lons*6

mat <- matrix(NA, nrow = length(lons), ncol = length(lats)) # subtract 1 from nrow and ncol if using image.plot

i.lat <- findInterval(all_preds$lat.int, lats.int)
i.lon <- findInterval(all_preds$long.int, lons.int)

mat[cbind(i.lon, i.lat)] <- all_preds$foi

write.table(mat, 
            file.path(out_pt, out_fl_nm),
            row.names = FALSE,
            sep = ",")

# png(file.path(out_pt, "map.png"), type = "cairo", antialias = "none", width = 7, height = 3, units = "in", res = 300)
# 
# image.plot(lons, lats, mat, asp = 1)
# 
# dev.off()
