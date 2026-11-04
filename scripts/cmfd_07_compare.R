# cmfd_07_compare.R —— CMFD 版本第七步：两版本公平对比（自己 vs CMFD）
# 输入：results/validation_metrics.csv（自己版本）、validation_metrics_cmfd.csv（CMFD）
# 处理：取两版本都有的共同站，按变量比 R²/RMSE/Bias 中位数
# 输出：results/version_comparison.csv

library(dplyr)

PROJ <- "D:/CoLM_ChinaFlux"

self <- read.csv(file.path(PROJ, "results/validation_metrics.csv"), stringsAsFactors = FALSE)
cmfd <- read.csv(file.path(PROJ, "results/validation_metrics_cmfd.csv"), stringsAsFactors = FALSE)

comp <- lapply(c("ET", "H", "Rnet", "GPP", "Resp"), function(v) {
  a <- self %>% filter(variable == v, !is.na(R2))
  b <- cmfd %>% filter(variable == v, !is.na(R2))
  both <- intersect(a$site, b$site)          # 两版本都有 R² 的站
  a <- a %>% filter(site %in% both) %>% arrange(site)
  b <- b %>% filter(site %in% both) %>% arrange(site)
  data.frame(
    variable = v, n = length(both),
    self_R2 = round(median(a$R2), 3),    cmfd_R2 = round(median(b$R2), 3),
    self_RMSE = round(median(a$RMSE), 2), cmfd_RMSE = round(median(b$RMSE), 2),
    self_Bias = round(median(a$Bias), 2), cmfd_Bias = round(median(b$Bias), 2)
  )
})
comp <- do.call(rbind, comp)

write.csv(comp, file.path(PROJ, "results/version_comparison.csv"), row.names = FALSE)
print(comp, row.names = FALSE)
