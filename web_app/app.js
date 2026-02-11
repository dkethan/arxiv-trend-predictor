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
  const resultKeywords = document.getElementById("result-keywords");
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

    const mainConf = Number(data.domain_confidence) || 0;
    const growth = Number(data.domain_growth_score);
    const alternates = data.alternate_domains || [];
    const altLabels = alternates.map(function (item) {
      return Array.isArray(item) ? item[0] : item.domain;
    });
    const altConfs = alternates.map(function (item) {
      return Array.isArray(item) ? item[1] : item.confidence;
    });

    var labels = [data.domain || "Primary"].concat(altLabels);
    var confValues = [mainConf].concat(altConfs);
    var bgColors = [CHART_COLORS.accentRgba].concat(
      altLabels.map(function () {
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
            borderColor: [CHART_COLORS.accent].concat(altLabels.map(function () { return "rgba(139,141,152,0.4)"; })),
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

    var growthVal = typeof growth === "number" && !isNaN(growth) ? growth : 0;
    chartGrowth = new Chart(document.getElementById("chart-growth"), {
      type: "bar",
      data: {
        labels: ["Growth score"],
        datasets: [
          {
            label: "Score",
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
                return " " + (ctx.raw * 100).toFixed(1) + "% of scale";
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

    var scatterPoints = [{ x: mainConf, y: growthVal, label: data.domain || "Primary" }];
    alternates.forEach(function (item, i) {
      var c = Array.isArray(item) ? item[1] : item.confidence;
      scatterPoints.push({ x: c, y: 0, label: altLabels[i] || "Alt" });
    });

    chartScatter = new Chart(document.getElementById("chart-scatter"), {
      type: "scatter",
      data: {
        datasets: [
          {
            label: data.domain || "Primary",
            data: scatterPoints.filter(function (_, i) { return i === 0; }),
            backgroundColor: CHART_COLORS.accent,
            borderColor: "rgba(46, 196, 182, 0.6)",
            borderWidth: 2,
            pointRadius: 10,
            pointHoverRadius: 12,
          },
          {
            label: "Alternates",
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
                return (p.label || "Point") + " — confidence: " + (p.x * 100).toFixed(1) + "%, growth: " + (p.y * 100).toFixed(1) + "%";
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
            title: { display: true, text: "Growth (your category)", color: CHART_COLORS.text },
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
      var an = data.alternate_domains || [];
      var items = [];
      items.push("<li class=\"viz-num-item\"><strong>" + escapeHtml(data.domain || "Primary") + "</strong> " + formatPercent(data.domain_confidence ?? 0) + "</li>");
      an.forEach(function (item) {
        var name = Array.isArray(item) ? item[0] : item.domain;
        var conf = Array.isArray(item) ? item[1] : item.confidence;
        items.push("<li class=\"viz-num-item\">" + escapeHtml(name) + " " + formatPercent(conf) + "</li>");
      });
      var growthPct = data.domain_growth_score != null ? (Number(data.domain_growth_score) * 100).toFixed(1) + "%" : "—";
      items.push("<li class=\"viz-num-item\"><strong>Growth score:</strong> <span class=\"viz-num-growth\">" + growthPct + "</span></li>");
      vizNumbers.innerHTML =
        "<p class=\"viz-numbers-title\">Numbers at a glance</p>" +
        "<ul class=\"viz-numbers-list\">" + items.join("") + "</ul>";
    }

    resultDomain.innerHTML = "";
    var mainConf = data.domain_confidence != null ? Number(data.domain_confidence) : 0;
    var domainRow = document.createElement("div");
    domainRow.className = "domain-main-row";
    domainRow.innerHTML =
      "<span class=\"domain-name\">" + escapeHtml(data.domain || "—") + "</span>" +
      "<span class=\"domain-confidence-value\" aria-label=\"Confidence\">" + formatPercent(mainConf) + "</span>";
    resultDomain.appendChild(domainRow);

    const alternates = data.alternate_domains;
    if (alternates && alternates.length > 0) {
      const altWrap = document.createElement("div");
      altWrap.className = "alternates";
      const altTitle = document.createElement("p");
      altTitle.className = "alternates-title";
      altTitle.textContent = "Also close (compare all four)";
      altWrap.appendChild(altTitle);
      const ul = document.createElement("ul");
      ul.className = "alternate-list";
      ul.setAttribute("role", "table");
      var header = document.createElement("li");
      header.className = "alternate-list-header";
      header.innerHTML = "<span>Domain</span><span>Confidence</span>";
      ul.appendChild(header);
      alternates.forEach(function (item) {
        const name = Array.isArray(item) ? item[0] : item.domain;
        const conf = Array.isArray(item) ? item[1] : item.confidence;
        const li = document.createElement("li");
        li.innerHTML =
          "<span>" + escapeHtml(name) + "</span><span class=\"alternate-conf\">" + formatPercent(conf) + "</span>";
        ul.appendChild(li);
      });
      altWrap.appendChild(ul);
      resultDomain.appendChild(altWrap);
    }

    resultGrowth.innerHTML = "";
    var growthNum = data.domain_growth_score != null ? Number(data.domain_growth_score) : null;
    var growthLabel = document.createElement("p");
    growthLabel.className = "growth-label";
    growthLabel.textContent = data.domain_growth_label || "—";
    resultGrowth.appendChild(growthLabel);
    var growthScoreWrap = document.createElement("p");
    growthScoreWrap.className = "growth-score-wrap";
    growthScoreWrap.innerHTML =
      "Growth score: <span class=\"growth-score-value\" aria-label=\"Growth score\">" +
      (growthNum != null ? (growthNum * 100).toFixed(1) + "%" : "—") + "</span>";
    resultGrowth.appendChild(growthScoreWrap);

    resultKeywords.innerHTML = "";
    const keywords = data.suggested_keywords;
    if (keywords && keywords.length > 0) {
      const ul = document.createElement("ul");
      ul.className = "keywords-list";
      keywords.forEach(function (kw) {
        const li = document.createElement("li");
        li.textContent = kw;
        ul.appendChild(li);
      });
      resultKeywords.appendChild(ul);
    } else {
      resultKeywords.innerHTML = "<p class=\"keywords-list\">No keywords suggested.</p>";
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
