# 02_prepare_lai.R —— 第二步：GLASS LAI 8天合成 → 月均值
# 输入：data-raw/lai/LAI/LAI_MODIS_GLASS_G005D_<year>_v20260608.nc
#       data-raw/soil/.../ChinaFlux_37sites_igbp_mapping.csv（经纬度/年份）
#       results/forcing_self.csv（31 站名单）
# 处理：逐站取最近格点，46 期 8天 LAI → 按月平均（12 月/年）
# 输出：results/lai_monthly.csv（site, year, m1..m12）

library(ncdf4)
library(lubridate)
library(dplyr)

PROJ <- "D:/CoLM_ChinaFlux"

# 1. 31 站（sp31）名单 + 经纬度/年份
name_map <- c("WSA_灌丛_燕山" = "MF_乔灌混交林_燕山")
rev_map  <- setNames(names(name_map), name_map)
sp31 <- unique(data.table::fread(file.path(PROJ, "results/forcing_self.csv"), select = "site")$site)

sites <- read.csv(file.path(PROJ, "data-raw/soil/ChinaFlux_soil5_final/ChinaFlux_37sites_igbp_mapping.csv"),
                  stringsAsFactors = FALSE) %>%
  mutate(site_sp31 = ifelse(site %in% names(rev_map), rev_map[site], site)) %>%
  filter(site_sp31 %in% sp31) %>%
  select(site_sp31, lon, lat, years)

# 2. GLASS LAI 文件清单（2000-2025 逐年）
lai_files <- list.files(file.path(PROJ, "data-raw/lai/LAI"),
                        pattern = "^LAI_MODIS_GLASS_G005D_(\\d{4})_v20260608\\.nc$",
                        full.names = TRUE)
lai_years <- as.integer(sub(".*G005D_(\\d{4})_.*", "\\1", basename(lai_files)))

# 3. 单站单年：最近格点 8 天 LAI → 12 个月均值
extract_lai_monthly <- function(lon, lat, year) {
  f <- lai_files[which(lai_years == year)]
  if (length(f) != 1) return(rep(NA_real_, 12))
  nc <- nc_open(f)
  on.exit(nc_close(nc), add = TRUE)
  ilon <- which.min(abs(ncvar_get(nc, "lon") - lon))
  ilat <- which.min(abs(ncvar_get(nc, "lat") - lat))
  lai8 <- ncvar_get(nc, "LAI", start = c(ilon, ilat, 1), count = c(1, 1, -1))
  mon  <- month(as.Date("1900-01-01") + nc$dim$time$vals)
  vapply(1:12, function(m) mean(lai8[mon == m], na.rm = TRUE), numeric(1))
}

# 4. 解析模拟年份（"2014-2018" → 2014:2018；空值补 2020:2021）
parse_years <- function(s) {
  if (is.na(s) || !nzchar(s)) return(2020:2021)
  y <- as.integer(strsplit(s, "-")[[1]])
  seq(y[1], y[2])
}

# 5. 逐站逐年提取 → 宽表
rows <- do.call(rbind, lapply(seq_len(nrow(sites)), function(i) {
  s <- sites[i, ]
  yrs <- parse_years(s$years)
  lai <- do.call(rbind, lapply(yrs, function(y) extract_lai_monthly(s$lon, s$lat, y)))
  cbind(data.frame(site = s$site_sp31, year = yrs), lai)
}))
colnames(rows)[3:14] <- paste0("m", 1:12)

write.csv(rows, file.path(PROJ, "results/lai_monthly.csv"), row.names = FALSE)
cat("已生成 results/lai_monthly.csv，共", nrow(rows), "行（站×年），", length(unique(rows$site)), "个站\n")
