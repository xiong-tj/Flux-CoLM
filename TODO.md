# TODO

## 站点清单对齐（老师 ChinaFlux2026.R 标准：38 站）

- [ ] **燕山拆分**：跑了 `ENF_人工针叶林_燕山` + `WSA_灌丛_燕山` 两个。需确认 ENF_燕山 是否剔除。

## 数据问题

- [ ] **崇明东滩土壤**：SoilGrids 无数据（全 -1e36），现用 CN-Cng 参考站土壤占位。方案待定。
- [ ] **变量单位核对**：逐站用 `data/Unit/ChinaFlux_Variable_Info_*.json` 核对单位换算（W/m²、µmol/m²/s、mm 等）。

## 收尾

- [ ] **大数据上传阿里网盘**（`data-raw/`、`results/`、`cases/`、`model/`），README 补链接。
- [ ] **git 仓库初始化**并提交（代码 + 小数据 + 文档 + 图）。
- [ ] **长岭 Rs 异常**：老师 sp31 里长岭太阳辐射偏低（7 月 40 W/m²），单独标注或换 CMFD 辐射。
