const initAnalyticsCharts = () => {
  const canvases = document.querySelectorAll('canvas[data-chart-variant]');
  if (!canvases.length || !window.Chart) return;

  const textColor = {
    light: '#9CA3AF',
    dark: '#6B7280'
  };

  const gridColor = {
    light: '#F3F4F6',
    dark: 'rgba(55, 65, 81, 0.6)'
  };

  const tooltipBodyColor = {
    light: '#6B7280',
    dark: '#9CA3AF'
  };

  const tooltipBgColor = {
    light: '#ffffff',
    dark: '#374151'
  };

  const tooltipBorderColor = {
    light: '#E5E7EB',
    dark: '#4B5563'
  };

  const isDarkMode = () => localStorage.getItem('dark-mode') === 'true';

  const chartAreaGradient = (ctx, chartArea, colorStops) => {
    if (!ctx || !chartArea || !colorStops.length) return 'transparent';
    const gradient = ctx.createLinearGradient(0, chartArea.bottom, 0, chartArea.top);
    colorStops.forEach(({ stop, color }) => {
      gradient.addColorStop(stop, color);
    });
    return gradient;
  };

  const htmlLegendPlugin = {
    id: 'htmlLegend',
    afterUpdate(chart, args, options) {
      const legendContainer = document.getElementById(options.containerID);
      const list = legendContainer ? legendContainer.querySelector('ul') : null;
      if (!list) return;
      while (list.firstChild) {
        list.firstChild.remove();
      }
      const items = chart.options.plugins.legend.labels.generateLabels(chart);
      items.forEach((item) => {
        const li = document.createElement('li');
        const button = document.createElement('button');
        button.style.display = 'inline-flex';
        button.style.alignItems = 'center';
        button.style.opacity = item.hidden ? '.3' : '';
        button.onclick = () => {
          chart.setDatasetVisibility(item.datasetIndex, !chart.isDatasetVisible(item.datasetIndex));
          chart.update();
        };
        const box = document.createElement('span');
        box.style.display = 'block';
        box.style.width = '12px';
        box.style.height = '12px';
        box.style.borderRadius = '9999px';
        box.style.marginRight = '8px';
        box.style.borderWidth = '3px';
        box.style.borderColor = item.fillStyle;
        box.style.pointerEvents = 'none';
        const label = document.createElement('span');
        label.classList.add('text-gray-500', 'dark:text-gray-400');
        label.style.fontSize = '0.875rem';
        label.style.lineHeight = '1.5715';
        label.appendChild(document.createTextNode(item.text));
        button.appendChild(box);
        button.appendChild(label);
        li.appendChild(button);
        list.appendChild(li);
      });
    }
  };

  const parsePayload = (canvas) => {
    const raw = canvas.dataset.chart;
    if (!raw) return null;
    try {
      return JSON.parse(raw);
    } catch (error) {
      return null;
    }
  };

  const charts = [];

  const registerChart = (chart, variant) => {
    charts.push({ chart, variant });
  };

  const applyTheme = (chart, variant, mode) => {
    const darkMode = mode === 'on';
    const text = darkMode ? textColor.dark : textColor.light;
    const grid = darkMode ? gridColor.dark : gridColor.light;
    const tooltipBody = darkMode ? tooltipBodyColor.dark : tooltipBodyColor.light;
    const tooltipBg = darkMode ? tooltipBgColor.dark : tooltipBgColor.light;
    const tooltipBorder = darkMode ? tooltipBorderColor.dark : tooltipBorderColor.light;

    const scales = chart.options && chart.options.scales ? chart.options.scales : null;
    const plugins = chart.options && chart.options.plugins ? chart.options.plugins : null;

    if (variant === 'line-main' || variant === 'bar-stacked' || variant === 'bar-horizontal') {
      if (scales && scales.x && scales.x.ticks) scales.x.ticks.color = text;
      if (scales && scales.y && scales.y.ticks) scales.y.ticks.color = text;
      if (scales && scales.y && scales.y.grid) scales.y.grid.color = grid;
    }

    if (variant === 'bar-horizontal') {
      if (scales && scales.x && scales.x.grid) scales.x.grid.color = grid;
    }

    if (plugins && plugins.tooltip) {
      plugins.tooltip.bodyColor = tooltipBody;
      plugins.tooltip.backgroundColor = tooltipBg;
      plugins.tooltip.borderColor = tooltipBorder;
    }
    chart.update('none');
  };

  const lineMainChart = (canvas, payload) => {
    const ctx = canvas.getContext('2d');
    const darkMode = isDarkMode();
    const lineColor = '#8470FF';
    const previousColor = 'rgba(107, 114, 128, 0.25)';

    const datasets = payload.datasets.map((dataset, index) => {
      const base = {
        label: dataset.label,
        data: dataset.data.map((value) => Number(value) || 0),
        borderWidth: 2,
        pointRadius: 0,
        pointHoverRadius: 3,
        tension: 0.2,
        clip: 20
      };

      if (index === 0) {
        base.borderColor = lineColor;
        base.pointBackgroundColor = lineColor;
        base.pointHoverBackgroundColor = lineColor;
        base.fill = true;
        base.backgroundColor = (context) => {
          const chart = context.chart;
          const { chartArea } = chart;
          return chartAreaGradient(chart.ctx, chartArea, [
            { stop: 0, color: 'rgba(132, 112, 255, 0)' },
            { stop: 1, color: 'rgba(132, 112, 255, 0.2)' }
          ]);
        };
      } else {
        base.borderColor = previousColor;
        base.fill = false;
      }

      return base;
    });

    const chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: payload.labels,
        datasets: datasets
      },
      options: {
        scales: {
          y: {
            beginAtZero: true,
            grid: {
              color: darkMode ? gridColor.dark : gridColor.light
            },
            ticks: {
              color: darkMode ? textColor.dark : textColor.light,
              callback: (value) => `$${Number(value).toFixed(2)}`
            }
          },
          x: {
            type: 'time',
            time: {
              parser: 'YYYY-MM-DD',
              unit: 'day'
            },
            grid: {
              display: false
            },
            ticks: {
              color: darkMode ? textColor.dark : textColor.light,
              maxRotation: 0
            }
          }
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              label: (context) => `${context.dataset.label}: $${Number(context.parsed.y).toFixed(2)}`
            },
            bodyColor: darkMode ? tooltipBodyColor.dark : tooltipBodyColor.light,
            backgroundColor: darkMode ? tooltipBgColor.dark : tooltipBgColor.light,
            borderColor: darkMode ? tooltipBorderColor.dark : tooltipBorderColor.light
          }
        },
        interaction: {
          intersect: false,
          mode: 'nearest'
        },
        maintainAspectRatio: false
      }
    });

    registerChart(chart, 'line-main');
  };

  const lineSparkChart = (canvas, payload) => {
    const ctx = canvas.getContext('2d');
    const darkMode = isDarkMode();
    const lineColor = '#8470FF';

    const firstDataset = payload.datasets[0] || { label: 'Active', data: [] };
    const chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: payload.labels,
        datasets: [
          {
            label: firstDataset.label || 'Active',
            data: (firstDataset.data || []).map((value) => Number(value) || 0),
            fill: true,
            backgroundColor: (context) => {
              const chart = context.chart;
              const { chartArea } = chart;
              return chartAreaGradient(chart.ctx, chartArea, [
                { stop: 0, color: 'rgba(132, 112, 255, 0)' },
                { stop: 1, color: 'rgba(132, 112, 255, 0.2)' }
              ]);
            },
            borderColor: lineColor,
            borderWidth: 2,
            pointRadius: 0,
            pointHoverRadius: 3,
            tension: 0.2
          }
        ]
      },
      options: {
        layout: {
          padding: {
            left: 20,
            right: 20
          }
        },
        scales: {
          y: {
            display: false,
            beginAtZero: true
          },
          x: {
            type: 'time',
            time: {
              parser: 'YYYY-MM-DD',
              unit: 'day'
            },
            display: false
          }
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              label: (context) => `${context.parsed.y}`
            },
            bodyColor: darkMode ? tooltipBodyColor.dark : tooltipBodyColor.light,
            backgroundColor: darkMode ? tooltipBgColor.dark : tooltipBgColor.light,
            borderColor: darkMode ? tooltipBorderColor.dark : tooltipBorderColor.light
          }
        },
        interaction: {
          intersect: false,
          mode: 'nearest'
        },
        maintainAspectRatio: false
      }
    });

    registerChart(chart, 'line-spark');
  };

  const stackedBarChart = (canvas, payload) => {
    const ctx = canvas.getContext('2d');
    const darkMode = isDarkMode();
    const colors = ['#3EC972', '#8470FF'];

    const datasets = payload.datasets.map((dataset, index) => ({
      label: dataset.label,
      data: dataset.data.map((value) => Number(value) || 0),
      backgroundColor: colors[index % colors.length],
      borderRadius: 4,
      barThickness: 8
    }));

    const chart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: payload.labels,
        datasets: datasets
      },
      options: {
        scales: {
          y: {
            stacked: true,
            beginAtZero: true,
            grid: {
              color: darkMode ? gridColor.dark : gridColor.light
            },
            ticks: {
              color: darkMode ? textColor.dark : textColor.light,
              callback: (value) => `$${Number(value).toFixed(0)}`
            }
          },
          x: {
            stacked: true,
            grid: {
              display: false
            },
            ticks: {
              color: darkMode ? textColor.dark : textColor.light,
              maxRotation: 0
            }
          }
        },
        plugins: {
          legend: {
            display: false
          },
          htmlLegend: {
            containerID: 'analytics-card-03-legend'
          },
          tooltip: {
            callbacks: {
              label: (context) => `${context.dataset.label}: $${Number(context.parsed.y).toFixed(2)}`
            },
            bodyColor: darkMode ? tooltipBodyColor.dark : tooltipBodyColor.light,
            backgroundColor: darkMode ? tooltipBgColor.dark : tooltipBgColor.light,
            borderColor: darkMode ? tooltipBorderColor.dark : tooltipBorderColor.light
          }
        },
        interaction: {
          intersect: false,
          mode: 'nearest'
        },
        maintainAspectRatio: false
      },
      plugins: [htmlLegendPlugin]
    });

    registerChart(chart, 'bar-stacked');
  };

  const horizontalBarChart = (canvas, payload) => {
    const ctx = canvas.getContext('2d');
    const darkMode = isDarkMode();

    const chart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: payload.labels,
        datasets: payload.datasets.map((dataset) => ({
          label: dataset.label,
          data: dataset.data.map((value) => Number(value) || 0),
          backgroundColor: '#8470FF',
          borderRadius: 4,
          barThickness: 10
        }))
      },
      options: {
        indexAxis: 'y',
        scales: {
          x: {
            beginAtZero: true,
            max: 100,
            grid: {
              color: darkMode ? gridColor.dark : gridColor.light
            },
            ticks: {
              color: darkMode ? textColor.dark : textColor.light,
              callback: (value) => `${value}%`
            }
          },
          y: {
            grid: {
              display: false
            },
            ticks: {
              color: darkMode ? textColor.dark : textColor.light
            }
          }
        },
        plugins: {
          legend: {
            display: false
          },
          htmlLegend: {
            containerID: 'analytics-card-04-legend'
          },
          tooltip: {
            callbacks: {
              label: (context) => `${context.parsed.x}%`
            },
            bodyColor: darkMode ? tooltipBodyColor.dark : tooltipBodyColor.light,
            backgroundColor: darkMode ? tooltipBgColor.dark : tooltipBgColor.light,
            borderColor: darkMode ? tooltipBorderColor.dark : tooltipBorderColor.light
          }
        },
        interaction: {
          intersect: false,
          mode: 'nearest'
        },
        maintainAspectRatio: false
      },
      plugins: [htmlLegendPlugin]
    });

    registerChart(chart, 'bar-horizontal');
  };

  const doughnutChart = (canvas, payload) => {
    const ctx = canvas.getContext('2d');
    const darkMode = isDarkMode();
    const schemes = {
      'analytics-card-08': ['#94A3B8', '#F59E0B', '#10B981'],
      'analytics-card-09': ['#6366F1', '#14B8A6', '#F59E0B', '#EF4444', '#0EA5E9', '#8B5CF6']
    };
    const colors = schemes[canvas.id] || schemes['analytics-card-09'];

    const chart = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: payload.labels,
        datasets: payload.datasets.map((dataset) => ({
          label: dataset.label,
          data: dataset.data.map((value) => Number(value) || 0),
          backgroundColor: colors.slice(0, payload.labels.length),
          borderWidth: 0
        }))
      },
      options: {
        cutout: '70%',
        plugins: {
          legend: {
            display: false
          },
          htmlLegend: {
            containerID: canvas.id === 'analytics-card-08' ? 'analytics-card-08-legend' : 'analytics-card-09-legend'
          },
          tooltip: {
            callbacks: {
              label: (context) => {
                const value = Number(context.parsed);
                if (canvas.id === 'analytics-card-09') {
                  return `${context.label}: ${value.toFixed(1)} min`;
                }
                return `${context.label}: ${value}`;
              }
            },
            bodyColor: darkMode ? tooltipBodyColor.dark : tooltipBodyColor.light,
            backgroundColor: darkMode ? tooltipBgColor.dark : tooltipBgColor.light,
            borderColor: darkMode ? tooltipBorderColor.dark : tooltipBorderColor.light
          }
        },
        maintainAspectRatio: false
      },
      plugins: [htmlLegendPlugin]
    });

    registerChart(chart, 'doughnut');
  };

  const polarChart = (canvas, payload) => {
    const ctx = canvas.getContext('2d');
    const darkMode = isDarkMode();
    const colors = ['#6366F1', '#F59E0B', '#14B8A6', '#0EA5E9'];

    const chart = new Chart(ctx, {
      type: 'polarArea',
      data: {
        labels: payload.labels,
        datasets: payload.datasets.map((dataset) => ({
          label: dataset.label,
          data: dataset.data.map((value) => Number(value) || 0),
          backgroundColor: colors.slice(0, payload.labels.length)
        }))
      },
      options: {
        plugins: {
          legend: {
            display: false
          },
          htmlLegend: {
            containerID: 'analytics-card-10-legend'
          },
          tooltip: {
            callbacks: {
              label: (context) => `${context.label}: ${Number(context.parsed).toFixed(0)}`
            },
            bodyColor: darkMode ? tooltipBodyColor.dark : tooltipBodyColor.light,
            backgroundColor: darkMode ? tooltipBgColor.dark : tooltipBgColor.light,
            borderColor: darkMode ? tooltipBorderColor.dark : tooltipBorderColor.light
          }
        },
        maintainAspectRatio: false
      },
      plugins: [htmlLegendPlugin]
    });

    registerChart(chart, 'polar');
  };

  canvases.forEach((canvas) => {
    const payload = parsePayload(canvas);
    if (!payload || !payload.labels || !payload.datasets) return;

    switch (canvas.dataset.chartVariant) {
      case 'line-main':
        lineMainChart(canvas, payload);
        break;
      case 'line-spark':
        lineSparkChart(canvas, payload);
        break;
      case 'bar-stacked':
        stackedBarChart(canvas, payload);
        break;
      case 'bar-horizontal':
        horizontalBarChart(canvas, payload);
        break;
      case 'doughnut':
        doughnutChart(canvas, payload);
        break;
      case 'polar':
        polarChart(canvas, payload);
        break;
      default:
        break;
    }
  });

  document.addEventListener('darkMode', (event) => {
    const mode = event.detail && event.detail.mode ? event.detail.mode : 'off';
    charts.forEach((entry) => applyTheme(entry.chart, entry.variant, mode));
  });
};

