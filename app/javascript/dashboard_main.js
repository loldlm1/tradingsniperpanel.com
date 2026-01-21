const TIME_PARSER = "YYYY-MM-DD";

const hexToRGB = (hex) => {
  if (!hex) return "0,0,0";
  const normalized = hex.replace("#", "");
  if (normalized.length === 3) {
    return `${parseInt(normalized[0] + normalized[0], 16)},${parseInt(normalized[1] + normalized[1], 16)},${parseInt(normalized[2] + normalized[2], 16)}`;
  }
  if (normalized.length === 6) {
    return `${parseInt(normalized.slice(0, 2), 16)},${parseInt(normalized.slice(2, 4), 16)},${parseInt(normalized.slice(4, 6), 16)}`;
  }
  return "0,0,0";
};

const withAlpha = (color, alpha) => {
  if (!color) return color;
  if (color.startsWith("rgba")) return color;
  if (color.startsWith("rgb")) {
    return color.replace("rgb(", "rgba(").replace(")", `, ${alpha})`);
  }
  return `rgba(${hexToRGB(color)}, ${alpha})`;
};

const chartAreaGradient = (ctx, chartArea, colorStops) => {
  if (!ctx || !chartArea || !colorStops || colorStops.length === 0) {
    return "transparent";
  }
  const gradient = ctx.createLinearGradient(0, chartArea.bottom, 0, chartArea.top);
  colorStops.forEach(({ stop, color }) => {
    gradient.addColorStop(stop, color);
  });
  return gradient;
};

const gradientFill = (context, color) => {
  const { chart } = context;
  if (!chart || !chart.chartArea) return "transparent";
  return chartAreaGradient(chart.ctx, chart.chartArea, [
    { stop: 0, color: withAlpha(color, 0) },
    { stop: 1, color: withAlpha(color, 0.2) }
  ]);
};

const formatValue = (value, format) => {
  const numeric = Number(value) || 0;
  if (format === "currency") {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(numeric);
  }
  return new Intl.NumberFormat("en-US").format(numeric);
};

const chartColors = (isDark) => ({
  text: isDark ? "#6B7280" : "#9CA3AF",
  grid: isDark ? "rgba(55, 65, 81, 0.6)" : "#F3F4F6",
  tooltipBody: isDark ? "#9CA3AF" : "#6B7280",
  tooltipTitle: isDark ? "#F3F4F6" : "#1F2937",
  tooltipBg: isDark ? "#374151" : "#ffffff",
  tooltipBorder: isDark ? "#4B5563" : "#E5E7EB"
});

const configureChartDefaults = () => {
  if (!window.Chart || window.Chart.__dashboardDefaults) return;

  Chart.defaults.font.family = '"Inter", sans-serif';
  Chart.defaults.font.weight = 500;
  Chart.defaults.plugins.tooltip.borderWidth = 1;
  Chart.defaults.plugins.tooltip.displayColors = false;
  Chart.defaults.plugins.tooltip.mode = "nearest";
  Chart.defaults.plugins.tooltip.intersect = false;
  Chart.defaults.plugins.tooltip.position = "nearest";
  Chart.defaults.plugins.tooltip.caretSize = 0;
  Chart.defaults.plugins.tooltip.caretPadding = 20;
  Chart.defaults.plugins.tooltip.cornerRadius = 8;
  Chart.defaults.plugins.tooltip.padding = 8;
  Chart.__dashboardDefaults = true;
};

const lineTooltip = (format, colors) => ({
  callbacks: {
    title: () => false,
    label: (context) => formatValue(context.parsed.y, format)
  },
  bodyColor: colors.tooltipBody,
  backgroundColor: colors.tooltipBg,
  borderColor: colors.tooltipBorder
});

const pieTooltip = (format, colors) => ({
  titleColor: colors.tooltipTitle,
  callbacks: {
    title: () => false,
    label: (context) => {
      const label = context.label || "";
      const value = formatValue(context.parsed, format);
      return label ? `${label}: ${value}` : value;
    }
  },
  bodyColor: colors.tooltipBody,
  backgroundColor: colors.tooltipBg,
  borderColor: colors.tooltipBorder
});

const timeScale = (tickColor, overrides = {}) => ({
  type: "time",
  time: {
    parser: TIME_PARSER,
    unit: "month",
    displayFormats: {
      month: "MMM YY"
    }
  },
  border: { display: false },
  grid: { display: false },
  ticks: {
    autoSkipPadding: 48,
    maxRotation: 0,
    color: tickColor,
    ...overrides
  }
});

