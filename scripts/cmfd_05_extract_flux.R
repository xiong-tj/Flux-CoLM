# cmfd_05_extract_flux.R —— CMFD 版本第五步：从 history 提取通量并聚合到日尺度
# 输入：cases/cmfd_version/<case>/out/<case>/history/*.nc
# 处理：逐站读 6 个通量变量，逐时 → 逐日（ET 累加、其余取均值）
# 输出：results/sim_daily_cmfd.csv（site, date, ET, H, Rnet, Qg, GPP, Resp）

library(ncdf4)
library(dplyr)

PROJ <- "D:/CoLM_ChinaFlux"

# 1. 案例名映射（ASCII → sp31/元数据中文名，37 站）
case_id_map <- c(
  "CRO_春玉米_锦州" = "Jinzhou", "CRO_冬小麦夏玉米_固城" = "Gucheng",
  "CRO_冬小麦夏玉米_禹城" = "Yucheng", "CRO_水稻_句容" = "Jurong",
  "CRO_水稻_盘锦" = "Panjin", "CRO_水稻_长岭" = "Changling",
  "CRO_制种玉米_临泽" = "Linze", "DBF_栓皮栎人工林_小浪底" = "Xiaolangdi",
  "DBF_天然栎林_宝天曼" = "Baotianman", "EBF_热带雨林_西双版纳" = "Xishuangbanna",
  "EBF_橡胶林_海南儋州" = "Danzhou", "EBF_橡胶林_西双版纳" = "Xishuangbanna_Rubber",
  "EBF_亚热带常绿阔叶林_金佛山" = "Jinfoshan", "ENF_北方林森林_呼中" = "Huzhong",
  "ENF_人工针叶林_千烟洲" = "Qianyanzhou", "ENF_人工针叶林_燕山" = "Yanshan_ENF",
  "GRA_典型草原_多伦" = "Duolun", "GRA_典型草原_锡林浩特" = "Xilinhot",
  "GRA_高寒草甸_当雄" = "Dangxiong", "GRA_高寒草甸_海北" = "Haibei_GRA",
  "GRA_高寒草甸_那曲" = "Naqu", "GRA_高寒草甸_若尔盖" = "Zoige",
  "GRA_人工垂穗披碱草_三江源" = "Sanjiangyuan", "GRA_稀树草原_元江" = "Yuanjiang",
  "GRA_刈割草原_锡林浩特" = "Xilinhot_Mowing", "MF_针阔混交_鼎湖山" = "Dinghushan",
  "MF_针阔混交_长白山" = "Changbaishan", "SAV_荒漠草原_达茂" = "Damao",
  "WET_高寒湿地_海北" = "Haibei_WET", "WSA_高寒灌丛_海北" = "Haibei_WSA",
  "WSA_灌丛_燕山" = "Yanshan_Shrub",
  "CRO_冬小麦夏玉米_栾城" = "Luancheng", "GRA_粮草复合_庆阳" = "Qingyang",
  "WET_滨海盐沼_崇明东滩" = "Chongmingdongtan", "WET_芦苇湿地_盘锦" = "Panjin_WET",
  "WET_南荻_洞庭湖" = "Dongtinghu", "WSA_退耕乔灌草_普定" = "Puding"
)
rev_map <- setNames(names(case_id_map), case_id_map)   # ASCII → 中文

# 2. 要提取的 6 个通量变量
vars <- c("f_fevpa", "f_fsena", "f_rnet", "f_fgrnd", "f_assim", "f_respc")

# 3. 单站：读全部 history → 逐日聚合
extract_case <- function(cd) {
  nm <- basename(cd)
  sp31 <- rev_map[[sub("_[0-9]{4}-[0-9]{4}$", "", nm)]]
  hd <- file.path(cd, "out", nm, "history")
  hf <- list.files(hd, pattern = glob2rx("*.nc"))

  daily <- lapply(hf, function(f) {
    nc <- nc_open(file.path(hd, f))
    t <- nc$dim$time$vals
    d <- data.frame(date = as.Date("1900-01-01") + t %/% 1440)
    for (v in vars) d[[v]] <- if (v %in% names(nc$var)) ncvar_get(nc, v) else NA_real_
    nc_close(nc)
    d
  }) %>%
    bind_rows() %>%
    group_by(date) %>%
    summarise(
      ET   = sum(f_fevpa * 3600, na.rm = TRUE),
      H    = mean(f_fsena, na.rm = TRUE),
      Rnet = mean(f_rnet,  na.rm = TRUE),
      Qg   = mean(f_fgrnd, na.rm = TRUE),
      GPP  = mean(f_assim, na.rm = TRUE) * 1e6,
      Resp = mean(f_respc, na.rm = TRUE) * 1e6,
      .groups = "drop"
    ) %>%
    mutate(site = sp31, .before = 1)
  daily
}

# 4. 逐站提取 → 合并
cases <- sort(list.dirs(file.path(PROJ, "cases/cmfd_version"), recursive = FALSE, full.names = TRUE))
sim <- do.call(rbind, lapply(cases, extract_case))

write.csv(sim, file.path(PROJ, "results/sim_daily_cmfd.csv"), row.names = FALSE)
cat("已生成 results/sim_daily_cmfd.csv，共", nrow(sim), "行（站×日），",
    length(unique(sim$site)), "个站\n")