const initAnalyticsFilters = () => {
  const filterForm = document.querySelector('[data-analytics-filters]');
  if (!filterForm) return;

  const datepicker = filterForm.querySelector('[data-analytics-datepicker]');
  const fromField = filterForm.querySelector('input[name="from_date"]');
  const toField = filterForm.querySelector('input[name="to_date"]');

  const submitForm = () => {
    if (filterForm.requestSubmit) {
      filterForm.requestSubmit();
    } else {
      filterForm.submit();
    }
  };

  const formatDate = (date) => {
    const year = date.getFullYear();
    const month = `${date.getMonth() + 1}`.padStart(2, '0');
    const day = `${date.getDate()}`.padStart(2, '0');
    return `${year}-${month}-${day}`;
  };

  const setHiddenRange = (dates) => {
    if (!fromField || !toField || dates.length < 2) return false;
    const [fromDate, toDate] = dates;
    fromField.value = formatDate(fromDate);
    toField.value = formatDate(toDate);
    return true;
  };

  const parseDate = (value) => {
    if (!value) return null;
    const [year, month, day] = value.split('-').map((part) => parseInt(part, 10));
    if (!year || !month || !day) return null;
    return new Date(year, month - 1, day);
  };

  if (datepicker && datepicker._flatpickr) {
    const fromDate = parseDate(datepicker.dataset.fromDate);
    const toDate = parseDate(datepicker.dataset.toDate);
    if (fromDate && toDate) {
      datepicker._flatpickr.setDate([fromDate, toDate], false);
      setHiddenRange([fromDate, toDate]);
    }

    datepicker.addEventListener('change', () => {
      const dates = datepicker._flatpickr.selectedDates || [];
      if (setHiddenRange(dates)) {
        submitForm();
      }
    });
  }
};

document.addEventListener('DOMContentLoaded', () => {
  initAnalyticsCharts();
  initAnalyticsFilters();
});
