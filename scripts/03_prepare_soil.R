# 03_prepare_soil.R —— 第三步：土壤参数表（soil5 17+7 → site.nc 26 变量 × 10 层）
# 输入：data-raw/soil/ChinaFlux_soil5_final/ChinaFlux_soil5_17params_raw.csv（17 原始，8 层）
#       data-raw/soil/ChinaFlux_soil5_final/ChinaFlux_soil5_derived_parameters.csv（7 派生，8 层）
#       results/forcing_self.csv（31 站名单）
# 处理：log→线性（k_s=10^log_k_s、n_vgm=10^log_VGM_n）；补 L_vgm=0.5、BA_alpha/beta 占位；
#       8→10 层映射（第 9、10 层 = 第 8 层）
# 输出：results/soil_params.csv（site, layer, 26 个土壤变量）

library(dplyr)

PROJ <- "D:/CoLM_ChinaFlux"

# 1. 37 站名单 + 站点名映射（sp31 名 → 元数据表名）
name_map <- c("WSA_灌丛_燕山" = "MF_乔灌混交林_燕山")
sp31 <- unique(data.table::fread(file.path(PROJ, "results/forcing_self.csv"), select = "site")$site)
# 补 6 个跳过站（CMFD 版本要跑，名字与元数据一致，无需映射）
sp31 <- c(sp31, c("CRO_冬小麦夏玉米_栾城", "GRA_粮草复合_庆阳", "WET_滨海盐沼_崇明东滩",
                  "WET_芦苇湿地_盘锦", "WET_南荻_洞庭湖", "WSA_退耕乔灌草_普定"))

# 2. 读 soil5 两文件
p17 <- read.csv(file.path(PROJ, "data-raw/soil/ChinaFlux_soil5_final/ChinaFlux_soil5_17params_raw.csv"),
                stringsAsFactors = FALSE)
drv <- read.csv(file.path(PROJ, "data-raw/soil/ChinaFlux_soil5_final/ChinaFlux_soil5_derived_parameters.csv"),
                stringsAsFactors = FALSE)

# 3. 占位参数：L_vgm 官方常数 0.5；BA_alpha/beta 参考 CN-Cng（CoLM 热导率参数）
soil_BA_alpha <- c(0.2, 0.2, 0.2, 0.2, 0.24, 0.2, 0.24, 0.38, 0.2, 0.2)
soil_BA_beta  <- c(10, 10, 10, 10, 26, 10, 26, 35, 10, 10)

# 4. 取某站某参数的 8 层值；8 → 10 层（第 9、10 层 = 第 8 层）
get8 <- function(meta_name, par) {
  r <- p17 %>% filter(site == meta_name, parameter == par)
  as.numeric(r[1, paste0("layer", 1:8)])
}
to10 <- function(v8) c(v8, v8[8], v8[8])

# 5. 单站：构建 10 层 × 26 变量土壤剖面
build_site_soil <- function(sp31_name) {
  meta_name <- if (sp31_name %in% names(name_map)) name_map[[sp31_name]] else sp31_name

  d <- drv %>% filter(site == meta_name) %>% arrange(layer)

  data.frame(
    site = sp31_name,
    layer = 1:10,
    # 体积分数（soil5 原始，无量纲）
    soil_vf_gravels        = to10(get8(meta_name, "vf_gravels")),
    soil_vf_quartz_mineral = to10(get8(meta_name, "vf_quartz")),
    soil_vf_om             = to10(get8(meta_name, "vf_om")),
    soil_vf_sand           = to10(get8(meta_name, "vf_sand")),
    soil_vf_clay           = to10(get8(meta_name, "vf_clay")),
    # 质量分数（7 派生参数）
    soil_wf_gravels        = to10(d$soil_wf_gravels),
    soil_wf_sand           = to10(d$soil_wf_sand),
    soil_wf_clay           = to10(d$soil_wf_clay),
    soil_wf_om             = to10(d$soil_wf_om),
    # 水分特征（Campbell + van Genuchten）
    soil_theta_s           = to10(get8(meta_name, "theta_s")),
    soil_psi_s             = to10(get8(meta_name, "psi_s")),
    soil_lambda            = to10(get8(meta_name, "lambda")),
    soil_theta_r           = to10(get8(meta_name, "VGM_theta_r")),
    soil_alpha_vgm         = to10(get8(meta_name, "VGM_alpha")),
    soil_n_vgm             = to10(10^get8(meta_name, "log_VGM_n")),
    soil_L_vgm             = rep(0.5, 10),
    soil_k_s               = to10(10^get8(meta_name, "log_k_s")),   # cm/day
    # 热参数
    soil_csol              = to10(get8(meta_name, "csol")),
    soil_tksatu            = to10(get8(meta_name, "tksatu")),
    soil_tksatf            = to10(get8(meta_name, "tksatf")),
    soil_tkdry             = to10(get8(meta_name, "tkdry")),
    soil_k_solids          = to10(d$soil_k_solids),
    soil_BD_all            = to10(d$soil_BD_all),
    soil_OM_density        = to10(d$soil_OM_density),
    # 热导率 Balland-Arp 参数（占位）
    soil_BA_alpha          = soil_BA_alpha,
    soil_BA_beta           = soil_BA_beta
  )
}

# 6. 逐站构建 → 合并
soil_params <- do.call(rbind, lapply(sp31, build_site_soil))

write.csv(soil_params, file.path(PROJ, "results/soil_params.csv"), row.names = FALSE)
cat("已生成 results/soil_params.csv，共", nrow(soil_params), "行（站×层），",
    length(unique(soil_params$site)), "个站，", ncol(soil_params) - 2, "个土壤变量\n")
