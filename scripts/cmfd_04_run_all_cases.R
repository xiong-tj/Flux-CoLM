# cmfd_04_run_all_cases.R —— CMFD 版本第四步：批量运行 37 站 CoLM
# 输入：cases/cmfd_version/<case>/（37 个已生成站点）
# 处理：逐站调用 colm-cli run（已完成阶段自动跳过，可断点续跑）
# 输出：results/run_summary_cmfd.csv

cases  <- sort(list.dirs("cases/cmfd_version", recursive = FALSE, full.names = TRUE))
cli    <- normalizePath("model/CoLM-Desktop/CoLM/colm-cli.exe")
kernel <- normalizePath("model/CoLM-Desktop/CoLM/kernels/default")

cat("共", length(cases), "站，预计总时长约 8~9 小时\n\n")

results <- list()
for (i in seq_along(cases)) {
  cd   <- cases[i]
  site <- basename(cd)
  cat(sprintf("[%02d/%02d] %-26s ... ", i, length(cases), site))
  t0   <- Sys.time()
  code <- system2(cli, c("run", cd, "--kernel", kernel))
  mins <- round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)
  ok   <- code == 0
  cat(sprintf("%s  %.1f 分钟\n", ifelse(ok, "OK", "FAILED"), mins))
  results[[i]] <- data.frame(site = site, status = ifelse(ok, "ok", "failed"),
                             minutes = mins, stringsAsFactors = FALSE)
}

out <- do.call(rbind, results)
write.csv(out, "results/run_summary_cmfd.csv", row.names = FALSE)
cat("\n===== 汇总 =====\n")
print(out, row.names = FALSE)
cat("\n成功", sum(out$status == "ok"), "/", nrow(out), "站\n")
