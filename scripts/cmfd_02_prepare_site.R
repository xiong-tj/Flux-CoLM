# cmfd_02_prepare_site.R —— CMFD 版本第二步：37 站站点参数
# 输入：results/site_params.csv（31 站 + 年份）、results/forcing_cmfd.csv（37 站名单）
#       data-raw/soil/.../ 映射表 + data/Metadata/ChinaFlux_Metadata.csv
# 处理：与 04 同逻辑，扩展到 37 站（补 6 个跳过站，年份用站点清单）
# 输出：results/site_params_cmfd.csv

library(dplyr)

PROJ <- "D:/CoLM_ChinaFlux"
D <- file.path(PROJ, "data-raw/soil/ChinaFlux_soil5_final")

# 1. 37 站名单 + 年份：31 站用 site_params，6 个跳过站用站点清单年份
sp31 <- read.csv(file.path(PROJ, "results/site_params.csv"), stringsAsFactors = FALSE)
extra_years <- c(
  "CRO_冬小麦夏玉米_栾城" = "2007-2018",
  "GRA_粮草复合_庆阳"     = "2019-2021",
  "WET_滨海盐沼_崇明东滩" = "2004-2010",
  "WET_芦苇湿地_盘锦"     = "2018-2020",
  "WET_南荻_洞庭湖"       = "2014-2016",
  "WSA_退耕乔灌草_普定"   = "2015-2019"
)
sites37 <- rbind(
  sp31[, c("site", "years")],
  data.frame(site = names(extra_years), years = unname(extra_years), stringsAsFactors = FALSE)
)

# 2. 名称映射（sp31 名 → 元数据表名；6 个跳过站名与元数据一致，无需映射）
name_map <- c("WSA_灌丛_燕山" = "MF_乔灌混交林_燕山")

# 3. 读映射表
igbp <- read.csv(file.path(D, "ChinaFlux_37sites_igbp_mapping.csv"), stringsAsFactors = FALSE)
pft  <- read.csv(file.path(D, "ChinaFlux_37sites_PFT_mapping.csv"),   stringsAsFactors = FALSE)
elev <- read.csv(file.path(D, "ChinaFlux_37sites_elevation_slope.csv"), stringsAsFactors = FALSE)
alb  <- read.csv(file.path(D, "ChinaFlux_37sites_soil_albedo.csv"),  stringsAsFactors = FALSE)
meta <- read.csv(file.path(PROJ, "data/Metadata/ChinaFlux_Metadata.csv"), stringsAsFactors = FALSE)

# 4. IGBP→USGS、SoilType→USDA、解析逗号串、冠层高（同 04）
igbp_to_usgs <- c("1"=14,"2"=13,"3"=12,"4"=11,"5"=15,"6"=8,"7"=9,
                  "8"=10,"9"=10,"10"=7,"11"=17,"12"=2,"13"=1,"14"=5,"16"=19)
usda_code <- c(sand=1, loamy_sand=2, sandy_loam=3, silt_loam=4, silty_loam=4,
               silt=5, loam=6, sandy_clay_loam=7, silty_clay_loam=8, clay_loam=9,
               sandy_clay=10, silty_clay=11, clay=12)
parse_nums <- function(s) {
  if (is.na(s) || !nzchar(s)) return(NA_real_)
  as.numeric(strsplit(gsub(" ", "", s), ",")[[1]])
}
canopy_height <- function(z_overstory, ch_pfts_str, pct_str) {
  if (!is.na(z_overstory) && z_overstory != "") return(as.numeric(z_overstory))
  ch <- parse_nums(ch_pfts_str); pct <- parse_nums(pct_str)
  if (any(is.na(ch))) return(0.5)
  weighted.mean(ch[ch > 0], pct[ch > 0])
}

# 5. 逐站合并
site_params <- lapply(seq_len(nrow(sites37)), function(i) {
  sn <- sites37$site[i]
  mn <- if (sn %in% names(name_map)) name_map[[sn]] else sn
  r_igbp <- igbp[igbp$site == mn, ]; r_pft <- pft[pft$site == mn, ]
  r_elev <- elev[elev$site == mn, ]; r_alb <- alb[alb$site == mn, ]
  r_meta <- meta[meta$site == mn, ]
  if (nrow(r_igbp) == 0 || nrow(r_meta) == 0) {
    return(data.frame(site = sn, years = sites37$years[i], 缺失 = "元数据无此站"))
  }

  igbp_code <- as.integer(r_igbp$IGBP)
  ref_h <- as.numeric(r_igbp$z_Uz)
  if (is.na(ref_h)) ref_h <- 2.0

  data.frame(
    site = sn,
    lon = r_igbp$lon, lat = r_igbp$lat,
    years = sites37$years[i],
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

write.csv(site_params, file.path(PROJ, "results/site_params_cmfd.csv"), row.names = FALSE)
cat("已生成 results/site_params_cmfd.csv，共", nrow(site_params), "行（站），",
    ncol(site_params), "列\n")