const buildLineOptions = (kind, format, isDark) => {
  const colors = chartColors(isDark);

  if (kind === "main") {
    return {
      layout: { padding: 20 },
      scales: {
        y: {
          beginAtZero: true,
          border: { display: false },
          ticks: {
            maxTicksLimit: 7,
            callback: (value) => formatValue(value, format),
            color: colors.text
          },
          grid: { color: colors.grid }
        },
        x: timeScale(colors.text)
      },
      plugins: {
        legend: { display: false },
        tooltip: lineTooltip(format, colors)
      },
      interaction: { intersect: false, mode: "nearest" },
      maintainAspectRatio: false
    };
  }

  if (kind === "card") {
    return {
      layout: {
        padding: { top: 12, bottom: 16, left: 20, right: 20 }
      },
      scales: {
        y: {
          beginAtZero: true,
          border: { display: false },
          ticks: {
            maxTicksLimit: 7,
            callback: (value) => formatValue(value, format),
            color: colors.text
          },
          grid: { color: colors.grid }
        },
        x: timeScale(colors.text, { align: "end" })
      },
      plugins: {
        legend: { display: false },
        tooltip: lineTooltip(format, colors)
      },
      interaction: { intersect: false, mode: "nearest" },
      maintainAspectRatio: false
    };
  }

  if (kind === "mini") {
    return {
      layout: {
        padding: { top: 16, bottom: 16, left: 20, right: 20 }
      },
      scales: {
        y: {
          beginAtZero: true,
          border: { display: false },
          grid: {
            drawTicks: false,
            color: colors.grid
          },
          ticks: {
            maxTicksLimit: 2,
            display: false
          }
        },
        x: {
          ...timeScale(colors.text),
          display: false
        }
      },
      plugins: {
        legend: { display: false },
        tooltip: lineTooltip(format, colors)
      },
      interaction: { intersect: false, mode: "nearest" },
      maintainAspectRatio: false
    };
  }

  return {
    scales: {
      y: { display: false, beginAtZero: true },
      x: { ...timeScale(colors.text), display: false }
    },
    plugins: {
      legend: { display: false },
      tooltip: lineTooltip(format, colors)
    },
    interaction: { intersect: false, mode: "nearest" },
    maintainAspectRatio: false
  };
};

const buildLineDatasets = (datasets, kind) => {
  return (datasets || []).map((dataset, idx) => {
    const baseColor = dataset.color || "#8470FF";
    const color = kind === "main" && idx >= 2 ? withAlpha(baseColor, 0.25) : baseColor;
    const fill = kind !== "sparkline" && (kind === "mini" || idx === 0);
    const line = {
      label: dataset.label,
      data: dataset.data || [],
      borderColor: color,
      backgroundColor: fill ? (context) => gradientFill(context, baseColor) : "transparent",
      borderWidth: 2,
      pointRadius: 0,
      pointHoverRadius: 3,
      pointBackgroundColor: color,
      pointHoverBackgroundColor: color,
      pointBorderWidth: 0,
      pointHoverBorderWidth: 0,
      clip: 20,
      tension: 0.2,
      fill: fill
    };

    if (kind === "main" && idx === 1) {
      line.borderDash = [4, 4];
    }

    if (kind === "sparkline") {
      line.fill = false;
      line.backgroundColor = "transparent";
    }

    return line;
  });
};

const buildPieDataset = (dataset) => ({
  data: dataset.data || [],
  backgroundColor: dataset.colors || [],
  borderWidth: 0
});

const buildHtmlLegendPlugin = (containerId, usesDataIndex = false) => ({
  id: "htmlLegend",
  afterUpdate(chart) {
    const legendContainer = document.getElementById(containerId);
    if (!legendContainer) return;
    const ul = legendContainer.querySelector("ul");
    if (!ul) return;

    while (ul.firstChild) {
      ul.firstChild.remove();
    }

    const items = chart.options.plugins.legend.labels.generateLabels(chart);
    items.forEach((item) => {
      const li = document.createElement("li");
      if (usesDataIndex) {
        li.style.margin = "6px";
      }

      const button = document.createElement("button");
      button.style.display = "inline-flex";
      button.style.alignItems = "center";
      button.style.opacity = item.hidden ? ".3" : "";
      button.onclick = () => {
        if (usesDataIndex) {
          chart.toggleDataVisibility(item.index);
        } else {
          chart.setDatasetVisibility(item.datasetIndex, !chart.isDatasetVisible(item.datasetIndex));
        }
        chart.update();
      };

      const box = document.createElement("span");
      box.style.display = "block";
      box.style.width = "12px";
      box.style.height = "12px";
      box.style.borderRadius = "9999px";
      box.style.marginRight = usesDataIndex ? "6px" : "8px";
      box.style.borderWidth = "3px";
      box.style.borderColor = usesDataIndex ? item.fillStyle : chart.data.datasets[item.datasetIndex].borderColor;
      box.style.pointerEvents = "none";

      const label = document.createElement("span");
      label.classList.add("text-gray-500", "dark:text-gray-400");
      label.style.fontSize = "0.875rem";
      label.style.lineHeight = "1.5715";
      label.appendChild(document.createTextNode(item.text));

      button.appendChild(box);
      button.appendChild(label);
      li.appendChild(button);
      ul.appendChild(li);
    });
  }
});

