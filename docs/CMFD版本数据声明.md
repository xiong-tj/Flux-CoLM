# CMFD 版本 · 数据声明

> 本文档声明「CMFD 版本」（全 CMFD 强迫，37 站）每一项数据的来源、性质与处理口径。
> 计算方法详见 `docs/数据来源与计算方法.md`。

---

## 1. 强迫数据（唯一与自己版本不同之处）

| 项 | 说明 |
|---|---|
| 文件 | `data-raw/forcing/cmfd/ChinaFlux_sp38_final_forcing_1h.csv` |
| 数据集 | **CMFD V2**（中国区域高分辨率气象强迫再分析，清华大学阳坤团队） |
| 性质 | **0.1° 格点再分析，非站点实测**；3 小时原生，已插值到逐时 |
| 时间 | 世界时 UTC，统一 **+8 小时**转北京钟面 |
| 时段 | 2000–2024 逐时 |
| 变量 | Temp、RHum、Wind、SRad、LRad、Prec、Pres（7 个，齐全无缺测） |

**换算**（与「自己版本」同口径）：
- Tair = Temp + 273.15（K）
- Qair = 由 RHum + Pres 反算比湿（饱和水汽压公式）
- Psurf = Pres（Pa，原样）
- Precip = Prec ÷ 3600（mm/h → kg/m²/s）
- Wind、SWdown、LWdown = 原样

## 2. 站点范围

- **37 个物理站** = 自己版本的 31 站 + 补跑 6 站（栾城、庆阳、崇明东滩、盘锦芦苇、洞庭湖、普定）。
- 各站模拟年份 = 站点清单（MetaInfo）观测年份。

## 3. 其余数据（与自己版本完全一致）

| 项 | 来源 | 性质 |
|---|---|---|
| LAI | GLASS V6.1 | 卫星反演（8 天合成 → 月均） |
| 土壤 | SoilGrids（soil5，8 层） | 模型预测栅格（全球土壤库） |
| IGBP | 站点名推断 | 推断 |
| PFT | IGBP→PFT 映射（Lawrence&Chase2007/CLM4.5） | 查表映射 |
| 海拔/坡度 | SRTM DEM | 遥感提取 |
| 土壤反照率 | CoLM ISC 查表 | 查表 |
| 冠层高/塔高 | ChinaFlux 元数据 | 实测（少数缺省补默认值） |
| SAI | sai0_igbp 官方常数 | 官方常数 |

## 4. 两处特别处理（需知晓）

1. **燕山去重**：CMFD 里 `MF_乔灌混交林_燕山` 与 `WSA_灌丛_燕山` 是**同一个站的两个名字**（逐时刻数据完全一致），去重后保留 `WSA_灌丛_燕山`（与自己版本命名一致）。所以 CMFD 名义 38 站，实际 **37 个物理站**。
2. **崇明东滩土壤无数据**：SoilGrids 在崇明东滩格点无有效土壤（全 -1e36），已用参考站（CN-Cng 草地）土壤**占位**，该站模拟结果仅供参考。

## 5. 模拟配置

- kernel：`default`（SinglePoint, LULC_IGBP, CaMaOFF, CROPOFF，无 BGC/CROP）
- `spinup_repeat = 0`（**不预热**，与自己版本一致，首年含土壤水瞬变）
- 逐时 3600 s + 末尾哨兵步；history 逐时输出

## 6. 验证口径

- 观测： ChinaFlux FluxSM 日尺度（39 站中取对应站）。
- 单位：能量通量 W/m²、碳通量 gC/m²/d、ET mm/d。
- 指标：R² / RMSE / MAE / Bias / N（不跳首年）。
- 对比：两版本取共同 31 站公平比较，见 `results/version_comparison.csv`。

## 7. 结论（CMFD vs 自己版本）

CMFD 版本在 ET/H/GPP/Resp 四项略优，仅在 Rnet 略差（净辐射对强迫源辐射项更敏感）。整体看，CMFD 再分析强迫不劣于、多数变量略好于「sp31 实测 + CMFD 补缺」的自己版本。
