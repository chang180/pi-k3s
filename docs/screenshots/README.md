# 截圖與 GIF

部署完成後，請在此目錄放入以下截圖：

## 必要截圖

1. **dashboard-overview.png** — 三合一儀表板全景：控制面板 + Monte Carlo Canvas + 即時結果 + π 收斂圖 + K8s 狀態 + 效能對比
2. **kubectl-hpa.png** — `kubectl get hpa -n pi-k3s` 顯示 HPA 擴展狀態

## 可選 GIF

3. **autoscale-demo.gif** — 完整自動擴展過程（1 pod → 2 pods → 1 pod）
4. **monte-carlo-animation.gif** — 蒙地卡羅投點動畫（distributed mode 即時更新）

## 截圖方式建議

- 瀏覽器截圖：使用 Chrome DevTools → Capture full size screenshot
- kubectl 截圖：使用 `script` 或 `asciinema` 錄製終端
- GIF 錄製：使用 [LICEcap](https://www.cockos.com/licecap/) 或 [Peek](https://github.com/phw/peek)
