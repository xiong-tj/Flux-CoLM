# 09_validate.R —— 第九步：模拟 vs 观测 算精度
# 输入：results/sim_daily.csv（模拟日通量）
#       data-raw/obs/fluxsm/ChinaFlux_FluxSM_39sp_v20260330.rda（老师观测，日尺度）
# 处理：名称映射、单位换算（观测→模拟口径）、按日期匹配、逐站逐变量算 R²/RMSE/MAE/Bias/N
# 输出：results/validation_metrics.csv（长表）+ results/validation_summary.csv（按变量汇总）

library(dplyr)
library(data.table)

PROJ <- "D:/CoLM_ChinaFlux"
skip_first_year <- FALSE   # TRUE = 跳过每站首年（spinup 瞬变）

# 1. 模拟（sim_daily.csv）
sim <- read.csv(file.path(PROJ, "results/sim_daily.csv"), stringsAsFactors = FALSE)
sim$date <- as.Date(sim$date)
sim$year <- as.integer(format(sim$date, "%Y"))

# 2. 观测（老师 FluxSM，39 站日尺度）
e <- new.env()
load(file.path(PROJ, "data-raw/obs/fluxsm/ChinaFlux_FluxSM_39sp_v20260330.rda"), envir = e)
obs_list <- e$lst_flux_SM

# 3. 名称映射（sp31 模拟名 → FluxSM 观测名）
name_map <- c(
  "CRO_春玉米_锦州" = "锦洲", "CRO_冬小麦夏玉米_固城" = "固城",
  "CRO_冬小麦夏玉米_禹城" = "禹城", "CRO_水稻_句容" = "句容",
  "CRO_水稻_盘锦" = "盘锦", "CRO_水稻_长岭" = "长岭",
  "CRO_制种玉米_临泽" = "临泽", "DBF_栓皮栎人工林_小浪底" = "小浪底_栓皮栎人工林",
  "DBF_天然栎林_宝天曼" = "宝天曼_天然栎林", "EBF_热带雨林_西双版纳" = "西双版纳_热带雨林",
  "EBF_橡胶林_海南儋州" = "儋州-橡胶林", "EBF_橡胶林_西双版纳" = "西双版纳_橡胶林",
  "EBF_亚热带常绿阔叶林_金佛山" = "金佛山_亚热带", "ENF_北方林森林_呼中" = "呼中_北方森林",
  "ENF_人工针叶林_千烟洲" = "千烟洲_人工针叶林", "ENF_人工针叶林_燕山" = "燕山_人工针叶林",
  "GRA_典型草原_多伦" = "多伦", "GRA_典型草原_锡林浩特" = "锡林浩特-典型草原",
  "GRA_高寒草甸_当雄" = "当雄_高寒草甸", "GRA_高寒草甸_海北" = "海北_高寒草甸",
  "GRA_高寒草甸_那曲" = "那曲_高寒草甸", "GRA_高寒草甸_若尔盖" = "若尔盖-高寒草甸",
  "GRA_人工垂穗披碱草_三江源" = "三江源-垂穗披碱草", "GRA_稀树草原_元江" = "元江_稀树草原",
  "GRA_刈割草原_锡林浩特" = "锡林浩特", "MF_针阔混交_鼎湖山" = "鼎湖山_针阔叶混交林",
  "MF_针阔混交_长白山" = "长白山_针阔混交林", "SAV_荒漠草原_达茂" = "达茂_荒漠草原",
  "WET_高寒湿地_海北" = "海北_高寒湿地", "WSA_高寒灌丛_海北" = "海北_高寒灌丛",
  "WSA_灌丛_燕山" = "燕山-山地丘陵区"
)

# 4. 观测 → 模拟口径单位
#    rda 里 Rn/Hs/LE 已是 W/m²（不用换）；ET 是 mm/d（直接用）；
#    GPP/RE 是 gC/m²/d → µmol/m²/s = ÷12(碳摩尔质量) ×1e6 ÷86400
conv_obs <- function(sn) {
  x <- as.data.frame(obs_list[[name_map[[sn]]]])
  x$date <- as.Date(x$date)
  data.frame(
    site = sn, date = x$date,
    ET   = if ("ET" %in% names(x)) x$ET else if ("LE" %in% names(x)) x$LE * 86400 / 2.45e6 else NA_real_,
    H    = if ("Hs" %in% names(x)) x$Hs else NA_real_,
    Rnet = if ("Rn" %in% names(x)) x$Rn else NA_real_,
    GPP  = if ("GPP" %in% names(x)) x$GPP / 12 * 1e6 / 86400 else NA_real_,
    Resp = if ("RE" %in% names(x)) x$RE / 12 * 1e6 / 86400 else NA_real_
  )
}
obs <- do.call(rbind, lapply(names(name_map), conv_obs))

# 5. 转长表 + 按站点/日期/变量匹配
vars <- c("ET", "H", "Rnet", "GPP", "Resp")
sim_long <- melt(as.data.table(sim), id.vars = c("site", "date", "year"),
                 measure.vars = vars, variable.name = "variable", value.name = "sim")
obs_long <- melt(as.data.table(obs), id.vars = c("site", "date"),
                 measure.vars = vars, variable.name = "variable", value.name = "obs")

d <- inner_join(as.data.frame(sim_long), as.data.frame(obs_long),
                by = c("site", "date", "variable"))
if (skip_first_year) {
  d <- d %>% group_by(site) %>% filter(year > min(year)) %>% ungroup()
}
write.csv(d, file.path(PROJ, "results/comparison_daily.csv"), row.names = FALSE)

# 6. 指标
calc_metrics <- function(obs, sim) {
  ok <- complete.cases(obs, sim); obs <- obs[ok]; sim <- sim[ok]
  data.frame(R2 = cor(obs, sim)^2, RMSE = sqrt(mean((sim - obs)^2)),
             MAE = mean(abs(sim - obs)), Bias = mean(sim - obs), N = length(obs))
}

# 6. 指标（R² 用安全版：配对样本 <2 时返回 NA，不报错）
r2 <- function(o, s) {
  ok <- complete.cases(o, s)
  if (sum(ok) < 2) return(NA_real_)
  cor(o[ok], s[ok])^2
}

metrics <- d %>%
  group_by(site, variable) %>%
  summarise(
    R2 = r2(obs, sim),
    RMSE = sqrt(mean((sim - obs)^2, na.rm = TRUE)),
    MAE = mean(abs(sim - obs), na.rm = TRUE),
    Bias = mean(sim - obs, na.rm = TRUE),
    N = sum(complete.cases(obs, sim)),
    .groups = "drop"
  )

# 7. 输出
write.csv(metrics, file.path(PROJ, "results/validation_metrics.csv"), row.names = FALSE)

summary <- metrics %>%
  group_by(variable) %>%
  summarise(
    n_stations = sum(!is.na(R2)),
    R2_median = median(R2, na.rm = TRUE), R2_mean = mean(R2, na.rm = TRUE),
    RMSE_median = median(RMSE, na.rm = TRUE), RMSE_mean = mean(RMSE, na.rm = TRUE),
    MAE_median = median(MAE, na.rm = TRUE), Bias_median = median(Bias, na.rm = TRUE),
    .groups = "drop"
  )
write.csv(summary, file.path(PROJ, "results/validation_summary.csv"), row.names = FALSE)

cat("已生成 validation_metrics.csv（", nrow(metrics), "行）和 validation_summary.csv\n")
print(as.data.frame(summary), row.names = FALSE)
