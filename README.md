# ChinaFlux CoLM 单点模拟与验证

基于 CoLM（Common Land Model）单点模式，对 ChinaFlux 通量站做「强迫准备 → 站点数据生成 → 批量模拟 → 通量提取 → 与观测验证」的完整流水线，为碳水通量模型验证提供数据支撑。

## 目录结构

```
.
├── scripts/          # 流水线脚本（自己版本 01~11 + CMFD 版本 cmfd_01~08）
├── R/                # 公共函数
├── data/             # 小数据，入 git（站点清单、元数据、变量单位表）
├── data-raw/         # 原始大数据，进阿里网盘（强迫、GLASS、soil5、观测）
├── results/          # 中间结果，进网盘（强迫表、提取通量、精度表）
├── cases/            # 案例与模型输出，进网盘（self_version、cmfd_version）
├── Figures/          # 图（散点、时间序列），入 git
├── docs/             # 文档（数据来源与计算方法、CMFD 数据声明、报告）
└── model/            # CoLM 程序（colm-cli、kernel），进网盘
```

## 两个版本

| 版本 | 强迫源 | 站点数 | 案例目录 |
|---|---|---|---|
| 自己版本 | sp31 实测 + CMFD 补缺 | 31 站 | `cases/self_version/` |
| CMFD 版本 | 全 CMFD 再分析（sp38） | 37 站 | `cases/cmfd_version/` |

两个版本均：`spinup_repeat=0`、逐时 3600s + 哨兵步、kernel `default`（LULC_IGBP，无 BGC/CROP）。

## 数据流向

```
data-raw/forcing(sp31,CMFD) ─┐
data-raw/lai(GLASS) ─────────┤
data-raw/soil(soil5) ────────┤→ scripts/01~06 → cases/<版本>/ → scripts/07 批量跑
data-raw/obs(FluxSM) ────────┘                                    ↓
                                                          scripts/08 提取通量
                                                                   ↓
                                              scripts/09 与 FluxSM 算精度
                                                                   ↓
                                              scripts/10 绘图、11 报告
```

CMFD 版本同流程，脚本前缀 `cmfd_`，末尾加 `cmfd_07` 两版本对比。

## 复现步骤

```r
# 自己版本（31 站）
source("scripts/01_prepare_forcing.R")   # 强迫
source("scripts/02_prepare_lai.R")       # LAI
source("scripts/03_prepare_soil.R")      # 土壤
source("scripts/04_prepare_site.R")      # 站点参数
source("scripts/05_build_site_data.R")   # 生成 Met.nc/site.nc/namelist
source("scripts/06_fill_gaps.R")         # 补时间缺口
source("scripts/07_run_all_cases.R")     # 批量跑 31 站
source("scripts/08_extract_flux.R")      # 提取通量
source("scripts/09_validate.R")          # 算精度
source("scripts/10_plot.R")              # 绘图
source("scripts/11_report.R")            # 报告

# CMFD 版本（37 站）
source("scripts/cmfd_01_prepare_forcing.R")
source("scripts/cmfd_02_prepare_site.R")
source("scripts/cmfd_03_build_site_data.R")
source("scripts/cmfd_04_run_all_cases.R")
source("scripts/cmfd_05_extract_flux.R")
source("scripts/cmfd_06_validate.R")
source("scripts/cmfd_07_compare.R")
source("scripts/cmfd_08_plot.R")
```

> 运行模型用 `scripts/07` 或 `cmfd_04`，会逐站调用 `model/CoLM-Desktop/CoLM/colm-cli.exe`，
> 约 2.5 分钟/站·年，可断点续跑（已完成阶段自动跳过）。

## 数据存储

- **代码 + 小数据 + 文档 + 图**：本仓库（GitHub）
- **大数据**：阿里网盘（`data-raw/`、`results/`、`cases/`、`model/`），链接见 TODO/网盘
  - 强迫：sp31（`Forcing_Hourly_Met_sp31_v20260629_MergeCFMD.csv`）、CMFD（`ChinaFlux_sp38_final_forcing_1h.csv`）
  - LAI：GLASS V6.1（`LAI_MODIS_GLASS_G005D_<year>_v20260608.nc`）
  - 土壤：SoilGrids soil5
  - 观测：老师 ChinaFlux FluxSM（`ChinaFlux_FluxSM_39sp_v20260330.rda`）

## 核心文档

- `docs/数据来源与计算方法.md` —— 每个数据从哪来、怎么算、单位口径
- `docs/CMFD版本数据声明.md` —— CMFD 版本数据声明
- `docs/验证报告.md` —— 自己版本验证报告（指标 + 图 + 注意事项）

## 已知问题

见 `TODO.md`。
