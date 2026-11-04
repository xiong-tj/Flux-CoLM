# 11_report.R —— 第十一步：生成验证汇总报告
# 输入：results/validation_summary.csv、validation_metrics.csv、Figures/*.png
# 处理：拼装指标表 + 每变量最佳/最差站 + 图链接 + 注意事项
# 输出：docs/验证报告.md

library(dplyr)

PROJ <- "D:/CoLM_ChinaFlux"
dir.create(file.path(PROJ, "docs"), showWarnings = FALSE)

summary <- read.csv(file.path(PROJ, "results/validation_summary.csv"), stringsAsFactors = FALSE)
metrics <- read.csv(file.path(PROJ, "results/validation_metrics.csv"), stringsAsFactors = FALSE)

# ---- 每变量最佳/最差 3 站（要求 N >= 30，按 R² 排序）----
best_worst <- metrics %>%
  filter(N >= 30) %>%
  group_by(variable) %>%
  summarise(
    best  = paste(site[order(-R2)][1:3], round(R2[order(-R2)][1:3], 2), collapse = "；"),
    worst = paste(site[order(R2)][1:3],  round(R2[order(R2)][1:3], 2),  collapse = "；"),
    .groups = "drop"
  )

# ---- 拼 markdown（add=纯文本，addf=带格式）----
L <- character()
add  <- function(x) L <<- c(L, x)
addf <- function(fmt, ...) L <<- c(L, sprintf(fmt, ...))

add("# CoLM 单点模拟验证报告（自己版本，31 站）")
add("")
add("## 一、概述")
add("")
add("- 模型：CoLM 单点（kernel `default`，LULC_IGBP，无 BGC/CROP）")
add("- 站点：31 个 ChinaFlux 站（自己版本 = sp31 实测 + CMFD 补缺）")
add("- 时段：各站自身观测时段（2003–2022）")
add("- 观测：老师 ChinaFlux FluxSM 日尺度（39 站中取 31 站）")
add("- 变量：ET / H / Rnet / GPP / Resp；**Qg 观测缺失，未做**")
add("- 配置：`spinup_repeat=0`（含首年瞬变，未跳过）；逐时 history → 日尺度聚合")
add("")
add("## 二、精度汇总")
add("")
add("| 变量 | 站数 | R² 中位数 | R² 均值 | RMSE 中位数 | MAE 中位数 | Bias 中位数 |")
add("|---|---|---|---|---|---|---|")
for (i in seq_len(nrow(summary))) {
  r <- summary[i, ]
  addf("| %s | %d | %.2f | %.2f | %.2f | %.2f | %.2f |",
       r$variable, r$n_stations, r$R2_median, r$R2_mean,
       r$RMSE_median, r$MAE_median, r$Bias_median)
}
add("")
add("*整体：Rnet 最好（R²≈0.86），Resp/GPP/ET 中等（0.5~0.6），H 最差（0.18，感热为能量平衡残差）*")
add("")
add("## 三、每变量最佳 / 最差 3 站（R²，仅 N≥30 的站）")
add("")
for (i in seq_len(nrow(best_worst))) {
  r <- best_worst[i, ]
  addf("- **%s**：最佳——%s；最差——%s", r$variable, r$best, r$worst)
}
add("")
add("## 四、图")
add("")
add("### 散点图（31 站合并，1:1 线）")
add("")
for (v in c("ET", "H", "Rnet", "GPP", "Resp")) {
  addf("![%s](../Figures/scatter_%s.png)", v, v)
  add("")
}
add("### 时间序列（代表站，逐月平均）")
add("")
for (s in c("Naqu", "Changbaishan", "Qianyanzhou", "Haibei_WET")) {
  addf("![%s](../Figures/timeseries_%s.png)", s, s)
  add("")
}
add("## 五、注意事项")
add("")
add("1. **长岭（水稻）太阳辐射异常**：老师 sp31 数据里长岭 7 月 Rs 仅 40 W/m²（正常约 200），导致其 ET/H/Rnet 精度差（R² 0.16/0.001/0.16），但 GPP/Resp 尚可（0.64/0.88）。该站按正常参与统计，未剔除。")
add("2. **缺观测的站/变量**：GPP/Resp——临泽、多伦、锡林浩特刈割（观测无此列）；Rnet——三江源（无 Rn 列）。这些组合自动为 NA，不参与该变量的中位数。")
add("3. **燕山两站 Rn 仅 3 个有效天**：燕山灌丛、燕山针叶林的 Rn 列 99.6% 缺测，Rnet 用 N=3 计算，统计上不可靠（R²=0.99 属偶然）。")
add("4. **首年瞬变（spinup=0）**：每站第 1 年有土壤水排水/蓄水瞬变（首年 7 月 ET 与后续年中位数比 1.18，方向不一），本次按「不跳首年」口径统计。")
add("5. **H 整体偏低**：感热是能量平衡残差，辐射/潜热误差累积到 H，R² 普遍低（中位数 0.18），属单点通量模拟常见现象。")
add("6. **单位口径**：观测已换算——能量通量 W/m²（老师 FluxSM 的 Rn/Hs/LE 本就是 W/m²）、碳通量 gC/m²/d（÷12×1e6÷86400 → µmol/m²/s）、ET mm/d。")
add("7. **kernel 无 BGC/CROP**：GPP 为光合碳同化（f_assim）、Resp 为自养呼吸（f_respc），不含异养呼吸/作物模块；水稻/农田站（长岭、盘锦等）无灌溉与作物物候。")

writeLines(L, file.path(PROJ, "docs/验证报告.md"), useBytes = TRUE)
cat("已生成 docs/验证报告.md，共", length(L), "行\n")
