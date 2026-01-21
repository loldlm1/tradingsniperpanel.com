const initAnalyticsCharts = () => {
  const canvases = document.querySelectorAll('canvas[data-chart-variant]');
  if (!canvases.length || !window.Chart) return;

  const hexToRGB = (h) => {
    let r = 0;
    let g = 0;
    let b = 0;
    if (h.length === 4) {
      r = `0x${h[1]}${h[1]}`;
      g = `0x${h[2]}${h[2]}`;
      b = `0x${h[3]}${h[3]}`;
    } else if (h.length === 7) {
      r = `0x${h[1]}${h[2]}`;
      g = `0x${h[3]}${h[4]}`;
      b = `0x${h[5]}${h[6]}`;
    }
    return `${+r},${+g},${+b}`;
  };

  const formatThousands = (value) => {
    const numeric = Number(value);
    if (Number.isNaN(numeric)) return '0';
    return Intl.NumberFormat('en-US', {
      maximumSignificantDigits: 3,
      notation: 'compact'
    }).format(numeric);
  };

  Chart.defaults.font.family = '"Inter", sans-serif';
  Chart.defaults.font.weight = 500;
  Chart.defaults.plugins.tooltip.borderWidth = 1;
  Chart.defaults.plugins.tooltip.displayColors = false;
  Chart.defaults.plugins.tooltip.mode = 'nearest';
  Chart.defaults.plugins.tooltip.intersect = false;
  Chart.defaults.plugins.tooltip.position = 'nearest';
  Chart.defaults.plugins.tooltip.caretSize = 0;
  Chart.defaults.plugins.tooltip.caretPadding = 20;
  Chart.defaults.plugins.tooltip.cornerRadius = 8;
  Chart.defaults.plugins.tooltip.padding = 8;

  const textColor = {
    light: '#9CA3AF',
    dark: '#6B7280'
  };

  const gridColor = {
    light: '#F3F4F6',
    dark: `rgba(${hexToRGB('#374151')}, 0.6)`
  };

  const tooltipTitleColor = {
    light: '#1F2937',
    dark: '#F3F4F6'
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

  const backdropColor = {
    light: '#ffffff',
    dark: '#1F2937'
  };

  const isDarkMode = () => localStorage.getItem('dark-mode') === 'true';

  const chartAreaGradient = (ctx, chartArea, colorStops) => {
    if (!ctx || !chartArea || !colorStops || !colorStops.length) return 'transparent';
    const gradient = ctx.createLinearGradient(0, chartArea.bottom, 0, chartArea.top);
    colorStops.forEach(({ stop, color }) => {
      gradient.addColorStop(stop, color);
    });
    return gradient;
  };

  const htmlLegendPlugin = {
    id: 'htmlLegend',
    afterUpdate(chart, args, options) {
      const legendContainer = options && options.containerID ? document.getElementById(options.containerID) : null;
      const list = legendContainer ? legendContainer.querySelector('ul') : null;
      if (!list) return;

      while (list.firstChild) {
        list.firstChild.remove();
      }

      const items = chart.options.plugins.legend.labels.generateLabels(chart);
      const style = options && options.style ? options.style : 'swatch';

      items.forEach((item) => {
        const li = document.createElement('li');
        const button = document.createElement('button');
        button.style.opacity = item.hidden ? '.3' : '';

        if (style === 'pill') {
          li.style.margin = '4px';
          button.classList.add(
            'btn-xs',
            'bg-white',
            'dark:bg-gray-700',
            'text-gray-500',
            'dark:text-gray-400',
            'shadow-xs',
            'shadow-black/[0.08]',
            'rounded-full'
          );
          button.onclick = () => {
            chart.toggleDataVisibility(item.index);
            chart.update();
          };

          const box = document.createElement('span');
          box.style.display = 'block';
          box.style.width = '8px';
          box.style.height = '8px';
          box.style.backgroundColor = item.fillStyle;
          box.style.borderRadius = '2px';
          box.style.marginRight = '4px';
          box.style.pointerEvents = 'none';

          const label = document.createElement('span');
          label.style.display = 'flex';
          label.style.alignItems = 'center';
          label.appendChild(document.createTextNode(item.text));

          li.appendChild(button);
          button.appendChild(box);
          button.appendChild(label);
          list.appendChild(li);
          return;
        }

        button.style.display = 'inline-flex';
        button.style.alignItems = 'center';
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
    const tooltipTitle = darkMode ? tooltipTitleColor.dark : tooltipTitleColor.light;
    const backdrop = darkMode ? backdropColor.dark : backdropColor.light;

    const scales = chart.options && chart.options.scales ? chart.options.scales : null;
    const plugins = chart.options && chart.options.plugins ? chart.options.plugins : null;

    if (scales) {
      if (variant === 'line-main' || variant === 'bar-stacked' || variant === 'bar-horizontal') {
        if (scales.x && scales.x.ticks) scales.x.ticks.color = text;
        if (scales.y && scales.y.ticks) scales.y.ticks.color = text;
        if (scales.y && scales.y.grid) scales.y.grid.color = grid;
      }

      if (variant === 'bar-horizontal') {
        if (scales.x && scales.x.grid) scales.x.grid.color = grid;
      }

      if (variant === 'polar' && scales.r) {
        if (scales.r.grid) scales.r.grid.color = grid;
        if (scales.r.ticks) {
          scales.r.ticks.color = text;
          scales.r.ticks.backdropColor = backdrop;
        }
      }
    }

    if (plugins && plugins.tooltip) {
      plugins.tooltip.bodyColor = tooltipBody;
      plugins.tooltip.backgroundColor = tooltipBg;
      plugins.tooltip.borderColor = tooltipBorder;

      if (variant === 'doughnut' || variant === 'polar') {
        plugins.tooltip.titleColor = tooltipTitle;
      }
    }

    chart.update('none');
  };

  const lineMainChart = (canvas, payload) => {
    const ctx = canvas.getContext('2d');
    const darkMode = isDarkMode();
    const lineColor = '#8470FF';
    const previousColor = `rgba(${hexToRGB('#6B7280')}, 0.25)`;

    const datasets = payload.datasets.map((dataset, index) => {
      const base = {
        label: dataset.label,
        data: dataset.data.map((value) => Number(value) || 0),
        borderWidth: 2,
        pointRadius: 0,
        pointHoverRadius: 3,
        pointBorderWidth: 0,
        pointHoverBorderWidth: 0,
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
            { stop: 0, color: `rgba(${hexToRGB('#8470FF')}, 0)` },
            { stop: 1, color: `rgba(${hexToRGB('#8470FF')}, 0.2)` }
          ]);
        };
      } else {
        base.borderColor = previousColor;
        base.pointBackgroundColor = previousColor;
        base.pointHoverBackgroundColor = previousColor;
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
        layout: {
          padding: 20
        },
        scales: {
          y: {
            beginAtZero: true,
            border: {
              display: false
            },
            grid: {
              color: darkMode ? gridColor.dark : gridColor.light
            },
            ticks: {
              color: darkMode ? textColor.dark : textColor.light,
              callback: (value) => formatThousands(value)
            }
          },
          x: {
            type: 'time',
            time: {
              parser: 'YYYY-MM-DD',
              unit: 'day',
              displayFormats: {
                day: 'MMM d'
              }
            },
            border: {
              display: false
            },
            grid: {
              display: false
            },
            ticks: {
              autoSkipPadding: 48,
              maxRotation: 0,
              color: darkMode ? textColor.dark : textColor.light
            }
          }
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              title: () => false,
              label: (context) => formatThousands(context.parsed.y)
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
                { stop: 0, color: `rgba(${hexToRGB('#8470FF')}, 0)` },
                { stop: 1, color: `rgba(${hexToRGB('#8470FF')}, 0.2)` }
              ]);
            },
            borderColor: lineColor,
            borderWidth: 2,
            pointRadius: 0,
            pointHoverRadius: 3,
            pointBorderWidth: 0,
            pointHoverBorderWidth: 0,
            pointBackgroundColor: lineColor,
            pointHoverBackgroundColor: lineColor,
            tension: 0.2,
            clip: 20
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
              title: () => false,
              label: (context) => formatThousands(context.parsed.y)
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
    const palette = [
      { fill: '#5D47DE', hover: '#4634B1' },
      { fill: '#8470FF', hover: '#755FF8' },
      { fill: '#B7ACFF', hover: '#9C8CFF' },
      { fill: '#E6E1FF', hover: '#D2CBFF' }
    ];

    const datasets = payload.datasets.map((dataset, index) => {
      const colors = palette[index % palette.length];
      return {
        label: dataset.label,
        data: dataset.data.map((value) => Number(value) || 0),
        backgroundColor: colors.fill,
        hoverBackgroundColor: colors.hover,
        barPercentage: 0.7,
        categoryPercentage: 0.7,
        borderRadius: 4
      };
    });

    const chart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: payload.labels,
        datasets: datasets
      },
      options: {
        layout: {
          padding: {
            top: 12,
            bottom: 16,
            left: 20,
            right: 20
          }
        },
        scales: {
          y: {
            stacked: true,
            beginAtZero: true,
            border: {
              display: false
            },
            grid: {
              color: darkMode ? gridColor.dark : gridColor.light
            },
            ticks: {
              maxTicksLimit: 5,
              color: darkMode ? textColor.dark : textColor.light,
              callback: (value) => formatThousands(value)
            }
          },
          x: {
            stacked: true,
            border: {
              display: false
            },
            grid: {
              display: false
            },
            ticks: {
              autoSkipPadding: 48,
              maxRotation: 0,
              color: darkMode ? textColor.dark : textColor.light
            }
          }
        },
        plugins: {
          legend: {
            display: false
          },
          htmlLegend: {
            containerID: 'analytics-card-03-legend',
            style: 'swatch'
          },
          tooltip: {
            callbacks: {
              title: () => false,
              label: (context) => formatThousands(context.parsed.y)
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
        animation: {
          duration: 200
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
    const palette = [
      { fill: '#8470FF', hover: '#755FF8' },
      { fill: '#7BC8FF', hover: '#67BFFF' }
    ];

    const chart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: payload.labels,
        datasets: payload.datasets.map((dataset, index) => {
          const colors = palette[index % palette.length];
          return {
            label: dataset.label,
            data: dataset.data.map((value) => Number(value) || 0),
            backgroundColor: colors.fill,
            hoverBackgroundColor: colors.hover,
            categoryPercentage: 0.7,
            barPercentage: 0.7,
            borderRadius: 4
          };
        })
      },
      options: {
        indexAxis: 'y',
        layout: {
          padding: {
            top: 12,
            bottom: 16,
            left: 20,
            right: 20
          }
        },
        scales: {
          x: {
            beginAtZero: true,
            max: 100,
            border: {
              display: false
            },
            grid: {
              color: darkMode ? gridColor.dark : gridColor.light
            },
            ticks: {
              maxTicksLimit: 3,
              align: 'end',
              color: darkMode ? textColor.dark : textColor.light,
              callback: (value) => `${formatThousands(value)}%`
            }
          },
          y: {
            border: {
              display: false
            },
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
            containerID: 'analytics-card-04-legend',
            style: 'swatch'
          },
          tooltip: {
            callbacks: {
              title: () => false,
              label: (context) => `${formatThousands(context.parsed.x)}%`
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
        animation: {
          duration: 200
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
      'analytics-card-08': {
        fill: ['#8470FF', '#7BC8FF', '#4634B1'],
        hover: ['#755FF8', '#67BFFF', '#2F227C']
      },
      'analytics-card-09': {
        fill: ['#8470FF', '#7BC8FF', '#FF5656', '#3EC972', '#F59E0B', '#8B5CF6'],
        hover: ['#755FF8', '#67BFFF', '#FA4949', '#059669', '#D97706', '#7C3AED']
      }
    };
    const scheme = schemes[canvas.id] || schemes['analytics-card-09'];

    const chart = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: payload.labels,
        datasets: payload.datasets.map((dataset) => ({
          label: dataset.label,
          data: dataset.data.map((value) => Number(value) || 0),
          backgroundColor: scheme.fill.slice(0, payload.labels.length),
          hoverBackgroundColor: scheme.hover.slice(0, payload.labels.length),
          borderWidth: 0
        }))
      },
      options: {
        cutout: '80%',
        layout: {
          padding: 24
        },
        plugins: {
          legend: {
            display: false
          },
          htmlLegend: {
            containerID: canvas.id === 'analytics-card-08' ? 'analytics-card-08-legend' : 'analytics-card-09-legend',
            style: 'pill'
          },
          tooltip: {
            callbacks: {
              label: (context) => {
                const value = Number(context.parsed);
                if (canvas.id === 'analytics-card-09') {
                  return `${context.label}: ${formatThousands(value)} min`;
                }
                return `${context.label}: ${formatThousands(value)}`;
              }
            },
            titleColor: darkMode ? tooltipTitleColor.dark : tooltipTitleColor.light,
            bodyColor: darkMode ? tooltipBodyColor.dark : tooltipBodyColor.light,
            backgroundColor: darkMode ? tooltipBgColor.dark : tooltipBgColor.light,
            borderColor: darkMode ? tooltipBorderColor.dark : tooltipBorderColor.light
          }
        },
        interaction: {
          intersect: false,
          mode: 'nearest'
        },
        animation: {
          duration: 200
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
    const colors = [
      `rgba(${hexToRGB('#8470FF')}, 0.8)`,
      `rgba(${hexToRGB('#7BC8FF')}, 0.8)`,
      `rgba(${hexToRGB('#3EC972')}, 0.8)`,
      `rgba(${hexToRGB('#F59E0B')}, 0.8)`
    ];
    const hoverColors = [
      `rgba(${hexToRGB('#755FF8')}, 0.8)`,
      `rgba(${hexToRGB('#67BFFF')}, 0.8)`,
      `rgba(${hexToRGB('#059669')}, 0.8)`,
      `rgba(${hexToRGB('#D97706')}, 0.8)`
    ];

    const chart = new Chart(ctx, {
      type: 'polarArea',
      data: {
        labels: payload.labels,
        datasets: payload.datasets.map((dataset) => ({
          label: dataset.label,
          data: dataset.data.map((value) => Number(value) || 0),
          backgroundColor: colors.slice(0, payload.labels.length),
          hoverBackgroundColor: hoverColors.slice(0, payload.labels.length),
          borderWidth: 0
        }))
      },
      options: {
        layout: {
          padding: 24
        },
        scales: {
          r: {
            grid: {
              color: darkMode ? gridColor.dark : gridColor.light
            },
            ticks: {
              color: darkMode ? textColor.dark : textColor.light,
              backdropColor: darkMode ? backdropColor.dark : backdropColor.light
            }
          }
        },
        plugins: {
          legend: {
            display: false
          },
          htmlLegend: {
            containerID: 'analytics-card-10-legend',
            style: 'pill'
          },
          tooltip: {
            callbacks: {
              label: (context) => `${context.label}: ${formatThousands(context.parsed)}`
            },
            titleColor: darkMode ? tooltipTitleColor.dark : tooltipTitleColor.light,
            bodyColor: darkMode ? tooltipBodyColor.dark : tooltipBodyColor.light,
            backgroundColor: darkMode ? tooltipBgColor.dark : tooltipBgColor.light,
            borderColor: darkMode ? tooltipBorderColor.dark : tooltipBorderColor.light
          }
        },
        interaction: {
          intersect: false,
          mode: 'nearest'
        },
        animation: {
          duration: 200
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
