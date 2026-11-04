# cmfd_08_plot.R —— CMFD 版本第八步：绘图（散点 + 代表站时间序列）
# 输入：results/comparison_daily_cmfd.csv（CMFD 匹配后日数据）
# 处理：ggplot2 画 5 张散点图 + 4 张代表站时间序列（月均），文件名加 cmfd_ 前缀
# 输出：Figures/scatter_cmfd_<var>.png、Figures/timeseries_cmfd_<site>.png

library(ggplot2)
library(dplyr)

PROJ <- "D:/CoLM_ChinaFlux"
fig_dir <- file.path(PROJ, "Figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

cmp <- read.csv(file.path(PROJ, "results/comparison_daily_cmfd.csv"), stringsAsFactors = FALSE)
cmp$date <- as.Date(cmp$date)

# ---- 1. 散点图 ----
for (v in c("ET", "H", "Rnet", "GPP", "Resp")) {
  d <- cmp %>% filter(variable == v, is.finite(obs), is.finite(sim))
  r2   <- cor(d$obs, d$sim)^2
  rmse <- sqrt(mean((d$sim - d$obs)^2))
  mae  <- mean(abs(d$sim - d$obs))
  n    <- nrow(d)
  lab  <- sprintf("R2 = %.2f    RMSE = %.2f    MAE = %.2f    N = %d", r2, rmse, mae, n)

  p <- ggplot(d, aes(x = obs, y = sim)) +
    geom_point(alpha = 0.06, size = 0.4, color = "steelblue") +
    geom_abline(slope = 1, intercept = 0, color = "red", linewidth = 0.6) +
    coord_equal() +
    labs(title = paste0(v, "  CMFD版模拟 vs 观测（37 站合并）"),
         subtitle = lab, x = "观测", y = "模拟") +
    theme_bw(base_size = 12)

  ggsave(file.path(fig_dir, paste0("scatter_cmfd_", v, ".png")), p, width = 6, height = 5.5, dpi = 150)
  cat("scatter_cmfd_", v, ".png  N=", n, "\n", sep = "")
}

# ---- 2. 时间序列（代表站，逐月平均）----
rep_sites <- c(
  "GRA_高寒草甸_那曲" = "Naqu",
  "MF_针阔混交_长白山" = "Changbaishan",
  "ENF_人工针叶林_千烟洲" = "Qianyanzhou",
  "WET_高寒湿地_海北" = "Haibei_WET"
)

for (sn in names(rep_sites)) {
  d <- cmp %>%
    filter(site == sn, variable %in% c("ET", "H", "GPP")) %>%
    mutate(ym = format(date, "%Y-%m")) %>%
    group_by(ym, variable) %>%
    summarise(sim = mean(sim, na.rm = TRUE), obs = mean(obs, na.rm = TRUE), .groups = "drop") %>%
    mutate(date = as.Date(paste0(ym, "-01")))

  p <- ggplot(d, aes(x = date)) +
    geom_line(aes(y = sim, color = "模拟"), alpha = 0.85) +
    geom_line(aes(y = obs, color = "观测"), alpha = 0.85) +
    facet_wrap(~variable, scales = "free_y", ncol = 1) +
    scale_color_manual(values = c("模拟" = "steelblue", "观测" = "black")) +
    labs(title = paste0(sn, "（CMFD版）"), x = NULL, y = NULL, color = NULL) +
    theme_bw(base_size = 12)

  ggsave(file.path(fig_dir, paste0("timeseries_cmfd_", rep_sites[[sn]], ".png")),
         p, width = 10, height = 8, dpi = 150)
  cat("timeseries_cmfd_", rep_sites[[sn]], ".png\n", sep = "")
}
cat("完成\n")
