const parseChartPayload = (canvas) => {
  const raw = canvas.dataset.chart;
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch (error) {
    return null;
  }
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

const lineOptionsFor = (style, format, isDark) => {
  const showAxes = style === "main-line";
  const showTooltip = style !== "mini-line" && style !== "sparkline";
  const gridColor = isDark ? "#374151" : "#E5E7EB";
  const tickColor = isDark ? "#9CA3AF" : "#6B7280";

  return {
    maintainAspectRatio: false,
    interaction: { intersect: false, mode: "nearest" },
    scales: {
      x: {
        display: showAxes,
        grid: { display: false },
        ticks: { color: tickColor }
      },
      y: {
        display: showAxes,
        beginAtZero: style !== "main-line",
        grid: { color: gridColor },
        ticks: {
          color: tickColor,
          callback: (value) => formatValue(value, format)
        }
      }
    },
    plugins: {
      legend: { display: false },
      tooltip: {
        enabled: showTooltip,
        callbacks: {
          label: (context) => {
            const value = formatValue(context.parsed.y, format);
            if (context.dataset.label) {
              return `${context.dataset.label}: ${value}`;
            }
            return value;
          }
        }
      }
    }
  };
};

const doughnutOptionsFor = (format) => ({
  maintainAspectRatio: false,
  cutout: "70%",
  plugins: {
    legend: { display: false },
    tooltip: {
      callbacks: {
        label: (context) => {
          const label = context.label || "";
          const value = formatValue(context.parsed, format);
          return label ? `${label}: ${value}` : value;
        }
      }
    }
  }
});

const buildLineDatasets = (datasets, style) => {
  const borderWidth = style === "main-line" ? 2 : 1.5;
  return (datasets || []).map((dataset) => ({
    label: dataset.label,
    data: dataset.data || [],
    borderColor: dataset.color || "#6366F1",
    backgroundColor: dataset.color || "transparent",
    borderWidth: borderWidth,
    pointRadius: 0,
    pointHoverRadius: style === "main-line" ? 3 : 0,
    tension: 0.25,
    fill: false
  }));
};

const buildDoughnutDataset = (dataset) => ({
  data: dataset.data || [],
  backgroundColor: dataset.colors || [],
  borderWidth: 0
});

document.addEventListener("DOMContentLoaded", () => {
  const charts = document.querySelectorAll("[data-dashboard-chart]");
  if (charts.length === 0 || !window.Chart) return;

  const isDark = localStorage.getItem("dark-mode") === "true";

  charts.forEach((canvas) => {
    const payload = parseChartPayload(canvas);
    if (!payload) return;

    const type = payload.type || "line";
    const style = canvas.dataset.chartStyle || "card-line";
    const format = canvas.dataset.chartFormat || "count";

    if (type === "doughnut") {
      const dataset = payload.datasets ? payload.datasets[0] : {};
      new Chart(canvas, {
        type: "doughnut",
        data: {
          labels: payload.labels || [],
          datasets: [buildDoughnutDataset(dataset)]
        },
        options: doughnutOptionsFor(format)
      });
      return;
    }

    new Chart(canvas, {
      type: "line",
      data: {
        labels: payload.labels || [],
        datasets: buildLineDatasets(payload.datasets, style)
      },
      options: lineOptionsFor(style, format, isDark)
    });
  });
});