const resolveChartKind = (canvas) => {
  const id = canvas.id;
  if (id === "fintech-card-01") return "main";
  if (id === "fintech-card-07" || id === "fintech-card-08") return "card";
  if (id === "fintech-card-09") return "pie";
  if (id === "fintech-card-10" || id === "fintech-card-11" || id === "fintech-card-12" || id === "fintech-card-13") return "mini";
  if (id && id.startsWith("fintech-card-14")) return "sparkline";
  if (canvas.dataset.chartStyle === "sparkline") return "sparkline";
  if (canvas.dataset.chartStyle === "main-line") return "main";
  if (canvas.dataset.chartStyle === "card-line") return "card";
  if (canvas.dataset.chartStyle === "mini-line") return "mini";
  if (canvas.dataset.chartStyle === "pie" || canvas.dataset.chartStyle === "doughnut") return "pie";
  return "card";
};

const updateColorsForLineChart = (chart, kind, format) => {
  const colors = chartColors(localStorage.getItem("dark-mode") === "true");
  const options = chart.options;
  options.plugins.tooltip = lineTooltip(format, colors);

  if (kind === "sparkline") {
    chart.update("none");
    return;
  }

  if (options.scales?.x?.ticks) {
    options.scales.x.ticks.color = colors.text;
  }

  if (options.scales?.y?.ticks) {
    options.scales.y.ticks.color = colors.text;
  }

  if (options.scales?.y?.grid) {
    options.scales.y.grid.color = colors.grid;
  }

  chart.update("none");
};

const updateColorsForPieChart = (chart, format) => {
  const colors = chartColors(localStorage.getItem("dark-mode") === "true");
  chart.options.plugins.tooltip = pieTooltip(format, colors);
  chart.update("none");
};

const parseChartPayload = (canvas) => {
  const raw = canvas.dataset.chart;
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch (error) {
    return null;
  }
};

document.addEventListener("DOMContentLoaded", () => {
  const charts = document.querySelectorAll("[data-dashboard-chart]");
  if (charts.length === 0 || !window.Chart) return;

  configureChartDefaults();

  const isDark = localStorage.getItem("dark-mode") === "true";

  charts.forEach((canvas) => {
    const payload = parseChartPayload(canvas);
    if (!payload) return;

    const kind = resolveChartKind(canvas);
    const format = canvas.dataset.chartFormat || "count";

    if (kind === "pie") {
      const dataset = payload.datasets ? payload.datasets[0] : {};
      const chart = new Chart(canvas, {
        type: "pie",
        data: {
          labels: payload.labels || [],
          datasets: [buildPieDataset(dataset)]
        },
        options: {
          layout: { padding: { top: 4, bottom: 4, left: 24, right: 24 } },
          plugins: {
            legend: { display: false },
            tooltip: pieTooltip(format, chartColors(isDark))
          },
          interaction: { intersect: false, mode: "nearest" },
          animation: { duration: 200 },
          maintainAspectRatio: false
        },
        plugins: [buildHtmlLegendPlugin("fintech-card-09-legend", true)]
      });

      document.addEventListener("darkMode", () => updateColorsForPieChart(chart, format));
      return;
    }

    const options = buildLineOptions(kind, format, isDark);
    const chart = new Chart(canvas, {
      type: "line",
      data: {
        labels: payload.labels || [],
        datasets: buildLineDatasets(payload.datasets, kind)
      },
      options: options,
      plugins: kind === "main" ? [buildHtmlLegendPlugin("fintech-card-01-legend", false)] : []
    });

    document.addEventListener("darkMode", () => updateColorsForLineChart(chart, kind, format));
  });
});
