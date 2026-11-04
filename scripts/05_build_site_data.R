# 05_build_site_data.R —— 第五步：生成 Met.nc + site.nc + case.nml + forcing.nml
# 输入：results/forcing_self.csv、lai_monthly.csv、soil_params.csv、site_params.csv
#       参考 cases/CN-Cng_2008/site.nc（49 变量模板）
# 处理：逐站组装 4 个文件，写入 cases/self_version/<case>/
# 输出：cases/self_version/<case>/{met/<case>_Met.nc, site.nc, case.nml, forcing.nml}

library(ncdf4)
library(dplyr)
library(lubridate)

PROJ     <- "D:/CoLM_ChinaFlux"
REF_SITE <- "D:/Graduate/2026.8/CoLM_Test/cases/CN-Cng_2008/site.nc"

#  1. 读输入
site_params <- read.csv(file.path(PROJ, "results/site_params.csv"), stringsAsFactors = FALSE)
soil_params <- read.csv(file.path(PROJ, "results/soil_params.csv"), stringsAsFactors = FALSE)
lai         <- read.csv(file.path(PROJ, "results/lai_monthly.csv"), stringsAsFactors = FALSE)
forcing     <- data.table::fread(file.path(PROJ, "results/forcing_self.csv"))

#  2. 参考 site.nc 的占位结构
ref <- nc_open(REF_SITE)
site_specific <- c("longitude", "latitude", "reference_height", "canopy_height",
                   "IGBP_classification", "USGS_classification", "pfttyp", "pctpfts",
                   "canopy_height_pfts", "year_qc", "LAI_monthly", "SAI_monthly",
                   "LAI_pfts_monthly", "SAI_pfts_monthly")
ph_vars <- setdiff(names(ref$var), site_specific)
ph_data <- lapply(ph_vars, function(v) ncvar_get(ref, v)); names(ph_data) <- ph_vars
ph_prec <- sapply(ph_vars, function(v) { p <- ref$var[[v]]$prec; if (p == "int") "integer" else p })
ph_soil <- sapply(ph_vars, function(v) any(sapply(ref$var[[v]]$dim, function(d) d$name == "soil")))
nc_close(ref)

#  3. 常数与工具
# ASCII 案例名（中文路径会让 Fortran 打不开文件，故用拼音）
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
  "WSA_灌丛_燕山" = "Yanshan_Shrub"
)
sai0 <- c(2.0, 2.0, 2.0, 2.0, 2.0, 0.5, 0.5, 0.5, 0.5, 0.2, 0.2, 0.2, 0.2, 0.2, 0.0, 0.0, 0.0)  # IGBP 0..16
parse_nums <- function(s) { if (is.na(s) || !nzchar(s)) return(NA_real_); as.numeric(strsplit(gsub(" ", "", s), ",")[[1]]) }
parse_yrs  <- function(s) { if (is.na(s) || !nzchar(s)) return(2020:2021); y <- as.integer(strsplit(s, "-")[[1]]); seq(y[1], y[2]) }

