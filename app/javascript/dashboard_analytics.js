document.addEventListener('DOMContentLoaded', () => {
  const chartContainer = document.querySelector('[data-analytics-chart]');
  if (chartContainer) {
    const raw = chartContainer.dataset.chart;
    const ctx = chartContainer.querySelector('canvas');

    if (raw && ctx && window.Chart) {
      const payload = JSON.parse(raw);
      const palette = [
        '#6366F1',
        '#14B8A6',
        '#F59E0B',
        '#EF4444',
        '#0EA5E9',
        '#8B5CF6'
      ];

      const datasetCount = payload.datasets.length;
      const isDark = localStorage.getItem('dark-mode') === 'true';

      const gradientFor = (context) => {
        const chart = context.chart;
        const { chartArea } = chart;
        if (!chartArea) return '#6366F1';
        const g = chart.ctx.createLinearGradient(0, chartArea.bottom, 0, chartArea.top);
        g.addColorStop(0, 'rgba(99, 102, 241, 0)');
        g.addColorStop(1, 'rgba(99, 102, 241, 0.2)');
        return g;
      };

      const datasets = payload.datasets.map((dataset, index) => {
        const color = palette[index % palette.length];
        const data = dataset.data.map((value) => Number(value) || 0);
        const base = {
          label: dataset.label,
          data: data,
          borderColor: color,
          borderWidth: 2,
          tension: 0.25,
          pointRadius: 0
        };

        if (datasetCount === 1) {
          base.fill = true;
          base.backgroundColor = (context) => gradientFor(context);
        } else {
          base.fill = false;
          base.backgroundColor = 'transparent';
        }

        return base;
      });

      new Chart(ctx, {
        type: 'line',
        data: {
          labels: payload.labels,
          datasets: datasets
        },
        options: {
          scales: {
            y: {
              beginAtZero: true,
              ticks: {
                callback: (value) => `$${Number(value).toFixed(2)}`
              },
              grid: {
                color: isDark ? '#374151' : '#E5E7EB'
              }
            },
            x: {
              grid: { display: false }
            }
          },
          plugins: {
            legend: { display: datasetCount > 1 },
            tooltip: {
              callbacks: {
                label: (context) => `${context.dataset.label}: $${Number(context.parsed.y).toFixed(2)}`
              }
            }
          },
          interaction: { intersect: false, mode: 'nearest' },
          maintainAspectRatio: false
        }
      });
    }
  }

  const filterForm = document.querySelector('[data-analytics-filters]');
  if (!filterForm) return;

  const datepicker = filterForm.querySelector('[data-analytics-datepicker]');
  const fromField = filterForm.querySelector('input[name="from_ts"]');
  const toField = filterForm.querySelector('input[name="to_ts"]');

  const submitForm = () => {
    if (filterForm.requestSubmit) {
      filterForm.requestSubmit();
    } else {
      filterForm.submit();
    }
  };

  const setHiddenRange = (dates) => {
    if (!fromField || !toField || dates.length < 2) return false;

    const [fromDate, toDate] = dates;
    const fromTs = Date.UTC(fromDate.getFullYear(), fromDate.getMonth(), fromDate.getDate()) / 1000;
    const toTs = (Date.UTC(toDate.getFullYear(), toDate.getMonth(), toDate.getDate() + 1) / 1000) - 1;

    fromField.value = Math.floor(fromTs);
    toField.value = Math.floor(toTs);
    return true;
  };

  if (datepicker && datepicker._flatpickr) {
    const fromTs = parseInt(datepicker.dataset.fromTs, 10);
    const toTs = parseInt(datepicker.dataset.toTs, 10);

    if (!Number.isNaN(fromTs) && !Number.isNaN(toTs)) {
      const fromDateUtc = new Date(fromTs * 1000);
      const toDateUtc = new Date(toTs * 1000);
      const fromDate = new Date(fromDateUtc.getUTCFullYear(), fromDateUtc.getUTCMonth(), fromDateUtc.getUTCDate());
      const toDate = new Date(toDateUtc.getUTCFullYear(), toDateUtc.getUTCMonth(), toDateUtc.getUTCDate());
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

  const selects = filterForm.querySelectorAll('select[data-analytics-filter]');
  selects.forEach((select) => {
    select.addEventListener('change', () => submitForm());
  });
});
