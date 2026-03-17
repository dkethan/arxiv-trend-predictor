(function () {
  const API_BASE =
    document.documentElement.dataset.apiBase ||
    "https://arxiv-trend-predictor-api-001.onrender.com";

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

    var primaryDomain = data.primary_domain || data.domain || "Primary";
    var allDomains = data.all_domains || [primaryDomain];
    var domainConfidence = data.domain_confidence || {};
    var growthInfo = data.growth_info || {};
    var allDomainNames = Object.keys(domainConfidence);

    // Top 10 domains by confidence (sorted descending)
    var top10 = allDomainNames.slice().sort(function (a, b) {
      return (domainConfidence[b] || 0) - (domainConfidence[a] || 0);
    }).slice(0, 10);
    var confLabels = top10;
    var confValues = top10.map(function (d) { return domainConfidence[d] || 0; });
    var confColors = top10.map(function (d) {
      return d === primaryDomain ? CHART_COLORS.accentRgba : CHART_COLORS.muted;
    });
    var confBorders = top10.map(function (d) {
      return d === primaryDomain ? CHART_COLORS.accent : "rgba(139,141,152,0.4)";
    });

    chartConfidence = new Chart(document.getElementById("chart-confidence"), {
      type: "bar",
      data: {
        labels: confLabels,
        datasets: [{
          label: "Confidence",
          data: confValues,
          backgroundColor: confColors,
          borderColor: confBorders,
          borderWidth: 1,
          borderRadius: 4,
        }],
      },
      options: {
        indexAxis: "y",
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              title: function (items) {
                if (!items || !items.length) return "";
                return confLabels[items[0].dataIndex] || "";
              },
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
          y: { grid: { display: false }, ticks: { display: false } },
        },
      },
    });

    // Grouped horizontal bar: slope per predicted domain, colored by R2 quality
    var growthLabels = allDomains;
    var growthSlopes = allDomains.map(function (d) {
      var g = growthInfo[d] || {};
      return g.slope != null ? Math.min(1, Math.max(0, g.slope)) : 0;
    });
    var growthColors = allDomains.map(function (d) {
      var r2 = (growthInfo[d] || {}).r2;
      if (r2 != null && r2 >= 0.5) return CHART_COLORS.success;
      if (r2 != null && r2 >= 0.25) return "rgba(251, 191, 36, 0.85)";
      return CHART_COLORS.muted;
    });

    chartGrowth = new Chart(document.getElementById("chart-growth"), {
      type: "bar",
      data: {
        labels: growthLabels,
        datasets: [{
          label: "Slope",
          data: growthSlopes,
          backgroundColor: growthColors,
          borderColor: "rgba(255, 255, 255, 0.1)",
          borderWidth: 1,
          borderRadius: 6,
        }],
      },
      options: {
        indexAxis: "y",
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              title: function (items) {
                if (!items || !items.length) return "";
                return growthLabels[items[0].dataIndex] || "";
              },
              label: function (ctx) {
                var domain = growthLabels[ctx.dataIndex];
                var g = growthInfo[domain] || {};
                return "Slope: " + (g.slope != null ? g.slope.toFixed(3) : "—") + ", R²: " + (g.r2 != null ? g.r2.toFixed(3) : "—");
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
          y: { grid: { display: false }, ticks: { display: false } },
        },
      },
    });

    // Scatter: all 20 domains; predicted = large accent, others = small muted
    var predSet = {};
    allDomains.forEach(function (d) { predSet[d] = true; });
    var scatterPred = [];
    var scatterOther = [];
    allDomainNames.forEach(function (domain) {
      var conf = domainConfidence[domain] || 0;
      var g = growthInfo[domain] || {};
      var normSlope = Math.min(1, Math.max(0, (g.slope || 0)));
      var point = { x: conf, y: normSlope, label: domain };
      if (predSet[domain]) scatterPred.push(point);
      else scatterOther.push(point);
    });

    chartScatter = new Chart(document.getElementById("chart-scatter"), {
      type: "scatter",
      data: {
        datasets: [
          {
            label: "Predicted",
            data: scatterPred,
            backgroundColor: CHART_COLORS.accent,
            borderColor: "rgba(46, 196, 182, 0.6)",
            borderWidth: 2,
            pointRadius: 10,
            pointHoverRadius: 12,
          },
          {
            label: "Other domains",
            data: scatterOther,
            backgroundColor: CHART_COLORS.muted,
            borderColor: "rgba(139, 141, 152, 0.5)",
            borderWidth: 1,
            pointRadius: 5,
            pointHoverRadius: 7,
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
                var g = growthInfo[domain] || {};
                return domain + " — conf: " + (p.x * 100).toFixed(1) + "%, slope: " + ((g.slope || 0).toFixed(3)) + ", R²: " + ((g.r2 || 0).toFixed(3));
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

  function abbreviateDomain(domain) {
    if (!domain || typeof domain !== "string") return "N/A";
    var words = domain.split(/[\s\/_-]+/).filter(Boolean);
    if (words.length >= 2) {
      return words.map(function (w) { return w.charAt(0).toUpperCase(); }).join("").slice(0, 5);
    }
    if (domain.length <= 8) return domain.toUpperCase();
    return domain.slice(0, 8).toUpperCase();
  }

  function r2FitLabel(r2) {
    if (r2 == null || typeof r2 !== "number") return "—";
    if (r2 >= 0.5) return "Strong fit";
    if (r2 >= 0.25) return "Moderate";
    return "Weak";
  }

  function slopeDirectionClass(slope) {
    if (slope == null || typeof slope !== "number") return "growth-slope-muted";
    if (slope > 0.3) return "growth-slope-up";
    if (slope > 0.1) return "growth-slope-moderate";
    return "growth-slope-muted";
  }

  function renderResult(data) {
    hideError();
    resultSection.classList.remove("hidden");
    vizSection.classList.remove("hidden");
    buildCharts(data);

    var primaryDomain = data.primary_domain || data.domain || "Primary";
    var allDomains = data.all_domains || [primaryDomain];
    var domainConfidence = data.domain_confidence || {};
    var growthInfo = data.growth_info || {};
    var allDomainNames = Object.keys(domainConfidence);
    var sortedByConf = allDomainNames.slice().sort(function (a, b) {
      return (domainConfidence[b] || 0) - (domainConfidence[a] || 0);
    });

    // ——— Numbers at a glance: stat tiles ———
    if (vizNumbers) {
      var topSlopeDomain = null;
      var topSlope = -Infinity;
      var bestR2Domain = null;
      var bestR2 = -Infinity;
      var confSum = 0;
      allDomains.forEach(function (d) {
        var conf = domainConfidence[d] || 0;
        confSum += conf;
        var g = growthInfo[d] || {};
        if (g.slope != null && g.slope > topSlope) {
          topSlope = g.slope;
          topSlopeDomain = d;
        }
        if (g.r2 != null && g.r2 > bestR2) {
          bestR2 = g.r2;
          bestR2Domain = d;
        }
      });
      var avgConf = allDomains.length ? confSum / allDomains.length : 0;
      var primaryShort = abbreviateDomain(primaryDomain);
      var topGrowthDomain = topSlopeDomain ? escapeHtml(topSlopeDomain) : "—";
      var bestFitDomain = bestR2Domain ? escapeHtml(bestR2Domain) : "—";
      vizNumbers.innerHTML =
        "<p class=\"viz-numbers-title\">Numbers at a glance</p>" +
        "<div class=\"viz-stat-layout\">" +
        "<div class=\"viz-stat-tile viz-stat-tile-primary\">" +
        "<span class=\"viz-stat-label\">Primary</span>" +
        "<span class=\"viz-stat-primary-code\">" + escapeHtml(primaryShort) + "</span>" +
        "<span class=\"viz-stat-primary-name\">" + escapeHtml(primaryDomain) + "</span>" +
        "<span class=\"viz-stat-primary-confidence\">" + formatPercent(domainConfidence[primaryDomain] || 0) + "</span>" +
        "<span class=\"viz-stat-meta\">confidence</span>" +
        "</div>" +
        "<div class=\"viz-stat-tile viz-stat-tile-top-growth\">" +
        "<span class=\"viz-stat-label\">Top growth</span>" +
        "<span class=\"viz-stat-value viz-num-growth\">" + topGrowthDomain + "</span>" +
        "<span class=\"viz-stat-meta\">slope " + (topSlope !== -Infinity ? topSlope.toFixed(3) : "—") + "</span>" +
        "</div>" +
        "<div class=\"viz-stat-tile viz-stat-tile-domains\">" +
        "<span class=\"viz-stat-label\">Domains</span>" +
        "<span class=\"viz-stat-value\">" + allDomains.length + "</span>" +
        "<span class=\"viz-stat-meta\">predicted</span>" +
        "</div>" +
        "<div class=\"viz-stat-tile viz-stat-tile-summary\">" +
        "<div class=\"viz-stat-summary-item\">" +
        "<span class=\"viz-stat-label\">Best R² fit</span>" +
        "<span class=\"viz-stat-value\">" + bestFitDomain + " — " + (bestR2 !== -Infinity ? bestR2.toFixed(3) : "—") + "</span>" +
        "</div>" +
        "<div class=\"viz-stat-summary-item viz-stat-summary-item-right\">" +
        "<span class=\"viz-stat-label\">Avg confidence</span>" +
        "<span class=\"viz-stat-value\">" + formatPercent(avgConf) + "</span>" +
        "</div>" +
        "</div>" +
        "</div>";
    }

    // ——— Domain card: hero + predicted rows + all-domain landscape ———
    resultDomain.innerHTML = "";
    var mainConf = domainConfidence[primaryDomain] || 0;
    var hero = document.createElement("div");
    hero.className = "domain-hero";
    hero.innerHTML =
      "<div class=\"domain-hero-ring-wrap\" aria-hidden=\"true\"><div class=\"domain-hero-ring\" style=\"--conf:" + mainConf + "\"></div><span class=\"domain-hero-ring-value\">" + formatPercent(mainConf) + "</span></div>" +
      "<div class=\"domain-hero-text\"><h3 class=\"domain-name\">" + escapeHtml(primaryDomain) + "</h3><p class=\"domain-hero-sub\">Primary classification</p></div>";
    resultDomain.appendChild(hero);

    var predSection = document.createElement("div");
    predSection.className = "domain-predicted";
    var predTitle = document.createElement("p");
    predTitle.className = "alternates-title";
    predTitle.textContent = "Predicted domains";
    predSection.appendChild(predTitle);
    var predList = document.createElement("div");
    predList.className = "domain-predicted-list";
    allDomains.forEach(function (domain) {
      var conf = domainConfidence[domain] || 0;
      var gInfo = growthInfo[domain] || {};
      var slopeStr = gInfo.slope != null ? gInfo.slope.toFixed(3) : "—";
      var slopeClass = slopeDirectionClass(gInfo.slope);
      var isPrimary = domain === primaryDomain;
      var row = document.createElement("div");
      row.className = "domain-predicted-row" + (isPrimary ? " domain-predicted-row-primary" : "");
      row.innerHTML =
        "<span class=\"domain-predicted-name\">" + escapeHtml(domain) + (isPrimary ? " <span class=\"domain-badge-primary\">primary</span>" : "") + "</span>" +
        "<div class=\"domain-predicted-bar-wrap\"><div class=\"domain-predicted-bar\" style=\"width:" + (conf * 100) + "%\"></div></div>" +
        "<span class=\"domain-predicted-conf\">" + formatPercent(conf) + "</span>" +
        "<span class=\"growth-badge " + slopeClass + "\" title=\"Slope: " + slopeStr + "\">" + slopeStr + "</span>";
      predList.appendChild(row);
    });
    predSection.appendChild(predList);
    resultDomain.appendChild(predSection);

    var landscapeSection = document.createElement("div");
    landscapeSection.className = "domain-landscape";
    var landscapeToggle = document.createElement("button");
    landscapeToggle.type = "button";
    landscapeToggle.className = "domain-landscape-toggle";
    landscapeToggle.setAttribute("aria-expanded", "false");
    landscapeToggle.textContent = "All domain scores";
    var landscapeList = document.createElement("div");
    landscapeList.className = "domain-landscape-list hidden";
    landscapeList.setAttribute("role", "region");
    landscapeList.setAttribute("aria-label", "All 20 domain confidence scores");
    sortedByConf.forEach(function (domain) {
      var conf = domainConfidence[domain] || 0;
      var isPred = allDomains.indexOf(domain) !== -1;
      var row = document.createElement("div");
      row.className = "domain-landscape-row" + (isPred ? " domain-landscape-row-predicted" : "");
      row.innerHTML =
        "<span class=\"domain-landscape-name\">" + escapeHtml(domain) + "</span>" +
        "<div class=\"domain-landscape-bar-wrap\"><div class=\"domain-landscape-bar\" style=\"width:" + (conf * 100) + "%\"></div></div>" +
        "<span class=\"domain-landscape-conf\">" + formatPercent(conf) + "</span>";
      landscapeList.appendChild(row);
    });
    landscapeToggle.addEventListener("click", function () {
      landscapeList.classList.toggle("hidden");
      landscapeToggle.setAttribute("aria-expanded", String(!landscapeList.classList.contains("hidden")));
    });
    landscapeSection.appendChild(landscapeToggle);
    landscapeSection.appendChild(landscapeList);
    resultDomain.appendChild(landscapeSection);

    // ——— Growth card: per-domain rows with slope + R² ———
    resultGrowth.innerHTML = "";
    var growthTitle = document.createElement("p");
    growthTitle.className = "growth-label";
    growthTitle.textContent = "Growth Trends";
    resultGrowth.appendChild(growthTitle);
    var growthList = document.createElement("div");
    growthList.className = "growth-trends-list";
    allDomains.forEach(function (domain) {
      var gInfo = growthInfo[domain] || {};
      var slope = gInfo.slope;
      var r2 = gInfo.r2;
      var slopeStr = slope != null ? slope.toFixed(3) : "—";
      var r2Str = r2 != null ? r2.toFixed(3) : "—";
      var r2Pct = r2 != null ? Math.min(100, r2 * 100) : 0;
      var row = document.createElement("div");
      row.className = "growth-trend-row";
      row.innerHTML =
        "<span class=\"growth-trend-domain\">" + escapeHtml(domain) + "</span>" +
        "<div class=\"growth-trend-metrics\">" +
        "<span class=\"growth-score-wrap " + slopeDirectionClass(slope) + "\"><span class=\"growth-trend-slope-label\">Slope</span><span class=\"growth-score-value\">" + slopeStr + "</span></span>" +
        "<div class=\"growth-trend-r2\"><span class=\"growth-trend-r2-label\">R² " + r2FitLabel(r2) + "</span><div class=\"growth-trend-r2-bar-wrap\"><div class=\"growth-trend-r2-bar\" style=\"width:" + r2Pct + "%\"></div></div><span class=\"growth-trend-r2-value\">" + r2Str + "</span></div>" +
        "</div>";
      growthList.appendChild(row);
    });
    resultGrowth.appendChild(growthList);

    // ——— Model info card: 2-column metric tiles ———
    if (resultModelInfo) {
      resultModelInfo.innerHTML = "";
      var modelInfo = data.model_info || {};
      if (Object.keys(modelInfo).length > 0) {
        resultModelInfo.classList.remove("hidden");
        var modelTitle = document.createElement("p");
        modelTitle.className = "model-info-title";
        modelTitle.textContent = "Model Performance Metrics";
        resultModelInfo.appendChild(modelTitle);
        var tiles = document.createElement("div");
        tiles.className = "model-metrics-grid";
        var metrics = [
          { key: "subset_accuracy", label: "Subset Accuracy" },
          { key: "hamming_loss", label: "Hamming Loss" },
          { key: "macro_f1", label: "Macro F1" },
          { key: "micro_f1", label: "Micro F1" },
          { key: "samples_f1", label: "Samples F1" },
          { key: "cv_micro_f1_mean", label: "CV Micro F1 (mean)" },
          { key: "cv_micro_f1_std", label: "CV Micro F1 (std)" }
        ];
        metrics.forEach(function (m) {
          if (modelInfo[m.key] == null) return;
          var tile = document.createElement("div");
          tile.className = "model-metric-tile";
          tile.innerHTML = "<span class=\"model-metric-label\">" + m.label + "</span><span class=\"model-metric-value\">" + modelInfo[m.key].toFixed(4) + "</span>";
          tiles.appendChild(tile);
        });
        resultModelInfo.appendChild(tiles);
      } else {
        resultModelInfo.classList.add("hidden");
      }
    }
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
