# cmfd_01_prepare_forcing.R —— CMFD 版本第一步：读 sp38 生成逐时强迫
# 输入：data-raw/forcing/cmfd/ChinaFlux_sp38_final_forcing_1h.csv（38 站，2000-2024）
#       results/site_params.csv（31 站的模拟年份）
# 处理：①去重（MF_乔灌混交林_燕山 = WSA_灌丛_燕山，保留后者）
#       ②时间 UTC+8h → 北京钟面；③单位换算（与 01 完全一致）
#       ④按各站模拟年份截取（31 站用 site_params，6 站用站点清单年份）
# 输出：results/forcing_cmfd.csv（37 站 × 逐时 × 8 变量）

library(dplyr)
library(lubridate)
library(readr)

PROJ <- "D:/CoLM_ChinaFlux"

# 1. 读 CMFD（只读需要的 8 列）
cmfd <- read_csv(file.path(PROJ, "data-raw/forcing/cmfd/ChinaFlux_sp38_final_forcing_1h.csv"),
                 col_select = c(site, datetime, Prec, Pres, LRad, SRad, Temp, Wind, RHum),
                 show_col_types = FALSE)

# 2. 去重：燕山灌丛在 CMFD 里有两个名（MF_乔灌混交林_燕山 与 WSA_灌丛_燕山），
#    逐时刻数据完全一致，是同一站；保留 WSA_灌丛_燕山（与自己版本命名一致）
cmfd <- cmfd %>% filter(site != "MF_乔灌混交林_燕山")

# 3. 时间对齐：CMFD 是真 UTC，+8h 转北京钟面（与 01 同口径）
cmfd <- cmfd %>% mutate(time = datetime + hours(8)) %>% select(-datetime)

# 4. 单位换算（与 01 完全一致）
cmfd <- cmfd %>%
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

# 5. 各站模拟年份：31 站用 site_params，6 个跳过站用站点清单年份
sp31 <- read.csv(file.path(PROJ, "results/site_params.csv"), stringsAsFactors = FALSE)
extra_years <- c(
  "CRO_冬小麦夏玉米_栾城" = "2007-2018",
  "GRA_粮草复合_庆阳"     = "2019-2021",
  "WET_滨海盐沼_崇明东滩" = "2004-2010",
  "WET_芦苇湿地_盘锦"     = "2018-2020",
  "WET_南荻_洞庭湖"       = "2014-2016",
  "WSA_退耕乔灌草_普定"   = "2015-2019"
)
years_df <- data.frame(
  site  = c(sp31$site, names(extra_years)),
  years = c(sp31$years, unname(extra_years)),
  stringsAsFactors = FALSE
) %>%
  mutate(
    y0 = as.integer(sub("-.*", "", years)),
    y1 = as.integer(sub(".*-", "", years))
  )

# 6. 按年份截取（北京钟面的年份）
cmfd <- cmfd %>%
  inner_join(years_df, by = "site") %>%
  filter(year(time) >= y0, year(time) <= y1) %>%
  select(site, time, Tair, Qair, Psurf, Precip, Wind, SWdown, LWdown) %>%
  arrange(site, time)

# 7. 保存
write_csv(cmfd, file.path(PROJ, "results/forcing_cmfd.csv"))
cat("已生成 results/forcing_cmfd.csv，共", nrow(cmfd), "行，",
    length(unique(cmfd$site)), "个站\n")
