(function () {
  const API_BASE =
    document.documentElement.dataset.apiBase ||
    "https://arxiv-trend-predictor-api.onrender.com";

  const CHART_COLORS = {
    accent: "#2ec4b6",
    accentRgba: "rgba(46, 196, 182, 0.85)",
    success: "#34d399",
    muted: "rgba(139, 141, 152, 0.7)",
    grid: "rgba(255, 255, 255, 0.06)",
    text: "#8b8d98",
  };

  const EXAMPLES = {
    1: {
      title: "Attention Is All You Need: Transformers for Sequence Modeling",
      abstract: "We propose a new architecture based entirely on self-attention mechanisms, dispensing with recurrence and convolutions. The Transformer achieves state-of-the-art results on machine translation and scales effectively to large datasets.",
    },
    2: {
      title: "Neural Radiance Fields for View Synthesis and 3D Reconstruction",
      abstract: "We present a method that represents a scene as a continuous 5D function and uses volume rendering to synthesize novel views. By optimizing a fully-connected neural network without convolutional layers, we achieve high-resolution photorealistic results.",
    },
  };

  const form = document.getElementById("advise-form");
  const submitBtn = document.getElementById("submit-btn");
  const statusEl = document.getElementById("status");
  const resultSection = document.getElementById("result");
  const vizSection = document.getElementById("viz-section");
  const vizNumbers = document.getElementById("viz-numbers");
  const resultDomain = document.getElementById("result-domain");
  const resultGrowth = document.getElementById("result-growth");
  const resultModelInfo = document.getElementById("result-model-info");
  const resultMessageWrap = document.getElementById("result-message-wrap");
  const resultMessage = document.getElementById("result-message");
  const resultDisclaimer = document.getElementById("result-disclaimer");
  const errorSection = document.getElementById("error");
  const errorMessage = document.getElementById("error-message");

  let chartConfidence = null;
  let chartGrowth = null;
  let chartScatter = null;

  function destroyCharts() {
    if (chartConfidence) {
      chartConfidence.destroy();
      chartConfidence = null;
    }
    if (chartGrowth) {
      chartGrowth.destroy();
      chartGrowth = null;
    }
    if (chartScatter) {
      chartScatter.destroy();
      chartScatter = null;
    }
  }

  function buildCharts(data) {
    destroyCharts();
    if (typeof Chart === "undefined") return;

    // Handle new data structure
    const primaryDomain = data.primary_domain || data.domain || "Primary";
    const allDomains = data.all_domains || [primaryDomain];
    const domainConfidence = data.domain_confidence || {};
    const growthInfo = data.growth_info || {};

    // Build labels and values from all_domains
    var labels = allDomains;
    var confValues = allDomains.map(function(domain) {
      return typeof domainConfidence === 'object' ? (domainConfidence[domain] || 0) : 0;
    });
    var bgColors = [CHART_COLORS.accentRgba].concat(
      allDomains.slice(1).map(function () {
        return CHART_COLORS.muted;
      })
    );

    chartConfidence = new Chart(document.getElementById("chart-confidence"), {
      type: "bar",
      data: {
        labels: labels,
        datasets: [
          {
            label: "Confidence",
            data: confValues,
            backgroundColor: bgColors,
            borderColor: [CHART_COLORS.accent].concat(allDomains.slice(1).map(function () { return "rgba(139,141,152,0.4)"; })),
            borderWidth: 1,
            borderRadius: 4,
          },
        ],
      },
      options: {
        indexAxis: "y",
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: function (ctx) {
                return (ctx.raw * 100).toFixed(1) + "%";
              },
            },
          },
        },
        scales: {
          x: {
            max: 1,
            grid: { color: CHART_COLORS.grid },
            ticks: { color: CHART_COLORS.text, callback: function (v) { return (v * 100).toFixed(0) + "%"; } },
          },
          y: { grid: { display: false }, ticks: { color: CHART_COLORS.text } },
        },
      },
    });

    // Use slope from growth_info for primary domain as growth value (normalized)
    var primaryGrowthData = growthInfo[primaryDomain] || {};
    var growthSlope = primaryGrowthData.slope || 0;
    var growthVal = Math.min(Math.max(growthSlope / 5, 0), 1); // Normalize slope to 0-1 range (assuming max slope ~5)

    chartGrowth = new Chart(document.getElementById("chart-growth"), {
      type: "bar",
      data: {
        labels: ["Growth slope"],
        datasets: [
          {
            label: "Slope",
            data: [growthVal],
            backgroundColor: CHART_COLORS.success,
            borderColor: "rgba(52, 211, 153, 0.5)",
            borderWidth: 1,
            borderRadius: 6,
          },
        ],
      },
      options: {
        indexAxis: "y",
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: function (ctx) {
                return " Slope: " + growthSlope.toFixed(3) + " (R²: " + (primaryGrowthData.r2 || 0).toFixed(3) + ")";
              },
            },
          },
        },
        scales: {
          x: {
            min: 0,
            max: 1,
            grid: { color: CHART_COLORS.grid },
            ticks: { color: CHART_COLORS.text, callback: function (v) { return (v * 100).toFixed(0) + "%"; } },
          },
          y: { grid: { display: false }, ticks: { color: CHART_COLORS.text } },
        },
      },
    });

    // Build scatter points: x=confidence, y=normalized growth slope
    var scatterPoints = allDomains.map(function(domain, idx) {
      var conf = domainConfidence[domain] || 0;
      var gInfo = growthInfo[domain] || {};
      var normalizedSlope = Math.min(Math.max((gInfo.slope || 0) / 5, 0), 1);
      return { x: conf, y: normalizedSlope, label: domain };
    });

    chartScatter = new Chart(document.getElementById("chart-scatter"), {
      type: "scatter",
      data: {
        datasets: [
          {
            label: primaryDomain,
            data: scatterPoints.filter(function (_, i) { return i === 0; }),
            backgroundColor: CHART_COLORS.accent,
            borderColor: "rgba(46, 196, 182, 0.6)",
            borderWidth: 2,
            pointRadius: 10,
            pointHoverRadius: 12,
          },
          {
            label: "Other Domains",
            data: scatterPoints.slice(1),
            backgroundColor: CHART_COLORS.muted,
            borderColor: "rgba(139, 141, 152, 0.5)",
            borderWidth: 1,
            pointRadius: 6,
            pointHoverRadius: 8,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: true,
            position: "top",
            labels: { color: CHART_COLORS.text, usePointStyle: true, padding: 12 },
          },
          tooltip: {
            callbacks: {
              label: function (ctx) {
                var p = ctx.raw;
                var domain = p.label || "Point";
                var gInfo = growthInfo[domain] || {};
                return domain + " — conf: " + (p.x * 100).toFixed(1) + "%, slope: " + ((gInfo.slope || 0).toFixed(3)) + ", R²: " + ((gInfo.r2 || 0).toFixed(3));
              },
            },
          },
        },
        scales: {
          x: {
            title: { display: true, text: "Confidence", color: CHART_COLORS.text },
            min: 0,
            max: 1,
            grid: { color: CHART_COLORS.grid },
            ticks: { color: CHART_COLORS.text, callback: function (v) { return (v * 100).toFixed(0) + "%"; } },
          },
          y: {
            title: { display: true, text: "Growth (normalized slope)", color: CHART_COLORS.text },
            min: 0,
            max: 1,
            grid: { color: CHART_COLORS.grid },
            ticks: { color: CHART_COLORS.text, callback: function (v) { return (v * 100).toFixed(0) + "%"; } },
          },
        },
      },
    });
  }

  function setLoading(loading) {
    submitBtn.disabled = loading;
    const actions = form.querySelector(".form-actions");
    if (loading) {
      actions.classList.add("is-loading");
      statusEl.textContent = "Calling advisor…";
    } else {
      actions.classList.remove("is-loading");
      statusEl.textContent = "";
    }
  }

  function showError(message) {
    errorMessage.textContent = message;
    errorSection.classList.remove("hidden");
    resultSection.classList.add("hidden");
  }

  function hideError() {
    errorSection.classList.add("hidden");
  }

  function escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }

  function formatPercent(value) {
    if (typeof value !== "number") return String(value);
    return (value * 100).toFixed(1) + "%";
  }

  function renderMessage(text) {
    if (!text) return "";
    var rawLines = text.split(/\n/).map(function (s) { return s.trim(); }).filter(Boolean);
    if (rawLines.length === 0) return "";

    var items;
    var allNumbered = rawLines.length > 0 && rawLines.every(function (line) {
      return /^\d+\.\s*.+/.test(line);
    });
    if (allNumbered && rawLines.length > 1) {
      // Already "1. ..." "2. ..." from API
      items = rawLines.map(function (line) {
        var m = line.match(/^\d+\.\s*(.*)$/);
        return (m ? m[1] : line).replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
      });
    } else {
      // Single paragraph from API: split at sentence boundaries (period + space + capital letter)
      var paragraph = rawLines.join(" ");
      var sentences = paragraph.split(/\.\s+(?=[A-Z])/).map(function (s) {
        return s.trim();
      }).filter(Boolean);
      items = sentences.map(function (s) {
        var withPeriod = s.slice(-1) === "." ? s : s + ".";
        return withPeriod.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
      });
    }
    if (items.length === 0) return "";
    var lis = items.map(function (html) { return "<li>" + html + "</li>"; }).join("");
    return "<ol class=\"result-message-list\">" + lis + "</ol>";
  }

  function renderResult(data) {
    hideError();
    resultSection.classList.remove("hidden");
    vizSection.classList.remove("hidden");
    buildCharts(data);

    if (vizNumbers) {
      var primaryDomain = data.primary_domain || data.domain || "Primary";
      var allDomains = data.all_domains || [primaryDomain];
      var domainConfidence = data.domain_confidence || {};
      var growthInfo = data.growth_info || {};

      var items = [];
      allDomains.forEach(function(domain, idx) {
        var conf = domainConfidence[domain] || 0;
        var prefix = idx === 0 ? "<strong>" : "";
        var suffix = idx === 0 ? "</strong>" : "";
        items.push("<li class=\"viz-num-item\">" + prefix + escapeHtml(domain) + suffix + " " + formatPercent(conf) + "</li>");
      });

      // Add growth info for primary domain
      var primaryGrowthData = growthInfo[primaryDomain] || {};
      var slopeVal = primaryGrowthData.slope != null ? primaryGrowthData.slope.toFixed(3) : "—";
      var r2Val = primaryGrowthData.r2 != null ? primaryGrowthData.r2.toFixed(3) : "—";
      items.push("<li class=\"viz-num-item\"><strong>Growth (slope):</strong> <span class=\"viz-num-growth\">" + slopeVal + "</span></li>");
      items.push("<li class=\"viz-num-item\"><strong>R² (fit quality):</strong> " + r2Val + "</li>");

      vizNumbers.innerHTML =
        "<p class=\"viz-numbers-title\">Numbers at a glance</p>" +
        "<ul class=\"viz-numbers-list\">" + items.join("") + "</ul>";
    }

    resultDomain.innerHTML = "";
    var primaryDomain = data.primary_domain || data.domain || "—";
    var allDomains = data.all_domains || [primaryDomain];
    var domainConfidence = data.domain_confidence || {};
    var growthInfo = data.growth_info || {};

    var mainConf = domainConfidence[primaryDomain] || 0;
    var domainRow = document.createElement("div");
    domainRow.className = "domain-main-row";
    domainRow.innerHTML =
      "<span class=\"domain-name\">" + escapeHtml(primaryDomain) + "</span>" +
      "<span class=\"domain-confidence-value\" aria-label=\"Confidence\">" + formatPercent(mainConf) + "</span>";
    resultDomain.appendChild(domainRow);

    const otherDomains = allDomains.slice(1);
    if (otherDomains.length > 0) {
      const altWrap = document.createElement("div");
      altWrap.className = "alternates";
      const altTitle = document.createElement("p");
      altTitle.className = "alternates-title";
      altTitle.textContent = "Other predicted domains";
      altWrap.appendChild(altTitle);
      const ul = document.createElement("ul");
      ul.className = "alternate-list";
      ul.setAttribute("role", "table");
      var header = document.createElement("li");
      header.className = "alternate-list-header";
      header.innerHTML = "<span>Domain</span><span>Confidence</span><span>Growth</span>";
      ul.appendChild(header);
      otherDomains.forEach(function (domain) {
        const conf = domainConfidence[domain] || 0;
        const gInfo = growthInfo[domain] || {};
        const slope = gInfo.slope != null ? gInfo.slope.toFixed(3) : "—";
        const li = document.createElement("li");
        li.innerHTML =
          "<span>" + escapeHtml(domain) + "</span>" +
          "<span class=\"alternate-conf\">" + formatPercent(conf) + "</span>" +
          "<span class=\"alternate-growth\">" + slope + "</span>";
        ul.appendChild(li);
      });
      altWrap.appendChild(ul);
      resultDomain.appendChild(altWrap);
    }

    resultGrowth.innerHTML = "";
    var primaryDomain = data.primary_domain || data.domain || "Primary";
    var growthInfo = data.growth_info || {};
    var primaryGrowthData = growthInfo[primaryDomain] || {};

    var growthLabel = document.createElement("p");
    growthLabel.className = "growth-label";
    growthLabel.textContent = "Growth Trend for " + primaryDomain;
    resultGrowth.appendChild(growthLabel);

    var metricsRow = document.createElement("div");
    metricsRow.className = "growth-metrics-row";

    var slopeWrap = document.createElement("p");
    slopeWrap.className = "growth-score-wrap";
    var slopeVal = primaryGrowthData.slope != null ? primaryGrowthData.slope.toFixed(3) : "—";
    slopeWrap.innerHTML =
      "Slope<span class=\"growth-score-value\" aria-label=\"Growth slope\">" + slopeVal + "</span>";
    metricsRow.appendChild(slopeWrap);

    var r2Wrap = document.createElement("p");
    r2Wrap.className = "growth-score-wrap";
    var r2Val = primaryGrowthData.r2 != null ? primaryGrowthData.r2.toFixed(3) : "—";
    r2Wrap.innerHTML =
      "R² fit quality<span class=\"growth-score-value\" aria-label=\"R-squared\">" + r2Val + "</span>";
    metricsRow.appendChild(r2Wrap);

    resultGrowth.appendChild(metricsRow);

    // Display model info metrics
    resultModelInfo.innerHTML = "";
    var modelInfo = data.model_info || {};
    if (Object.keys(modelInfo).length > 0) {
      var modelInfoTitle = document.createElement("p");
      modelInfoTitle.className = "model-info-title";
      modelInfoTitle.textContent = "Model Performance Metrics";
      resultModelInfo.appendChild(modelInfoTitle);

      var metricsTable = document.createElement("div");
      metricsTable.className = "model-metrics-table";

      var metrics = [
        { key: "subset_accuracy", label: "Subset Accuracy" },
        { key: "hamming_loss", label: "Hamming Loss" },
        { key: "macro_f1", label: "Macro F1" },
        { key: "micro_f1", label: "Micro F1" },
        { key: "samples_f1", label: "Samples F1" },
        { key: "cv_micro_f1_mean", label: "CV Micro F1 (mean)" },
        { key: "cv_micro_f1_std", label: "CV Micro F1 (std)" }
      ];

      metrics.forEach(function(metric) {
        if (modelInfo[metric.key] != null) {
          var row = document.createElement("p");
          row.className = "model-metric-row";
          var val = modelInfo[metric.key].toFixed(4);
          row.innerHTML = "<span>" + metric.label + "</span><span class=\"model-metric-value\">" + val + "</span>";
          metricsTable.appendChild(row);
        }
      });

      resultModelInfo.appendChild(metricsTable);
    } else {
      resultModelInfo.classList.add("hidden");
    }


    var messageHtml = renderMessage(data.message || "");
    if (resultMessage) resultMessage.innerHTML = messageHtml;
    if (resultMessageWrap) resultMessageWrap.classList.toggle("hidden", !messageHtml);
    resultDisclaimer.textContent = data.disclaimer || "";
  }

  document.querySelectorAll(".btn-example").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var key = btn.getAttribute("data-example");
      var ex = EXAMPLES[key];
      if (!ex) return;
      var titleInput = document.getElementById("title");
      var abstractInput = document.getElementById("abstract");
      if (titleInput) titleInput.value = ex.title;
      if (abstractInput) abstractInput.value = ex.abstract;
    });
  });

  form.addEventListener("submit", function (e) {
    e.preventDefault();
    const title = (form.querySelector("#title") || form.querySelector('[name="title"]')).value.trim();
    if (!title) {
      showError("Please enter a title.");
      return;
    }
    const abstract = (form.querySelector("#abstract") || form.querySelector('[name="abstract"]')).value.trim();

    setLoading(true);
    fetch(API_BASE + "/api/v1/advisor/advise", {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ title: title, abstract: abstract }),
    })
      .then(function (res) {
        if (!res.ok) {
          return res.json().then(
            function (body) {
              throw new Error(body.detail || res.statusText || "Request failed");
            },
            function () {
              throw new Error(res.statusText || "Request failed");
            }
          );
        }
        return res.json();
      })
      .then(function (data) {
        renderResult(data);
        statusEl.textContent = "Done.";
      })
      .catch(function (err) {
        showError(err.message || "Something went wrong. Check the API URL and try again.");
      })
      .finally(function () {
        setLoading(false);
      });
  });
})();