#  4. 写 Met.nc 
write_met <- function(met_path, fc, years, ref_h, lon, lat) {
  t0 <- as.POSIXct(paste0(years[1], "-01-01 00:00:00"), tz = "UTC")
  tsec <- as.numeric(difftime(fc$time, t0, units = "secs"))
  tsec <- c(tsec, tail(tsec, 1) + 3600)          # 末尾哨兵步
  add_tail <- function(v) c(v, tail(v, 1))

  dimx <- ncdim_def("x", "", 1L); dimy <- ncdim_def("y", "", 1L)
  dimt <- ncdim_def("time", paste0("seconds since ", years[1], "-01-01 00:00:00"),
                    tsec, unlim = FALSE, create_dimvar = TRUE)
  vlist <- list(
    ncvar_def("Tair", "K", list(dimx, dimy, dimt), -9999, prec = "float"),
    ncvar_def("SWdown", "W/m2", list(dimx, dimy, dimt), -9999, prec = "float"),
    ncvar_def("LWdown", "W/m2", list(dimx, dimy, dimt), -9999, prec = "float"),
    ncvar_def("Qair", "kg/kg", list(dimx, dimy, dimt), -9999, prec = "float"),
    ncvar_def("Psurf", "Pa", list(dimx, dimy, dimt), -9999, prec = "float"),
    ncvar_def("Precip", "kg/m2/s", list(dimx, dimy, dimt), -9999, prec = "float"),
    ncvar_def("Wind", "m/s", list(dimx, dimy, dimt), -9999, prec = "float"),
    ncvar_def("latitude", "degrees_north", list(dimx, dimy), -9999, prec = "float"),
    ncvar_def("longitude", "degrees_east", list(dimx, dimy), -9999, prec = "float"),
    ncvar_def("reference_height_v", "m", list(), NA, prec = "float"),
    ncvar_def("reference_height_t", "m", list(), NA, prec = "float"),
    ncvar_def("reference_height_q", "m", list(), NA, prec = "float")
  )
  nc <- nc_create(met_path, vlist, force_v4 = FALSE)
  for (v in c("Tair", "SWdown", "LWdown", "Qair", "Psurf", "Precip", "Wind"))
    ncvar_put(nc, v, add_tail(fc[[v]]))
  ncvar_put(nc, "latitude", lat); ncvar_put(nc, "longitude", lon)
  ncvar_put(nc, "reference_height_v", ref_h)
  ncvar_put(nc, "reference_height_t", ref_h)
  ncvar_put(nc, "reference_height_q", ref_h)
  nc_close(nc)
}

