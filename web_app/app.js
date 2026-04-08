(function () {
  const API_BASE =
    document.documentElement.dataset.apiBase ||
    "https://eidon-api-001.onrender.com";

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
      abstract:
        "We propose a new architecture based entirely on self-attention mechanisms, dispensing with recurrence and convolutions. The Transformer achieves state-of-the-art results on machine translation and scales effectively to large datasets.",
    },
    2: {
      title: "Neural Radiance Fields for View Synthesis and 3D Reconstruction",
      abstract:
        "We present a method that represents a scene as a continuous 5D function and uses volume rendering to synthesize novel views. By optimizing a fully-connected neural network without convolutional layers, we achieve high-resolution photorealistic results.",
    },
  };

  const form = document.getElementById("advise-form");
  const submitBtn = document.getElementById("submit-btn");
  const enableCompareInput = document.getElementById("enable-compare");
  const compareInputsSection = document.querySelector(".compare-inputs");
  const statusEl = document.getElementById("status");
  const resultSection = document.getElementById("result");
  const vizSection = document.getElementById("viz-section");
  const vizNumbers = document.getElementById("viz-numbers");
  const resultOverview = document.getElementById("result-overview");
  const resultDomain = document.getElementById("result-domain");
  const resultGrowth = document.getElementById("result-growth");
  const resultAdvisory = document.getElementById("result-advisory");
  const resultSimilar = document.getElementById("result-similar");
  const resultCompare = document.getElementById("result-compare");
  const resultTabsBar = document.querySelector(".result-tabs");
  const resultHeading = document.querySelector(".result-heading");
  const resultTabButtons = Array.prototype.slice.call(
    document.querySelectorAll(".result-tab")
  );
  const resultTabPanels = Array.prototype.slice.call(
    document.querySelectorAll(".result-panel")
  );
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

  function escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text == null ? "" : String(text);
    return div.innerHTML;
  }

  function formatPercent(value) {
    if (typeof value !== "number") return String(value);
    return (value * 100).toFixed(1) + "%";
  }

  function formatScoreOutOf10(value) {
    if (typeof value !== "number" || Number.isNaN(value)) return "—";
    return value.toFixed(2) + " / 10";
  }

  function signalLabel(signal) {
    if (!signal) return "No signal";
    return String(signal).replace(/_/g, " ");
  }

  function abbreviateDomain(domain) {
    if (!domain || typeof domain !== "string") return "N/A";
    var words = domain.split(/[\s\/_-]+/).filter(Boolean);
    if (words.length >= 2) {
      return words
        .map(function (w) {
          return w.charAt(0).toUpperCase();
        })
        .join("")
        .slice(0, 5);
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

  function setLoading(loading) {
    submitBtn.disabled = loading;
    const actions = form.querySelector(".form-actions");
    if (loading) {
      actions.classList.add("is-loading");
      statusEl.textContent = "Calling advisor...";
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

  function setCompareInputsVisible(show) {
    if (!compareInputsSection) return;
    var compareFields = compareInputsSection.querySelectorAll("input, textarea");
    compareInputsSection.classList.toggle("hidden", !show);
    compareInputsSection.setAttribute("aria-hidden", show ? "false" : "true");
    compareFields.forEach(function (field) {
      field.disabled = !show;
    });
  }

  if (enableCompareInput) {
    setCompareInputsVisible(enableCompareInput.checked);
    enableCompareInput.addEventListener("change", function () {
      setCompareInputsVisible(enableCompareInput.checked);
    });
  }

  function activateResultTab(tabName) {
    resultTabButtons.forEach(function (button) {
      var isActive = button.getAttribute("data-tab-target") === tabName;
      button.classList.toggle("is-active", isActive);
      button.setAttribute("aria-selected", isActive ? "true" : "false");
      button.tabIndex = isActive ? 0 : -1;
    });
    resultTabPanels.forEach(function (panel) {
      var isActive = panel.getAttribute("data-tab-panel") === tabName;
      panel.classList.toggle("is-active", isActive);
      panel.hidden = !isActive;
    });
  }

  resultTabButtons.forEach(function (button) {
    button.addEventListener("click", function () {
      activateResultTab(button.getAttribute("data-tab-target"));
    });
  });

  function buildCharts(data) {
    destroyCharts();
    if (typeof Chart === "undefined") return;

    var primaryDomain = data.primary_domain || data.domain || "Primary";
    var allDomains = data.all_domains || [primaryDomain];
    var domainConfidence = data.domain_confidence || {};
    var growthInfo = data.growth_info || {};
    var allDomainNames = Object.keys(domainConfidence);

    var top10 = allDomainNames
      .slice()
      .sort(function (a, b) {
        return (domainConfidence[b] || 0) - (domainConfidence[a] || 0);
      })
      .slice(0, 10);

    var confLabels = top10;
    var confValues = top10.map(function (d) {
      return domainConfidence[d] || 0;
    });
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
        datasets: [
          {
            label: "Confidence",
            data: confValues,
            backgroundColor: confColors,
            borderColor: confBorders,
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
            ticks: {
              color: CHART_COLORS.text,
              callback: function (v) {
                return (v * 100).toFixed(0) + "%";
              },
            },
          },
          y: { grid: { display: false }, ticks: { display: false } },
        },
      },
    });

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
        datasets: [
          {
            label: "Slope",
            data: growthSlopes,
            backgroundColor: growthColors,
            borderColor: "rgba(255, 255, 255, 0.1)",
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
              title: function (items) {
                if (!items || !items.length) return "";
                return growthLabels[items[0].dataIndex] || "";
              },
              label: function (ctx) {
                var domain = growthLabels[ctx.dataIndex];
                var g = growthInfo[domain] || {};
                return (
                  "Slope: " +
                  (g.slope != null ? g.slope.toFixed(3) : "—") +
                  ", R²: " +
                  (g.r2 != null ? g.r2.toFixed(3) : "—")
                );
              },
            },
          },
        },
        scales: {
          x: {
            min: 0,
            max: 1,
            grid: { color: CHART_COLORS.grid },
            ticks: {
              color: CHART_COLORS.text,
              callback: function (v) {
                return (v * 100).toFixed(0) + "%";
              },
            },
          },
          y: { grid: { display: false }, ticks: { display: false } },
        },
      },
    });

    var predSet = {};
    allDomains.forEach(function (d) {
      predSet[d] = true;
    });
    var scatterPred = [];
    var scatterOther = [];
    allDomainNames.forEach(function (domain) {
      var conf = domainConfidence[domain] || 0;
      var g = growthInfo[domain] || {};
      var normSlope = Math.min(1, Math.max(0, g.slope || 0));
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
            labels: {
              color: CHART_COLORS.text,
              usePointStyle: true,
              padding: 12,
            },
          },
          tooltip: {
            callbacks: {
              label: function (ctx) {
                var p = ctx.raw;
                var domain = p.label || "Point";
                var g = growthInfo[domain] || {};
                return (
                  domain +
                  " — conf: " +
                  (p.x * 100).toFixed(1) +
                  "%, slope: " +
                  (g.slope || 0).toFixed(3) +
                  ", R²: " +
                  (g.r2 || 0).toFixed(3)
                );
              },
            },
          },
        },
        scales: {
          x: {
            title: {
              display: true,
              text: "Confidence",
              color: CHART_COLORS.text,
            },
            min: 0,
            max: 1,
            grid: { color: CHART_COLORS.grid },
            ticks: {
              color: CHART_COLORS.text,
              callback: function (v) {
                return (v * 100).toFixed(0) + "%";
              },
            },
          },
          y: {
            title: {
              display: true,
              text: "Growth (normalized slope)",
              color: CHART_COLORS.text,
            },
            min: 0,
            max: 1,
            grid: { color: CHART_COLORS.grid },
            ticks: {
              color: CHART_COLORS.text,
              callback: function (v) {
                return (v * 100).toFixed(0) + "%";
              },
            },
          },
        },
      },
    });
  }

  function renderNumbers(primaryDomain, allDomains, domainConfidence, growthInfo) {
    if (!vizNumbers) return;
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
      "<span class=\"viz-stat-primary-code\">" +
      escapeHtml(primaryShort) +
      "</span>" +
      "<span class=\"viz-stat-primary-name\">" +
      escapeHtml(primaryDomain) +
      "</span>" +
      "<span class=\"viz-stat-primary-confidence\">" +
      formatPercent(domainConfidence[primaryDomain] || 0) +
      "</span>" +
      "<span class=\"viz-stat-meta\">confidence</span>" +
      "</div>" +
      "<div class=\"viz-stat-tile viz-stat-tile-top-growth\">" +
      "<span class=\"viz-stat-label\">Top growth</span>" +
      "<span class=\"viz-stat-value viz-num-growth\">" +
      topGrowthDomain +
      "</span>" +
      "<span class=\"viz-stat-meta\">slope " +
      (topSlope !== -Infinity ? topSlope.toFixed(3) : "—") +
      "</span>" +
      "</div>" +
      "<div class=\"viz-stat-tile viz-stat-tile-domains\">" +
      "<span class=\"viz-stat-label\">Domains</span>" +
      "<span class=\"viz-stat-value\">" +
      allDomains.length +
      "</span>" +
      "<span class=\"viz-stat-meta\">predicted</span>" +
      "</div>" +
      "<div class=\"viz-stat-tile viz-stat-tile-summary\">" +
      "<div class=\"viz-stat-summary-item\">" +
      "<span class=\"viz-stat-label\">Best R² fit</span>" +
      "<span class=\"viz-stat-value\">" +
      bestFitDomain +
      " — " +
      (bestR2 !== -Infinity ? bestR2.toFixed(3) : "—") +
      "</span>" +
      "</div>" +
      "<div class=\"viz-stat-summary-item viz-stat-summary-item-right\">" +
      "<span class=\"viz-stat-label\">Avg confidence</span>" +
      "<span class=\"viz-stat-value\">" +
      formatPercent(avgConf) +
      "</span>" +
      "</div>" +
      "</div>" +
      "</div>";
  }

  function renderDomainCard(
    primaryDomain,
    allDomains,
    domainConfidence,
    growthInfo,
    sortedByConf
  ) {
    resultDomain.innerHTML = "";
    var mainConf = domainConfidence[primaryDomain] || 0;
    var hero = document.createElement("div");
    hero.className = "domain-hero";
    hero.innerHTML =
      "<div class=\"domain-hero-ring-wrap\" aria-hidden=\"true\"><div class=\"domain-hero-ring\" style=\"--conf:" +
      mainConf +
      "\"></div><span class=\"domain-hero-ring-value\">" +
      formatPercent(mainConf) +
      "</span></div>" +
      "<div class=\"domain-hero-text\"><h3 class=\"domain-name\">" +
      escapeHtml(primaryDomain) +
      "</h3><p class=\"domain-hero-sub\">Primary classification</p></div>";
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
      row.className =
        "domain-predicted-row" + (isPrimary ? " domain-predicted-row-primary" : "");
      row.innerHTML =
        "<span class=\"domain-predicted-name\">" +
        escapeHtml(domain) +
        (isPrimary ? " <span class=\"domain-badge-primary\">primary</span>" : "") +
        "</span>" +
        "<div class=\"domain-predicted-bar-wrap\"><div class=\"domain-predicted-bar\" style=\"width:" +
        conf * 100 +
        "%\"></div></div>" +
        "<span class=\"domain-predicted-conf\">" +
        formatPercent(conf) +
        "</span>" +
        "<span class=\"growth-badge " +
        slopeClass +
        "\" title=\"Slope: " +
        slopeStr +
        "\">" +
        slopeStr +
        "</span>";
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
    landscapeList.setAttribute("aria-label", "All domain confidence scores");
    sortedByConf.forEach(function (domain) {
      var conf = domainConfidence[domain] || 0;
      var isPred = allDomains.indexOf(domain) !== -1;
      var row = document.createElement("div");
      row.className =
        "domain-landscape-row" + (isPred ? " domain-landscape-row-predicted" : "");
      row.innerHTML =
        "<span class=\"domain-landscape-name\">" +
        escapeHtml(domain) +
        "</span>" +
        "<div class=\"domain-landscape-bar-wrap\"><div class=\"domain-landscape-bar\" style=\"width:" +
        conf * 100 +
        "%\"></div></div>" +
        "<span class=\"domain-landscape-conf\">" +
        formatPercent(conf) +
        "</span>";
      landscapeList.appendChild(row);
    });
    landscapeToggle.addEventListener("click", function () {
      landscapeList.classList.toggle("hidden");
      landscapeToggle.setAttribute(
        "aria-expanded",
        String(!landscapeList.classList.contains("hidden"))
      );
    });
    landscapeSection.appendChild(landscapeToggle);
    landscapeSection.appendChild(landscapeList);
    resultDomain.appendChild(landscapeSection);
  }

  function renderGrowthCard(allDomains, growthInfo) {
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
        "<span class=\"growth-trend-domain\">" +
        escapeHtml(domain) +
        "</span>" +
        "<div class=\"growth-trend-metrics\">" +
        "<span class=\"growth-score-wrap " +
        slopeDirectionClass(slope) +
        "\"><span class=\"growth-trend-slope-label\">Slope</span><span class=\"growth-score-value\">" +
        slopeStr +
        "</span></span>" +
        "<div class=\"growth-trend-r2\"><span class=\"growth-trend-r2-label\">R² " +
        r2FitLabel(r2) +
        "</span><div class=\"growth-trend-r2-bar-wrap\"><div class=\"growth-trend-r2-bar\" style=\"width:" +
        r2Pct +
        "%\"></div></div><span class=\"growth-trend-r2-value\">" +
        r2Str +
        "</span></div>" +
        "</div>";
      growthList.appendChild(row);
    });
    resultGrowth.appendChild(growthList);
  }

  function renderAdvisoryCard(data) {
    var advisory = data.advisory || {};
    var narrative = advisory.narrative || {};

    function narrativeSection(label, content) {
      if (!content) return "";
      return (
        "<div class=\"narrative-section\">" +
        "<p class=\"narrative-label\">" + escapeHtml(label) + "</p>" +
        "<p class=\"narrative-body\">" + escapeHtml(content) + "</p>" +
        "</div>"
      );
    }

    var positionList = "";
    if (Array.isArray(narrative.how_to_position) && narrative.how_to_position.length) {
      positionList =
        "<div class=\"narrative-section\">" +
        "<p class=\"narrative-label\">How to position it</p>" +
        "<ul class=\"narrative-list\">" +
        narrative.how_to_position.map(function (item) {
          return "<li>" + escapeHtml(item) + "</li>";
        }).join("") +
        "</ul></div>";
    }

    resultAdvisory.innerHTML =
      "<p class=\"advisory-title\">Insights</p>" +
      narrativeSection("Why this fits", narrative.why_this_fits) +
      narrativeSection("Where it stands right now", narrative.where_it_stands) +
      narrativeSection("Where it\u2019s going", narrative.where_its_going) +
      positionList +
      narrativeSection("Supporting signals", narrative.supporting_signals);
  }

  var BREAKDOWN_META = {
    semantic_alignment:  { label: "Semantic Alignment",   desc: "How well your idea aligns with existing research" },
    growth_trajectory:   { label: "Growth Trajectory",    desc: "Growth momentum of the domain" },
    cluster_density:     { label: "Competition Level",    desc: "How crowded the research cluster is" },
    cross_domain_potential: { label: "Cross-domain Reach", desc: "How many research communities this touches" },
  };

  var BREAKDOWN_LEVEL_CLASS = {
    "Strong": "breakdown-level-high",
    "High": "breakdown-level-high",
    "Low saturation": "breakdown-level-high",
    "Emerging": "breakdown-level-mid",
    "Moderate": "breakdown-level-mid",
    "Narrow": "breakdown-level-mid",
    "Weak": "breakdown-level-low",
    "Slow": "breakdown-level-low",
    "High saturation": "breakdown-level-low",
    "Unknown": "breakdown-level-muted",
  };

  function renderOverviewCard(data) {
    var advisory = data.advisory || {};
    var signal = advisory.signal_type || data.signal_type;
    var growthScore = advisory.growth_score || data.domain_growth_score;
    var breakdown = advisory.score_breakdown || {};

    var breakdownHtml = "";
    if (Object.keys(breakdown).length) {
      var tiles = Object.keys(BREAKDOWN_META).map(function (key) {
        var meta = BREAKDOWN_META[key];
        var factor = breakdown[key] || {};
        var level = factor.level || "—";
        var detail = factor.detail || "";
        var levelClass = BREAKDOWN_LEVEL_CLASS[level] || "breakdown-level-muted";
        return (
          "<div class=\"breakdown-tile\">" +
          "<span class=\"breakdown-factor\">" + escapeHtml(meta.label) + "</span>" +
          "<span class=\"breakdown-level " + levelClass + "\">" + escapeHtml(level) + "</span>" +
          "<span class=\"breakdown-detail\">" + escapeHtml(detail) + "</span>" +
          "</div>"
        );
      }).join("");

      var tips = advisory.improvement_tips;
      var tipsHtml = "";
      if (Array.isArray(tips) && tips.length) {
        tipsHtml =
          "<div class=\"overview-tips\">" +
          "<p class=\"overview-tips-title\">What would improve this idea?</p>" +
          "<p class=\"overview-tips-sub\">To increase your score:</p>" +
          "<ul class=\"overview-tips-list\">" +
          tips.map(function (t) { return "<li>" + escapeHtml(t) + "</li>"; }).join("") +
          "</ul>" +
          "</div>";
      }

      breakdownHtml =
        "<div class=\"overview-breakdown\">" +
        "<p class=\"overview-breakdown-title\">Why this score</p>" +
        "<div class=\"breakdown-grid\">" + tiles + "</div>" +
        "</div>" +
        tipsHtml;
    }

    resultOverview.innerHTML =
      "<p class=\"advisory-title\">Overview</p>" +
      "<div class=\"advisory-grid\">" +
      "<div class=\"advisory-item\"><span class=\"advisory-label\">Opportunity score</span><span class=\"advisory-value\">" +
      formatScoreOutOf10(advisory.opportunity_score || data.opportunity_score) +
      "</span></div>" +
      "<div class=\"advisory-item\"><span class=\"advisory-label\">Signal</span><span class=\"advisory-value advisory-signal\">" +
      escapeHtml(signalLabel(signal)) +
      "</span></div>" +
      "<div class=\"advisory-item\"><span class=\"advisory-label\">Growth score</span><span class=\"advisory-value\">" +
      formatPercent(growthScore || 0) +
      "</span></div>" +
      "</div>" +
      breakdownHtml;
  }

  function renderSimilarPapers(data) {
    var papers = Array.isArray(data.similar_papers) ? data.similar_papers : [];
    var similarityNote = data.similarity_note
      ? escapeHtml(data.similarity_note)
      : "Pinecone similarity is not connected right now.";
    if (!papers.length) {
      resultSimilar.innerHTML =
        "<p class=\"advisory-title\">Top similar papers</p><p class=\"advisory-text\">" +
        similarityNote +
        "</p>";
      return;
    }

    resultSimilar.innerHTML =
      "<p class=\"advisory-title\">Top similar papers</p>" +
      "<div class=\"similar-list\">" +
      papers
        .map(function (paper) {
          var link = paper.link || "#";
          var meta = [
            paper.year ? escapeHtml(paper.year) : "year n/a",
            paper.domain ? escapeHtml(paper.domain) : "domain n/a",
            "sim " + formatPercent(paper.similarity_score || 0),
          ].join(" • ");
          return (
            "<div class=\"similar-item\">" +
            "<a class=\"similar-title\" href=\"" +
            escapeHtml(link) +
            "\" target=\"_blank\" rel=\"noopener\">" +
            escapeHtml(paper.title || "Untitled paper") +
            "</a>" +
            "<p class=\"similar-meta\">" +
            meta +
            "</p>" +
            "</div>"
          );
        })
        .join("") +
      "</div>";
  }

  function renderCompareSection(compareData) {
    if (!compareData || !compareData.idea_a_result || !compareData.idea_b_result) {
      resultCompare.classList.add("hidden");
      resultCompare.innerHTML = "";
      return;
    }

    function compareCard(result, label) {
      var advisory = result.advisory || {};
      var opp = formatScoreOutOf10(advisory.opportunity_score || result.opportunity_score);
      var sig = escapeHtml(signalLabel(advisory.signal_type || result.signal_type));
      var growth = formatPercent(advisory.growth_score || result.domain_growth_score || 0);
      return (
        "<div class=\"compare-card-new\">" +
        "<p class=\"compare-card-title\">" + escapeHtml(label) + "</p>" +
        "<div class=\"compare-card-row\"><span class=\"compare-card-label\">Opportunity</span><span class=\"compare-card-value\">" + opp + "</span></div>" +
        "<div class=\"compare-card-row\"><span class=\"compare-card-label\">Signal</span><span class=\"compare-card-value\">" + sig + "</span></div>" +
        "<div class=\"compare-card-row\"><span class=\"compare-card-label\">Growth</span><span class=\"compare-card-value\">" + growth + "</span></div>" +
        "</div>"
      );
    }

    resultCompare.classList.remove("hidden");
    resultCompare.innerHTML =
      "<p class=\"compare-heading\">Idea Comparison</p>" +
      "<div class=\"compare-cards-grid\">" +
      compareCard(compareData.idea_a_result, "Idea A") +
      compareCard(compareData.idea_b_result, "Idea B") +
      "</div>" +
      "<p class=\"compare-verdict-new\">" +
      escapeHtml(compareData.final_verdict || "Comparison complete.") +
      "</p>";
  }

  function renderResult(data, compareData) {
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

    if (compareData) {
      resultOverview.innerHTML = "";
      resultOverview.style.display = "none";
      if (resultTabsBar) resultTabsBar.style.display = "none";
      if (resultHeading) resultHeading.style.display = "none";
    } else {
      resultOverview.style.display = "";
      if (resultTabsBar) resultTabsBar.style.display = "";
      if (resultHeading) resultHeading.style.display = "";
      renderOverviewCard(data);
    }
    renderNumbers(primaryDomain, allDomains, domainConfidence, growthInfo);
    renderDomainCard(primaryDomain, allDomains, domainConfidence, growthInfo, sortedByConf);
    renderGrowthCard(allDomains, growthInfo);
    renderAdvisoryCard(data);
    renderSimilarPapers(data);
    renderCompareSection(compareData);
    activateResultTab("overview");
  }

  function callApi(path, payload) {
    return fetch(API_BASE + path, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    }).then(function (res) {
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
    });
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
    const titleA = (form.querySelector("#title") || form.querySelector('[name="title"]')).value.trim();
    const abstractA = (form.querySelector("#abstract") || form.querySelector('[name="abstract"]')).value.trim();
    const titleB = (form.querySelector("#title-b") || form.querySelector('[name="title_b"]')).value.trim();
    const abstractB = (form.querySelector("#abstract-b") || form.querySelector('[name="abstract_b"]')).value.trim();

    if (!titleA || !abstractA) {
      showError("Please enter title and abstract for Idea A.");
      return;
    }

    const hasIdeaB = Boolean(enableCompareInput && enableCompareInput.checked);
    if (hasIdeaB && (!titleB || !abstractB)) {
      showError("Please provide both title and abstract for Idea B.");
      return;
    }

    setLoading(true);
    const request = hasIdeaB
      ? callApi("/api/v1/advisor/compare", {
          idea_a: { title: titleA, abstract: abstractA },
          idea_b: { title: titleB, abstract: abstractB },
        }).then(function (compareData) {
          renderResult(compareData.idea_a_result, compareData);
          statusEl.textContent = "Comparison complete.";
        })
      : callApi("/api/v1/advisor/advise", {
          title: titleA,
          abstract: abstractA,
        }).then(function (data) {
          renderResult(data, null);
          statusEl.textContent = "Done.";
        });

    request
      .catch(function (err) {
        showError(err.message || "Something went wrong. Check the API URL and try again.");
      })
      .finally(function () {
        setLoading(false);
      });
  });
})();
