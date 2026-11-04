# 01_prepare_forcing.R —— 第一步：读 sp31 + CMFD，生成"自己版本"逐时强迫
# 输入：data-raw/forcing/sp31/Forcing_Hourly_Met_sp31_...csv
#       data-raw/forcing/cmfd/ChinaFlux_sp38_final_forcing_1h.csv
# 处理：时间对齐（CMFD UTC→北京时间）、按站点+时间合并、
#       单位换算（°C→K、RH→比湿、mm/h→kg/m²/s 等）
# 输出：results/forcing_self.csv（31 站 × 逐时 × 8 变量）

library(dplyr)
library(readr)
library(lubridate)
library(data.table)

#  1. 读数据
# sp31： 31 站逐时（Ta 气温/RH 湿度/WS 风/Rs 短波/Prcp 降水，缺气压、缺长波）
# 用 select 只读需要的列，去掉 Rln_in（不用它，省内存）
sp31 <- fread("data-raw/forcing/sp31/Forcing_Hourly_Met_sp31_v20260629_MergeCFMD.csv",
              select = c("site", "time", "Ta", "RH", "WS", "Rs", "Prcp"))

# CMFD sp38：38 站逐时（7 变量齐全，含 Pres 气压、LRad 长波——用来补 sp31 缺的）
# 注意：这个文件 1.1GB，fread 的内存映射会失败（内存不够），改用 read_csv 逐块读
cmfd <- read_csv("data-raw/forcing/cmfd/ChinaFlux_sp38_final_forcing_1h.csv", show_col_types = FALSE)

#  2. 时间对齐
# CMFD 时间是 UTC（世界时），sp31 是北京时间（UTC+8）
# 注意：fread 已自动把时间列解析成日期类型，不要再 ymd_hms（重复解析会报错）
# sp31 的 time 已经是日期类型，直接保留；CMFD 是真 UTC，直接 +8 小时转北京钟面
cmfd <- cmfd %>%
  mutate(datetime = datetime + hours(8)) %>%
  rename(time = datetime)

#  3. 合并两张表
merged <- sp31 %>%
  left_join(cmfd, by = c("site", "time"))

# 合并完就释放两个大对象，腾出内存（内存紧张时很关键）
rm(sp31, cmfd); gc()

#  4. 用 CMFD 填补 sp31 的缺测
# sp31 里有缺测（NA），用 CMFD 同站同时刻的值补上（同一数据源，物理一致）
merged <- merged %>%
  mutate(
    Ta    = ifelse(is.na(Ta),    Temp,  Ta),
    RH    = ifelse(is.na(RH),    RHum,  RH),
    WS    = ifelse(is.na(WS),    Wind,  WS),
    Rs    = ifelse(is.na(Rs),    SRad,  Rs),
    Prcp  = ifelse(is.na(Prcp),  Prec,  Prcp)
  )

#  5. 单位换算
# CoLM 要求：Tair=K、Qair=kg/kg、Psurf=Pa、Precip=kg/m²/s、Wind=m/s、SW/LW=W/m²
merged <- merged %>%
  mutate(
    Tair   = Ta + 273.15,
    Psurf  = Pres,
    Precip = Prcp / 3600,
    Wind   = WS,
    SWdown = Rs,
    LWdown = LRad
  ) %>%
  mutate(
    # 比湿 Qair：由 RH(%) 和气压(Pa) 算
    # 公式：es=6.112*exp(17.62*T/(243.12+T))，e=RH/100*es，q=0.622*e/(P-0.378*e)
    es   = 6.112 * exp(17.62 * Ta / (243.12 + Ta)),   # 饱和水汽压 (hPa)
    e    = RH / 100 * es,                            # 实际水汽压 (hPa)
    Qair = 0.622 * e / (Psurf / 100 - 0.378 * e)     # 比湿 (kg/kg)
  ) %>%
  # 截断异常比湿（物理范围 0~0.05）
  mutate(Qair = pmin(pmax(Qair, 0), 0.05))

#  6. 只保留 CoLM 需要的 8 列，并按站点+时间排好
forcing <- merged %>%
  select(site, time, Tair, Qair, Psurf, Precip, Wind, SWdown, LWdown) %>%
  arrange(site, time)

#  7. 保存 
write_csv(forcing, "results/forcing_self.csv")
cat("已生成 results/forcing_self.csv，共", nrow(forcing), "行，",
    length(unique(forcing$site)), "个站\n")
