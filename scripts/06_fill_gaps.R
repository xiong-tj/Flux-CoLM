# 06_fill_gaps.R —— 第六步：用 CMFD 补全所有站的时间缺口（头/尾/中间）
# 输入：results/forcing_self.csv（有缺口）
#       data-raw/forcing/cmfd/ChinaFlux_sp38_final_forcing_1h.csv（完整，2000-2024）
#       results/site_params.csv（模拟年份）
# 处理：对每站建完整逐时时间轴（年初~年末），缺的时刻从 CMFD 取并换算（口径与 01 一致）
# 输出：results/forcing_self.csv（覆盖，补全后无任何时间缺口）

library(dplyr)
library(lubridate)
library(readr)

PROJ <- "D:/CoLM_ChinaFlux"

# 1. 读 forcing 与模拟年份
forcing <- data.table::fread(file.path(PROJ, "results/forcing_self.csv"))
site_params <- read.csv(file.path(PROJ, "results/site_params.csv"), stringsAsFactors = FALSE)

# 2. 读 CMFD（与 01 同口径：read_csv 解析 UTC，+8h 转北京钟面），换算成 8 变量
cmfd <- read_csv(file.path(PROJ, "data-raw/forcing/cmfd/ChinaFlux_sp38_final_forcing_1h.csv"),
                 col_select = c(site, datetime, Prec, Pres, LRad, SRad, Temp, Wind, RHum),
                 show_col_types = FALSE) %>%
  filter(site %in% site_params$site) %>%
  mutate(time = datetime + hours(8)) %>%
  select(-datetime) %>%
  mutate(
    Tair   = Temp + 273.15,
    Psurf  = Pres,
    Precip = Prec / 3600,
    Wind   = Wind,
    SWdown = SRad,
    LWdown = LRad,
    es     = 6.112 * exp(17.62 * Temp / (243.12 + Temp)),
    e      = RHum / 100 * es,
    Qair   = pmin(pmax(0.622 * e / (Psurf / 100 - 0.378 * e), 0), 0.05)
  ) %>%
  select(site, time, Tair, Qair, Psurf, Precip, Wind, SWdown, LWdown)

# 3. 单站补全：完整逐时轴 - 已有时刻 = 缺的时刻，从 CMFD 填
fill_site <- function(sn) {
  y <- as.integer(strsplit(site_params$years[site_params$site == sn], "-")[[1]])
  full_time <- seq(as.POSIXct(paste0(y[1], "-01-01 00:00:00"), tz = "UTC"),
                   as.POSIXct(paste0(y[2], "-12-31 23:00:00"), tz = "UTC"),
                   by = "hour")
  fc_site <- forcing[site == sn]
  missing_t <- setdiff(full_time, fc_site$time)
  if (length(missing_t) == 0) return(fc_site)
  fill <- cmfd %>% filter(site == sn, time %in% missing_t)
  rbind(fc_site, fill) %>% arrange(time)
}

# 4. 逐站补全 → 合并
forcing_new <- do.call(rbind, lapply(site_params$site, fill_site))
forcing_new <- forcing_new[order(site, time)]

readr::write_csv(forcing_new, file.path(PROJ, "results/forcing_self.csv"))
cat("已补全 results/forcing_self.csv，共", nrow(forcing_new), "行，",
    length(unique(forcing_new$site)), "个站\n")
