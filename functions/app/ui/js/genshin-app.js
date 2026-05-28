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
    slots: []
  };

  let htmlComponent = null;

  function setup(component) {
    htmlComponent = component;
    htmlComponent.addEventListener("DataChanged", render);
    render();
  }

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
    root.innerHTML = `
      <section class="team">
        <header class="team-top">
          <div>
            <div class="eyebrow">队伍概览</div>
            <div class="title">${escapeHtml(currentData.activeCount)}/${escapeHtml(currentData.totalSlots)} 启用</div>
            <div class="subtle">${escapeHtml(currentData.teamDuration)} · ${escapeHtml(currentData.enemySummary)}</div>
          </div>
          <button class="text-btn primary" data-action="runTeam" title="运行整队模拟">运行</button>
        </header>
        <section class="slot-grid">
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
      <article class="slot-card${selectedClass}${disabledClass}">
        <div class="portrait">${portrait}</div>
        <div class="slot-main">
          <div class="slot-name">${escapeHtml(slot.displayName)}</div>
          <div class="slot-key">${escapeHtml(slot.characterKey)}</div>
        </div>
        <div class="slot-tags">
          <span class="tag">${escapeHtml(slot.talentSummary)}</span>
          <span class="tag">${escapeHtml(slot.startTime)}</span>
          <span class="tag">${escapeHtml(slot.enabled ? "启用" : "停用")}</span>
        </div>
        <div class="slot-actions">
          <button class="icon-btn" data-action="selectSlot" data-slot="${escapeHtml(slot.index)}" title="选择此槽位">编辑</button>
          <button class="icon-btn" data-action="toggleSlot" data-slot="${escapeHtml(slot.index)}" title="切换队伍计算状态">${slot.enabled ? "停用" : "启用"}</button>
        </div>
      </article>`;
  }

  function renderEditor(root, currentData) {
    const slot = currentData.selectedSlot || {};
    const portrait = slot.portraitUrl
      ? `<img src="${escapeHtml(slot.portraitUrl)}" alt="">`
      : `<span class="fallback">${escapeHtml(text(slot.displayName, "?").slice(0, 1))}</span>`;

    root.innerHTML = `
      <section class="editor">
        <article class="editor-card">
          <div class="editor-portrait">${portrait}</div>
          <div class="editor-title">
            <div class="eyebrow">当前构筑</div>
            <div class="title">${escapeHtml(slot.displayName)}</div>
            <div class="subtle">${escapeHtml(slot.characterKey)} · ${escapeHtml(slot.enabled ? "参与整队" : "未参与整队")}</div>
          </div>
          <div class="editor-actions">
            <button class="text-btn primary" data-action="runSingle" title="运行当前角色模拟">单人模拟</button>
            <button class="text-btn gold" data-action="refreshTimeline" title="刷新输出轴预览">刷新轴</button>
            <button class="text-btn" data-action="resetSlot" title="重置当前角色">重置</button>
          </div>
          <div class="build-grid">
            ${buildItem("武器", slot.weaponName)}
            ${buildItem("圣遗物", slot.artifactName)}
            ${buildItem("套装模式", slot.artifactMode)}
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

  function renderDashboard(root, currentData) {
    const tone = ["success", "warn", "error", "ready", "idle"].indexOf(currentData.statusTone) >= 0
      ? currentData.statusTone
      : "idle";

    root.innerHTML = `
      <section class="dashboard">
        <header class="dashboard-header">
          <div>
            <div class="eyebrow">结果面板</div>
            <div class="title">${escapeHtml(currentData.headline)}</div>
            <div class="subtle">${escapeHtml(currentData.subtitle)}</div>
          </div>
          <div class="pill ${escapeHtml(tone)}">${escapeHtml(currentData.statusLabel)}</div>
        </header>
        <section class="metrics" aria-label="核心指标">
          ${metricHtml("total", "总伤害", currentData.totalDamageValue, currentData.totalDamageNote)}
          ${metricHtml("dps", "DPS", currentData.dpsValue, currentData.dpsNote)}
          ${metricHtml("time", "循环时长", currentData.rotationValue, currentData.rotationNote)}
          ${metricHtml("slot", "当前槽位", currentData.slotValue, currentData.slotNote)}
        </section>
        <section class="details" aria-label="构筑摘要">
          ${detailHtml("角色", currentData.characterName)}
          ${detailHtml("武器", currentData.weaponName)}
          ${detailHtml("圣遗物", currentData.artifactName)}
          ${detailHtml("预设", currentData.presetName)}
          ${detailHtml("命座 / 天赋", currentData.talentSummary)}
          ${detailHtml("模式", currentData.modeSummary)}
        </section>
      </section>`;
  }

  function metricHtml(kind, label, value, note) {
    return `
      <article class="metric ${escapeHtml(kind)}">
        <div class="label">${escapeHtml(label)}</div>
        <div class="metric-value">${escapeHtml(value)}</div>
        <div class="note">${escapeHtml(note)}</div>
      </article>`;
  }

  function detailHtml(label, value) {
    return `
      <div class="detail">
        <div class="label">${escapeHtml(label)}</div>
        <div class="detail-value" title="${escapeHtml(value)}">${escapeHtml(value)}</div>
      </div>`;
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