#  5. 写 site.nc（49 变量，10 层土壤）
write_site <- function(site_path, sp, years, soil_site, lai_site) {
  ny <- length(years)
  dim_year <- ncdim_def("year", "years", 1997:2022, create_dimvar = TRUE)
  dim_laiy <- ncdim_def("LAI_year", "", years, create_dimvar = TRUE)
  dim_mon  <- ncdim_def("month", "", 1:12, create_dimvar = FALSE)
  dim_pft  <- ncdim_def("pft", "", 1:2, create_dimvar = FALSE)
  dim_soil <- ncdim_def("soil", "", 1:10, create_dimvar = FALSE)

  igbp <- as.integer(sp$IGBP)
  pfttyp  <- parse_nums(sp$pfttyp); pctpfts <- parse_nums(sp$pctpfts); ch_pfts <- parse_nums(sp$canopy_height_pfts)
  if (length(pfttyp) < 2) { pfttyp <- c(pfttyp, 0L); pctpfts <- c(pctpfts, 0); ch_pfts <- c(ch_pfts, 0) }

  sai <- rep(sai0[igbp + 1], 12)
  LAI_m <- matrix(as.numeric(t(lai_site[, paste0("m", 1:12)])), nrow = 12, ncol = ny)
  SAI_m <- matrix(rep(sai, ny), nrow = 12, ncol = ny)
  LAI_p <- array(0, dim = c(2, 12, ny)); SAI_p <- array(0, dim = c(2, 12, ny))
  for (k in seq_len(ny)) for (p in 1:2) if (pfttyp[p] != 0) {
    LAI_p[p, , k] <- LAI_m[, k]; SAI_p[p, , k] <- SAI_m[, k]
  }
  year_qc <- rep(0L, length(1997:2022)); year_qc[1997:2022 %in% years] <- 1L

  vars <- list(
    ncvar_def("longitude", "degrees_east", list(), NA, prec = "float"),
    ncvar_def("latitude", "degrees_north", list(), NA, prec = "float"),
    ncvar_def("reference_height", "m", list(), NA, prec = "float"),
    ncvar_def("canopy_height", "m", list(), NA, prec = "float"),
    ncvar_def("IGBP_classification", "", list(), NULL, prec = "integer"),
    ncvar_def("USGS_classification", "", list(), NULL, prec = "integer"),
    ncvar_def("pfttyp", "", list(dim_pft), NULL, prec = "integer"),
    ncvar_def("pctpfts", "", list(dim_pft), NA, prec = "float"),
    ncvar_def("canopy_height_pfts", "m", list(dim_pft), NA, prec = "float"),
    ncvar_def("year_qc", "", list(dim_year), NULL, prec = "integer"),
    ncvar_def("LAI_monthly", "m2/m2", list(dim_mon, dim_laiy), NA, prec = "float"),
    ncvar_def("SAI_monthly", "m2/m2", list(dim_mon, dim_laiy), NA, prec = "float"),
    ncvar_def("LAI_pfts_monthly", "m2/m2", list(dim_pft, dim_mon, dim_laiy), NA, prec = "float"),
    ncvar_def("SAI_pfts_monthly", "m2/m2", list(dim_pft, dim_mon, dim_laiy), NA, prec = "float")
  )
  for (v in ph_vars) {
    dims <- if (ph_soil[[v]]) list(dim_soil) else list()
    mv <- if (ph_prec[[v]] == "integer") NULL else NA
    vars[[length(vars) + 1]] <- ncvar_def(v, "", dims, mv, prec = ph_prec[[v]])
  }

  nc <- nc_create(site_path, vars, force_v4 = FALSE)
  ncvar_put(nc, "longitude", sp$lon); ncvar_put(nc, "latitude", sp$lat)
  ncvar_put(nc, "reference_height", sp$reference_height)
  ncvar_put(nc, "canopy_height", sp$canopy_height)
  ncvar_put(nc, "IGBP_classification", igbp)
  ncvar_put(nc, "USGS_classification", sp$USGS)
  ncvar_put(nc, "pfttyp", pfttyp); ncvar_put(nc, "pctpfts", pctpfts)
  ncvar_put(nc, "canopy_height_pfts", ch_pfts)
  ncvar_put(nc, "year_qc", year_qc)
  ncvar_put(nc, "LAI_monthly", LAI_m); ncvar_put(nc, "SAI_monthly", SAI_m)
  ncvar_put(nc, "LAI_pfts_monthly", LAI_p); ncvar_put(nc, "SAI_pfts_monthly", SAI_p)

  for (v in ph_vars) {
    val <- if (v %in% names(soil_site)) {
      soil_site[[v]]
    } else if (v == "elevation") {
      sp$elevation_m
    } else if (v == "sloperatio") {
      sp$sloperatio
    } else if (v == "soil_s_v_alb") {
      sp$soil_s_v_alb
    } else if (v == "soil_d_v_alb") {
      sp$soil_d_v_alb
    } else if (v == "soil_s_n_alb") {
      sp$soil_s_n_alb
    } else if (v == "soil_d_n_alb") {
      sp$soil_d_n_alb
    } else if (v == "soil_texture") {
      sp$soil_texture
    } else {
      ph_data[[v]]              # lakedepth/elvstd 等占位
    }
    ncvar_put(nc, v, val)
  }
  nc_close(nc)
}

