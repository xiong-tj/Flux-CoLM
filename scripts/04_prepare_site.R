# 04_prepare_site.R —— 第四步：站点参数表
# 输入：data-raw/soil/ChinaFlux_soil5_final/ 下的 igbp/PFT/elevation/soil_albedo 映射表
#       data/Metadata/ChinaFlux_Metadata.csv（SoilType、z_Uz、z_overstory）
#       results/forcing_self.csv（31 站名单）
# 处理：合并各映射表；IGBP→USGS、SoilType→soil_texture、冠层高缺省补 PFT 加权；
#       塔高缺省补 2.0（三江源）
# 输出：results/site_params.csv（31 站 × 站点标量参数）

library(dplyr)

PROJ <- "D:/CoLM_ChinaFlux"
D <- file.path(PROJ, "data-raw/soil/ChinaFlux_soil5_final")

# 1. 31 站名单 + 站点名映射（sp31 名 → 元数据表名）
name_map <- c("WSA_灌丛_燕山" = "MF_乔灌混交林_燕山")
sp31 <- unique(data.table::fread(file.path(PROJ, "results/forcing_self.csv"), select = "site")$site)

# 2. 读映射表
igbp <- read.csv(file.path(D, "ChinaFlux_37sites_igbp_mapping.csv"), stringsAsFactors = FALSE)
pft  <- read.csv(file.path(D, "ChinaFlux_37sites_PFT_mapping.csv"),   stringsAsFactors = FALSE)
elev <- read.csv(file.path(D, "ChinaFlux_37sites_elevation_slope.csv"), stringsAsFactors = FALSE)
alb  <- read.csv(file.path(D, "ChinaFlux_37sites_soil_albedo.csv"),  stringsAsFactors = FALSE)
meta <- read.csv(file.path(PROJ, "data/Metadata/ChinaFlux_Metadata.csv"), stringsAsFactors = FALSE)

# 3. IGBP→USGS、SoilType→USDA 质地代码
igbp_to_usgs <- c("1"=14,"2"=13,"3"=12,"4"=11,"5"=15,"6"=8,"7"=9,
                  "8"=10,"9"=10,"10"=7,"11"=17,"12"=2,"13"=1,"14"=5,"16"=19)
usda_code <- c(sand=1, loamy_sand=2, sandy_loam=3, silt_loam=4, silty_loam=4,
               silt=5, loam=6, sandy_clay_loam=7, silty_clay_loam=8, clay_loam=9,
               sandy_clay=10, silty_clay=11, clay=12)

# 4. 解析 "13,14" → c(13,14)
parse_nums <- function(s) {
  if (is.na(s) || !nzchar(s)) return(NA_real_)
  as.numeric(strsplit(gsub(" ", "", s), ",")[[1]])
}

# 5. 冠层高：z_overstory 优先，缺省用 pctpfts 加权的 canopy_height_pfts
canopy_height <- function(z_overstory, ch_pfts_str, pct_str) {
  if (!is.na(z_overstory) && z_overstory != "") return(as.numeric(z_overstory))
  ch <- parse_nums(ch_pfts_str); pct <- parse_nums(pct_str)
  if (any(is.na(ch))) return(0.5)
  weighted.mean(ch[ch > 0], pct[ch > 0])
}

# 6. 逐站合并
site_params <- lapply(sp31, function(sn) {
  mn <- if (sn %in% names(name_map)) name_map[[sn]] else sn
  r_igbp <- igbp[igbp$site == mn, ]; r_pft <- pft[pft$site == mn, ]
  r_elev <- elev[elev$site == mn, ]; r_alb <- alb[alb$site == mn, ]
  r_meta <- meta[meta$site == mn, ]

  igbp_code <- as.integer(r_igbp$IGBP)
  ref_h <- as.numeric(r_igbp$z_Uz)
  if (is.na(ref_h)) ref_h <- 2.0           # 三江源缺塔高，暂用 2.0

  data.frame(
    site = sn,
    lon = r_igbp$lon, lat = r_igbp$lat,
    years = ifelse(is.na(r_igbp$years) | r_igbp$years == "", "2020-2021", r_igbp$years),
    IGBP = igbp_code,
    USGS = as.integer(igbp_to_usgs[as.character(igbp_code)]),
    pfttyp = r_pft$pfttyp, pctpfts = r_pft$pctpfts,
    canopy_height_pfts = r_pft$canopy_height_pfts,
    canopy_height = canopy_height(r_igbp$z_overstory, r_pft$canopy_height_pfts, r_pft$pctpfts),
    reference_height = ref_h,
    elevation_m = r_elev$elevation_m, sloperatio = r_elev$sloperatio,
    soil_s_v_alb = r_alb$soil_s_v_alb, soil_d_v_alb = r_alb$soil_d_v_alb,
    soil_s_n_alb = r_alb$soil_s_n_alb, soil_d_n_alb = r_alb$soil_d_n_alb,
    soil_texture = as.integer(usda_code[r_meta$SoilType]),
    SoilType = r_meta$SoilType,
    note = ifelse(sn %in% names(name_map), "燕山灌丛→MF_乔灌混交林_燕山",
                  ifelse(is.na(as.numeric(r_igbp$z_Uz)), "塔高缺省2.0", ""))
  )
}) %>% bind_rows()

write.csv(site_params, file.path(PROJ, "results/site_params.csv"), row.names = FALSE)
cat("已生成 results/site_params.csv，共", nrow(site_params), "行（站），",
    ncol(site_params), "列\n")
