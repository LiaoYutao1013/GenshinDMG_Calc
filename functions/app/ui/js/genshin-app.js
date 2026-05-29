(function () {
  "use strict";

  const defaults = {
    headline: "伤害仪表盘",
    subtitle: "等待模拟。",
    statusTone: "ready",
    statusLabel: "就绪",
    totalDamageValue: "--",
    totalDamageNote: "尚未运行",
    dpsValue: "--",
    dpsNote: "--",
    rotationValue: "--",
    rotationNote: "--",
    slotValue: "--",
    slotNote: "--",
    characterName: "--",
    weaponName: "--",
    artifactName: "--",
    presetName: "--",
    talentSummary: "--",
    modeSummary: "--",
    teamDuration: "--",
    enemySummary: "--",
    activeCount: 0,
    totalSlots: 4,
    lastMode: "未运行",
    slots: [],
    summaryRows: [],
    breakdownRows: [],
    chartRows: [],
    timelineRows: [],
    timelineBlocks: []
  };

  let htmlComponent = null;

  function setup(component) {
    htmlComponent = component;
    htmlComponent.addEventListener("DataChanged", render);
    render();
  }

  window.GenshinDMGUI = {
    setup: setup,
    render: render
  };
  window.setup = setup;

  function data() {
    return Object.assign({}, defaults, htmlComponent ? htmlComponent.Data || {} : {});
  }

  function text(value, fallback) {
    if (value === undefined || value === null || value === "") {
      return fallback || "--";
    }
    return String(value);
  }

  function escapeHtml(value) {
    return text(value, "").replace(/[&<>"']/g, function (char) {
      return {
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        "\"": "&quot;",
        "'": "&#39;"
      }[char];
    });
  }

  function eventToMatlab(name, detail) {
    if (htmlComponent && typeof htmlComponent.sendEventToMATLAB === "function") {
      htmlComponent.sendEventToMATLAB(name, detail || {});
    }
  }

  function render() {
    const root = document.getElementById("app");
    if (!root) {
      return;
    }

    const view = root.dataset.view || "dashboard";
    const currentData = data();
    if (view === "team") {
      renderTeam(root, currentData);
    } else if (view === "editor") {
      renderEditor(root, currentData);
    } else {
      renderDashboard(root, currentData);
    }
  }

  function renderTeam(root, currentData) {
    const slots = Array.isArray(currentData.slots) ? currentData.slots : [];
    const tone = safeTone(currentData.statusTone);
    root.innerHTML = `
      <section class="team" aria-label="队伍预览">
        <header class="team-top">
          <div>
            <div class="eyebrow">队伍概览</div>
            <div class="title">${escapeHtml(currentData.activeCount)}/${escapeHtml(currentData.totalSlots)} 启用</div>
            <div class="subtle">${escapeHtml(currentData.teamDuration)} · ${escapeHtml(currentData.enemySummary)}</div>
          </div>
          <div class="team-actions">
            <span class="pill compact ${escapeHtml(tone)}" role="status">${escapeHtml(currentData.statusLabel)}</span>
            <button type="button" class="text-btn primary" data-action="runTeam" title="运行整队模拟" aria-label="运行整队模拟">整队模拟</button>
          </div>
        </header>
        <section class="slot-grid" aria-label="队伍槽位">
          ${slots.map(slotCardHtml).join("")}
        </section>
      </section>`;

    bindActionButtons(root);
  }

  function slotCardHtml(slot) {
    const selectedClass = slot.isSelected ? " selected" : "";
    const disabledClass = slot.enabled ? "" : " disabled";
    const portrait = slot.portraitUrl
      ? `<img src="${escapeHtml(slot.portraitUrl)}" alt="">`
      : `<span class="fallback">${escapeHtml(text(slot.displayName, "?").slice(0, 1))}</span>`;

    return `
      <article class="slot-card${selectedClass}${disabledClass}" aria-current="${slot.isSelected ? "true" : "false"}">
        <div class="portrait" title="${escapeHtml(slot.displayName)}">${portrait}</div>
        <div class="slot-main">
          <div class="slot-name">${escapeHtml(slot.displayName)}</div>
          <div class="slot-key">${escapeHtml(slot.characterKey)}</div>
        </div>
        <div class="slot-tags">
          <span class="tag">${escapeHtml(slot.talentSummary)}</span>
          <span class="tag">${escapeHtml(slot.startTime)}</span>
          <span class="tag">${escapeHtml(slot.enabled ? "启用" : "停用")}</span>
        </div>
        <div class="slot-badges">
          ${badgeHtml(slot.weaponBadgeUrl, "武器")}
          ${badgeHtml(slot.artifactBadgeUrl, "圣遗物")}
        </div>
        <div class="slot-actions">
          <button type="button" class="icon-btn" data-action="openEditor" data-slot="${escapeHtml(slot.index)}" title="打开角色信息编辑窗口" aria-label="编辑 ${escapeHtml(slot.displayName)}">编辑</button>
          <button type="button" class="icon-btn" data-action="toggleSlot" data-slot="${escapeHtml(slot.index)}" aria-pressed="${slot.enabled ? "true" : "false"}" title="切换队伍计算状态">${slot.enabled ? "停用" : "启用"}</button>
        </div>
      </article>`;
  }

  function renderEditor(root, currentData) {
    const slot = currentData.selectedSlot || {};
    const portrait = slot.portraitUrl
      ? `<img src="${escapeHtml(slot.portraitUrl)}" alt="">`
      : `<span class="fallback">${escapeHtml(text(slot.displayName, "?").slice(0, 1))}</span>`;

    root.innerHTML = `
      <section class="editor" aria-label="当前角色构筑预览">
        <article class="editor-card">
          <div class="editor-portrait">${portrait}</div>
          <div class="editor-title">
            <div class="eyebrow">当前构筑</div>
            <div class="title">${escapeHtml(slot.displayName)}</div>
            <div class="subtle">${escapeHtml(slot.characterKey)} · ${escapeHtml(slot.enabled ? "参与整队" : "未参与整队")}</div>
            <div class="equipment-badges">
              ${badgeHtml(slot.weaponBadgeUrl, "武器")}
              ${badgeHtml(slot.artifactBadgeUrl, "圣遗物")}
            </div>
          </div>
          <div class="editor-actions">
            <button type="button" class="text-btn primary" data-action="openEditor" data-slot="${escapeHtml(slot.index || 0)}" title="打开角色信息编辑窗口">编辑信息</button>
            <button type="button" class="text-btn primary" data-action="runSingle" title="运行当前角色模拟">单人模拟</button>
            <button type="button" class="text-btn gold" data-action="refreshTimeline" title="刷新输出轴预览">刷新轴</button>
            <button type="button" class="text-btn" data-action="resetSlot" title="重置当前角色">重置</button>
          </div>
          <div class="build-grid" aria-label="构筑摘要">
            ${buildItem("武器", slot.weaponName)}
            ${buildItem("圣遗物", slot.artifactName)}
            ${buildItem("构筑预设", slot.presetName)}
            ${buildItem("命座 / 天赋 / 精炼", slot.talentSummary)}
            ${buildItem("起轴时间", slot.startTime)}
          </div>
        </article>
      </section>`;

    bindActionButtons(root);
  }

  function buildItem(label, value) {
    return `
      <div class="build-item">
        <div class="label">${escapeHtml(label)}</div>
        <div class="build-value" title="${escapeHtml(value)}">${escapeHtml(value)}</div>
      </div>`;
  }

  function badgeHtml(src, label) {
    if (!src) {
      return `<span class="badge fallback">${escapeHtml(label.slice(0, 1))}</span>`;
    }
    return `<span class="badge" title="${escapeHtml(label)}"><img src="${escapeHtml(src)}" alt=""></span>`;
  }

  function renderDashboard(root, currentData) {
    const tone = safeTone(currentData.statusTone);

    root.innerHTML = `
      <section class="dashboard" aria-label="计算结果仪表盘">
        <header class="dashboard-header">
          <div>
            <div class="eyebrow">结果面板</div>
            <div class="title">${escapeHtml(currentData.headline)}</div>
            <div class="subtle">${escapeHtml(currentData.subtitle)}</div>
          </div>
          <div class="pill ${escapeHtml(tone)}" role="status">${escapeHtml(currentData.statusLabel)}</div>
        </header>
        <section class="metrics" aria-label="核心指标">
          ${metricHtml("total", "总伤害", currentData.totalDamageValue, currentData.totalDamageNote)}
          ${metricHtml("dps", "DPS", currentData.dpsValue, currentData.dpsNote)}
          ${metricHtml("time", "循环时长", currentData.rotationValue, currentData.rotationNote)}
          ${metricHtml("slot", "当前槽位", currentData.slotValue, currentData.slotNote)}
        </section>
        <section class="result-visuals" aria-label="结果可视化">
          <article class="visual-card">
            <div class="visual-title">成员 DPS</div>
            ${chartRowsHtml(currentData.chartRows)}
          </article>
          <article class="visual-card">
            <div class="visual-title">结果摘要</div>
            ${summaryRowsHtml(currentData.summaryRows)}
          </article>
        </section>
        <section class="timeline-card" aria-label="输出轴">
          <div class="visual-title">输出轴预览</div>
          ${timelineHtml(currentData.timelineRows, currentData.timelineBlocks)}
        </section>
      </section>`;
  }

  function metricHtml(kind, label, value, note) {
    return `
      <article class="metric ${escapeHtml(kind)}" aria-label="${escapeHtml(label)} ${escapeHtml(value)}">
        <div class="label">${escapeHtml(label)}</div>
        <div class="metric-value">${escapeHtml(value)}</div>
        <div class="note">${escapeHtml(note)}</div>
      </article>`;
  }

  function chartRowsHtml(rows) {
    rows = Array.isArray(rows) ? rows : [];
    if (!rows.length) {
      return `<div class="empty-state">运行模拟后显示成员对比。</div>`;
    }

    return `<div class="bar-list">${rows.map(function (row) {
      const width = Math.max(4, Math.min(100, Number(row.width || 0)));
      return `
        <div class="bar-row">
          <div class="bar-label" title="${escapeHtml(row.label)}">${escapeHtml(row.label)}</div>
          <div class="bar-track"><div class="bar-fill" style="width:${width}%"></div></div>
          <div class="bar-value">${escapeHtml(row.valueLabel)}</div>
        </div>`;
    }).join("")}</div>`;
  }

  function summaryRowsHtml(rows) {
    rows = Array.isArray(rows) ? rows : [];
    if (!rows.length) {
      return `<div class="empty-state">暂无计算结果。</div>`;
    }

    return `<div class="summary-list">${rows.map(function (row) {
      return `
        <div class="summary-row">
          <div class="summary-name" title="${escapeHtml(row.Character || row.Name)}">${escapeHtml(row.Character || row.Name)}</div>
          <div class="summary-value">${escapeHtml(formatNumber(row.TotalDMG))}</div>
          <div class="summary-value">${escapeHtml(formatNumber(row.StandaloneDPS))}</div>
        </div>`;
    }).join("")}</div>`;
  }

  function formatNumber(value) {
    const number = Number(value || 0);
    if (Math.abs(number) >= 100000000) {
      return (number / 100000000).toFixed(2) + " e8";
    }
    if (Math.abs(number) >= 10000) {
      return (number / 10000).toFixed(2) + " 万";
    }
    return number.toFixed(0);
  }

  function timelineHtml(rows, blocks) {
    rows = Array.isArray(rows) ? rows : [];
    blocks = Array.isArray(blocks) ? blocks : [];
    if (!rows.length) {
      return `<div class="empty-state">暂无输出轴。</div>`;
    }

    return `
      <div class="timeline">
        ${rows.map(function (row) {
          const rowBlocks = blocks.filter(function (block) {
            return Number(block.rowIndex) === Number(row.rowIndex);
          });
          return `
            <div class="timeline-row">
              <div class="timeline-label" title="${escapeHtml(row.label)}">${escapeHtml(row.label)}</div>
              <div class="timeline-track">
                ${rowBlocks.map(timelineBlockHtml).join("")}
              </div>
            </div>`;
        }).join("")}
      </div>`;
  }

  function timelineBlockHtml(block) {
    const left = Math.max(0, Math.min(100, Number(block.left || 0)));
    const width = Math.max(2, Math.min(100 - left, Number(block.width || 0)));
    const tone = Math.max(1, Math.min(4, Number(block.tone || 1)));
    return `
      <div class="timeline-block tone-${tone}" style="left:${left}%;width:${width}%;" title="${escapeHtml(block.label)}">
        <span>${escapeHtml(block.label)}</span>
      </div>`;
  }

  function safeTone(tone) {
    return ["success", "warn", "error", "ready", "idle"].indexOf(tone) >= 0 ? tone : "idle";
  }

  function bindActionButtons(root) {
    root.querySelectorAll("[data-action]").forEach(function (button) {
      button.addEventListener("click", function () {
        const action = button.dataset.action;
        const slotIndex = Number(button.dataset.slot || 0);
        const payload = slotIndex > 0 ? { slotIndex: slotIndex } : {};
        eventToMatlab(action, payload);
      });
    });
  }
}());