#  6. 写 namelist
write_nml <- function(case_dir, case_name, met_dir, site_path, sp, years) {
  case_nml <- sprintf('&nl_colm

   DEF_CASE_NAME = \'%s\'
   SITE_fsitedata = \'%s\'
   SITE_lon_location = %s
   SITE_lat_location = %s
   SITE_landtype = %d
   USE_SITE_landtype = .true.
   DEF_simulation_time%%greenwich = .false.
   DEF_simulation_time%%start_year = %d
   DEF_simulation_time%%end_year = %d
   DEF_simulation_time%%end_month = 12
   DEF_simulation_time%%end_day = 31
   DEF_simulation_time%%end_sec = 86400
   DEF_simulation_time%%spinup_repeat = 0
   DEF_dir_rawdata = \'%s\'
   DEF_dir_runtime = \'%s\'
   DEF_dir_output = \'%s\'
   DEF_forcing_namelist = \'%s\'
   DEF_USE_OZONEDATA = .false.
   DEF_WRST_FREQ = \'MONTHLY\'
   DEF_HIST_FREQ = \'HOURLY\'
/
', case_name, site_path, sp$lon, sp$lat, as.integer(sp$IGBP), years[1], years[length(years)],
   paste0(case_dir, "/rawdata_unused/"), paste0(case_dir, "/runtime_unused/"),
   paste0(case_dir, "/out/"), paste0(case_dir, "/forcing.nml"))

  forcing_nml <- sprintf('&nl_colm_forcing

   DEF_dir_forcing              = \'%s\'

   DEF_forcing%%dataset          = \'POINT\'
   DEF_forcing%%solarin_all_band = .true.

   DEF_forcing%%HEIGHT_V         = %s
   DEF_forcing%%HEIGHT_T         = %s
   DEF_forcing%%HEIGHT_Q         = %s

   DEF_forcing%%NVAR             = 8
   DEF_forcing%%startyr          = %d
   DEF_forcing%%startmo          = 1
   DEF_forcing%%endyr            = %d
   DEF_forcing%%endmo            = 1

   DEF_forcing%%fprefix(1)       = \'%s\'

   DEF_forcing%%vname            = \'Tair\' \'Qair\' \'Psurf\' \'Precip\' \'NULL\' \'Wind\' \'SWdown\' \'LWdown\'
   DEF_forcing%%tintalgo         = \'linear\' \'linear\' \'linear\' \'nearest\' \'NULL\' \'linear\' \'linear\' \'linear\'
/
', paste0(met_dir, "/"), sp$reference_height, sp$reference_height, sp$reference_height,
   years[1], years[length(years)] + 1L, paste0(case_name, "_Met.nc"))

  writeLines(case_nml, file.path(case_dir, "case.nml"))
  writeLines(forcing_nml, file.path(case_dir, "forcing.nml"))
}

#  7. 逐站组装
base <- file.path(PROJ, "cases/self_version")
dir.create(base, showWarnings = FALSE, recursive = TRUE)

report <- lapply(seq_len(nrow(site_params)), function(i) {
  sp <- site_params[i, ]
  years <- parse_yrs(sp$years)
  case_id <- case_id_map[[sp$site]]
  case_name <- paste0(case_id, "_", years[1], "-", years[length(years)])
  case_dir <- file.path(base, case_name)
  met_dir <- file.path(case_dir, "met")
  dir.create(met_dir, showWarnings = FALSE, recursive = TRUE)

  # 强迫子集 + 缺口
  fc <- forcing[site == sp$site & data.table::year(time) %in% years]
  fc <- fc[order(time)]
  gaps <- sum(as.numeric(diff(fc$time), units = "hours") > 1.5)

  # LAI、土壤
  lai_site <- lai %>% filter(site == sp$site, year %in% years) %>% arrange(year)
  soil_site <- soil_params %>% filter(site == sp$site)
  soil_list <- as.list(soil_site[, setdiff(names(soil_site), c("site", "layer"))])
  soil_list <- lapply(soil_list, function(x) x[order(soil_site$layer)])

  write_met(file.path(met_dir, paste0(case_name, "_Met.nc")), fc, years,
            sp$reference_height, sp$lon, sp$lat)
  write_site(file.path(case_dir, "site.nc"), sp, years, soil_list, lai_site)
  write_nml(case_dir, case_name, met_dir, file.path(case_dir, "site.nc"), sp, years)

  data.frame(site = sp$site, status = "ok", years = length(years), n_forcing = nrow(fc), gaps = gaps)
})

out <- do.call(rbind, report)
print(out, row.names = FALSE)
cat("\n共", sum(out$status == "ok"), "/", nrow(out), "站生成成功；有缺口的站：",
    sum(out$gaps > 0), "个\n")
