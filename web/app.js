"use strict";

const DB_NAME = "finance-local";
const DB_VERSION = 1;
const STORE = "incomeEntries";
const MONTHS = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"];
const MONTHS_SHORT = ["Янв", "Фев", "Мар", "Апр", "Май", "Июн", "Июл", "Авг", "Сен", "Окт", "Ноя", "Дек"];
const CURRENCIES = {
  RUB: { title: "Российский рубль", short: "Рубль", symbol: "₽", flag: "🇷🇺" },
  USD: { title: "Доллар США", short: "Доллар", symbol: "$", flag: "🇺🇸" },
  EUR: { title: "Евро", short: "Евро", symbol: "€", flag: "🇪🇺" }
};

const state = {
  entries: [],
  tab: "overview",
  detailYear: null,
  selectedYear: null,
  selectedMonth: null,
  currency: localStorage.getItem("finance.currency") || "RUB",
  appearance: localStorage.getItem("finance.appearance") || "system",
  modal: null
};

let db;

const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
const nowYear = () => new Date().getFullYear();
const nowMonth = () => new Date().getMonth() + 1;
const uid = () => crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random().toString(16).slice(2)}`;
const escapeHTML = value => String(value).replace(/[&<>'"]/g, char => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" })[char]);

function openDatabase() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = () => {
      const store = request.result.createObjectStore(STORE, { keyPath: "id" });
      store.createIndex("period", ["year", "month"], { unique: true });
      store.createIndex("year", "year");
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

function dbRequest(mode, callback) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE, mode);
    const result = callback(tx.objectStore(STORE));
    tx.oncomplete = () => resolve(result?.result);
    tx.onerror = () => reject(tx.error || result?.error);
    tx.onabort = () => reject(tx.error || new Error("Операция отменена"));
  });
}

const loadEntries = () => dbRequest("readonly", store => store.getAll()).then(items => items.sort((a, b) => a.year - b.year || a.month - b.month));
const putEntry = entry => dbRequest("readwrite", store => store.put(entry));
const deleteEntry = id => dbRequest("readwrite", store => store.delete(id));
const clearEntries = () => dbRequest("readwrite", store => store.clear());

function formatNumber(value, maximumFractionDigits = 2) {
  return new Intl.NumberFormat("ru-RU", { maximumFractionDigits, minimumFractionDigits: 0 }).format(Number(value) || 0);
}

function currency(value, code = state.currency) {
  return `${formatNumber(value)}\u00a0${CURRENCIES[code].symbol}`;
}

function compactCurrency(value) {
  const number = Number(value) || 0;
  if (Math.abs(number) >= 1_000_000) return `${formatNumber(number / 1_000_000, 1)} млн ${CURRENCIES[state.currency].symbol}`;
  if (Math.abs(number) >= 1_000) return `${formatNumber(number / 1_000, 1)} тыс. ${CURRENCIES[state.currency].symbol}`;
  return currency(number);
}

function percent(value) {
  if (value == null || !Number.isFinite(value)) return "—";
  return `${value > 0 ? "+" : ""}${formatNumber(value)}%`;
}

function entriesForYear(year) {
  return state.entries.filter(item => item.year === year).sort((a, b) => a.month - b.month);
}

function percentageChange(current, previous) {
  return previous == null || previous === 0 ? null : ((current - previous) / previous) * 100;
}

function yearStatistic(year) {
  const entries = entriesForYear(year);
  const endMonth = year === nowYear() ? Math.max(0, ...entries.map(item => item.month)) : 12;
  const comparable = entries.filter(item => !endMonth || item.month <= endMonth);
  const previous = entriesForYear(year - 1).filter(item => !endMonth || item.month <= endMonth);
  const total = entries.reduce((sum, item) => sum + Number(item.amount), 0);
  const currentTotal = comparable.reduce((sum, item) => sum + Number(item.amount), 0);
  const previousTotal = previous.length ? previous.reduce((sum, item) => sum + Number(item.amount), 0) : null;
  const best = entries.reduce((winner, item) => !winner || Number(item.amount) > Number(winner.amount) || (item.amount === winner.amount && item.month < winner.month) ? item : winner, null);
  return { year, total, average: entries.length ? total / entries.length : 0, change: percentageChange(currentTotal, previousTotal), best, count: entries.length, endMonth };
}

function yearStatistics() {
  return [...new Set(state.entries.map(item => item.year))].sort((a, b) => a - b).map(yearStatistic);
}

function monthStatistics(year) {
  const map = new Map(entriesForYear(year).map(item => [item.month, Number(item.amount)]));
  return MONTHS.map((_, index) => {
    const month = index + 1;
    const amount = map.has(month) ? map.get(month) : null;
    const previous = map.has(month - 1) ? map.get(month - 1) : null;
    return { month, amount, change: amount == null ? null : percentageChange(amount, previous) };
  });
}

function changeHTML(value, pill = false) {
  const type = value == null ? "" : value >= 0 ? "positive" : "negative";
  const arrow = value == null ? "" : value >= 0 ? "↗ " : "↘ ";
  return `<span class="change ${type} ${pill ? "pill" : ""}">${arrow}${percent(value)}</span>`;
}

function icon(name) {
  const icons = {
    plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>',
    chart: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 20h18M4 16l5-6 4 3 7-9"/></svg>',
    calendar: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="5" width="18" height="16" rx="3"/><path d="M7 3v4M17 3v4M3 10h18"/></svg>',
    gear: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1-2.8 2.8-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6v.2h-4V21a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1L4.2 17l.1-.1a1.7 1.7 0 0 0 .3-1.9A1.7 1.7 0 0 0 3 14H2.8v-4H3a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9L4.2 7 7 4.2l.1.1A1.7 1.7 0 0 0 9 4.6a1.7 1.7 0 0 0 1-1.6v-.2h4V3a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1L19.8 7l-.1.1a1.7 1.7 0 0 0-.3 1.9 1.7 1.7 0 0 0 1.6 1h.2v4H21a1.7 1.7 0 0 0-1.6 1z"/></svg>',
    back: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 18-6-6 6-6"/></svg>',
    share: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v12M8 7l4-4 4 4"/><path d="M5 11H4a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-7a2 2 0 0 0-2-2h-1"/></svg>'
  };
  return icons[name] || "";
}

function tabBar() {
  return `<nav class="tab-bar" aria-label="Основная навигация"><div class="tab-inner">
    ${[["overview", "chart", "Обзор"], ["years", "calendar", "Годы"], ["settings", "gear", "Настройки"]].map(([tab, ico, label]) => `
      <button class="tab-item ${state.tab === tab && state.detailYear == null ? "active" : ""}" data-action="tab" data-tab="${tab}">${icon(ico)}<span>${label}</span></button>`).join("")}
  </div></nav>`;
}

function nav(title, actions = "", back = false) {
  return `<header class="nav-bar">
    ${back ? `<button class="icon-button" data-action="back" aria-label="Назад">${icon("back")}</button>` : `<h1 class="nav-title">${escapeHTML(title)}</h1>`}
    ${back ? `<h1 class="nav-title small">${escapeHTML(title)}</h1>` : ""}
    <div class="nav-actions">${actions}</div>
  </header>`;
}

function emptyState() {
  return `<div class="empty-state"><div class="empty-icon">↗</div><h2>Начните историю дохода</h2>
    <p>Добавьте первый месяц — статистика и графики появятся автоматически.</p>
    <button class="primary-button" data-action="add-entry">＋ Добавить первый доход</button></div>`;
}

function metricGrid(stat) {
  return `<div class="metric-grid">
    <div class="card metric"><div class="metric-icon">=</div><div><div class="metric-value">${currency(stat.average)}</div><div class="metric-title">Среднее в месяц</div></div></div>
    <div class="card metric"><div class="metric-icon orange">♛</div><div><div class="metric-value">${stat.best ? MONTHS[stat.best.month - 1] : "—"}</div><div class="metric-title">Лучший месяц</div></div></div>
  </div>`;
}

function overviewHTML() {
  const current = yearStatistic(nowYear());
  const stats = yearStatistics();
  const add = `<button class="icon-button" data-action="add-entry" aria-label="Добавить доход">${icon("plus")}</button>`;
  if (!state.entries.length) return `<main class="screen">${nav("Обзор", add)}${emptyState()}</main>${tabBar()}`;
  const period = current.endMonth ? `Январь — ${MONTHS[current.endMonth - 1]}` : `Пока нет данных за ${nowYear()}`;
  return `<main class="screen">${nav("Обзор", add)}<div class="content stack">
    <section class="hero"><div class="hero-row"><span class="hero-label">Текущий год</span><span class="year-chip">${nowYear()}</span></div>
      <div><div class="hero-value">${currency(current.total)}</div><div class="hero-subtitle">◷ ${period}</div></div>
      <div class="hero-row"><span class="hero-label">К прошлому году</span><span class="hero-change">${percent(current.change)}</span></div>
    </section>
    ${metricGrid(current)}
    <section class="card chart-card"><div class="chart-title">Динамика по годам</div><div class="chart-subtitle">Долгосрочная история дохода</div>
      <div class="chart-selection" id="annual-selection">${annualSelectionHTML(stats)}</div><div class="chart-wrap"><canvas id="annual-chart" aria-label="График дохода по годам"></canvas></div></section>
    <section><h2 class="section-title">История по годам</h2><div class="card list-card">${stats.slice().reverse().map(stat => `
      <button class="list-row" data-action="open-year" data-year="${stat.year}"><span class="list-leading">${stat.year}</span><span class="list-main"><span class="list-primary">${currency(stat.total)}</span><span class="list-secondary">В среднем ${currency(stat.average)}</span></span>${changeHTML(stat.change)}<span class="chevron">›</span></button>`).join("")}</div></section>
  </div></main>${tabBar()}`;
}

function annualSelectionHTML(stats) {
  const stat = stats.find(item => item.year === state.selectedYear);
  return stat ? `<strong>${stat.year}</strong><span class="value">${currency(stat.total)}</span>${changeHTML(stat.change)}` : `<span class="list-secondary">Нажмите на точку, чтобы увидеть детали</span>`;
}

function yearsHTML() {
  const add = `<button class="icon-button" data-action="add-entry" aria-label="Добавить доход">${icon("plus")}</button>`;
  if (!state.entries.length) return `<main class="screen">${nav("Годы", add)}${emptyState()}</main>${tabBar()}`;
  return `<main class="screen">${nav("Годы", add)}<div class="content">${yearStatistics().slice().reverse().map(stat => `
    <button class="card year-card" data-action="open-year" data-year="${stat.year}"><div class="row"><span class="year-card-title">${stat.year}</span>${changeHTML(stat.change, true)}<span class="chevron">›</span></div>
      <div class="year-card-value">${currency(stat.total)}</div><div class="year-card-meta"><span>▣ ${stat.count} мес.</span><span>◉ ${currency(stat.average)}</span></div></button>`).join("")}</div></main>${tabBar()}`;
}

function yearDetailHTML(year) {
  const stat = yearStatistic(year);
  const months = monthStatistics(year);
  const actions = `<button class="icon-button" data-action="print-year" data-year="${year}" aria-label="Экспортировать отчёт">${icon("share")}</button><button class="icon-button" data-action="add-for-year" data-year="${year}" aria-label="Добавить доход">${icon("plus")}</button>`;
  return `<main class="screen">${nav(String(year), actions, true)}<div class="content stack">
    <section class="hero reverse"><div class="hero-row"><span class="hero-label">↗ Доход за год</span><span class="change-on-color">${percent(stat.change)}</span></div><div class="hero-value">${currency(stat.total)}</div></section>
    ${metricGrid(stat)}
    <section class="card chart-card"><div class="chart-title">По месяцам</div><div class="chart-subtitle">Нажмите на точку для подробностей</div>
      <div class="chart-selection" id="monthly-selection">${monthlySelectionHTML(months)}</div><div class="chart-wrap"><canvas id="monthly-chart" aria-label="График дохода по месяцам"></canvas></div></section>
    <section><h2 class="section-title">Все месяцы</h2><div class="card list-card">${months.map(item => `
      <button class="list-row" data-action="edit-month" data-year="${year}" data-month="${item.month}"><span class="list-leading">${MONTHS_SHORT[item.month - 1]}</span><span class="list-main"><span class="list-primary">${item.amount == null ? `<span class="no-data">Нет данных</span>` : currency(item.amount)}</span></span>${item.amount == null ? `<span class="add-month">＋</span>` : changeHTML(item.change)}</button>`).join("")}</div></section>
  </div></main>${tabBar()}`;
}

function monthlySelectionHTML(months) {
  const item = months.find(value => value.month === state.selectedMonth && value.amount != null);
  return item ? `<strong>${MONTHS[item.month - 1]}</strong><span class="value">${currency(item.amount)}</span>${changeHTML(item.change)}` : `<span class="list-secondary">Выберите месяц на графике</span>`;
}

function settingsHTML() {
  const c = CURRENCIES[state.currency];
  return `<main class="screen">${nav("Настройки")}<div class="settings">
    <section><div class="settings-group-title">Оформление</div><div class="card">
      <div class="settings-row"><span class="settings-icon">◐</span><span>Тема</span><div class="segmented">${[["system","Авто"],["light","Свет"],["dark","Тьма"]].map(([key,label]) => `<button class="${state.appearance === key ? "active" : ""}" data-action="theme" data-theme="${key}">${label}</button>`).join("")}</div></div>
      <button class="settings-row" data-action="currency"><span class="settings-icon">¤</span><span>Валюта</span><span class="settings-value">${c.flag} ${state.currency}</span><span class="chevron">›</span></button>
    </div></section>
    <section><div class="settings-group-title">Хранение</div><div class="card"><div class="settings-row privacy-note"><span class="settings-icon">▯</span><div><strong>Только на этом iPhone</strong><span>Доходы хранятся в локальной базе Safari. Нет аккаунта, сервера, аналитики или синхронизации.</span></div></div></div><p class="settings-footer">Удаление ярлыка не всегда удаляет данные Safari. Очистка данных сайта или удаление истории Safari удалит локальную базу — заранее сохраните резервную копию.</p></section>
    <section><div class="settings-group-title">Данные</div><div class="card">
      <button class="settings-row" data-action="print-overview" ${state.entries.length ? "" : "disabled"}><span class="settings-icon">▤</span><span>Экспортировать общий PDF</span></button>
      <div class="settings-row"><span>Записей</span><span class="settings-value">${state.entries.length}</span></div>
      <div class="settings-row"><span>Лет в истории</span><span class="settings-value">${new Set(state.entries.map(e => e.year)).size}</span></div>
    </div></section>
    <section><div class="settings-group-title">Резервная копия</div><div class="card">
      <button class="settings-row" data-action="export-backup" ${state.entries.length ? "" : "disabled"}><span class="settings-icon">⇩</span><span>Сохранить копию в Файлы</span></button>
      <button class="settings-row" data-action="import-backup"><span class="settings-icon">↻</span><span>Восстановить из копии</span></button>
    </div><p class="settings-footer">Копия содержит все суммы, даты и выбранную валюту. Само приложение никуда её не отправляет.</p></section>
    <section><div class="card"><button class="settings-row danger" data-action="delete-all" ${state.entries.length ? "" : "disabled"}><span class="settings-icon">⌫</span><span>Удалить все данные</span></button></div></section>
    <section><div class="settings-group-title">О приложении</div><div class="card"><div class="settings-row"><span>Версия</span><span class="settings-value">1.0 Web Local</span></div><div class="settings-row"><span>Текущая валюта</span><span class="settings-value">${c.short} (${c.symbol})</span></div></div></section>
  </div></main>${tabBar()}`;
}

function render() {
  applyTheme();
  const root = $("#app");
  root.innerHTML = state.detailYear != null ? yearDetailHTML(state.detailYear) : state.tab === "overview" ? overviewHTML() : state.tab === "years" ? yearsHTML() : settingsHTML();
  requestAnimationFrame(() => {
    if ($("#annual-chart")) drawLineChart($("#annual-chart"), yearStatistics().map(item => ({ key: item.year, value: item.total })), state.selectedYear, "year");
    if ($("#monthly-chart")) drawLineChart($("#monthly-chart"), monthStatistics(state.detailYear).filter(item => item.amount != null).map(item => ({ key: item.month, value: item.amount })), state.selectedMonth, "month");
  });
}

function applyTheme() {
  document.documentElement.dataset.theme = state.appearance === "system" ? "" : state.appearance;
  const dark = state.appearance === "dark" || (state.appearance === "system" && matchMedia("(prefers-color-scheme: dark)").matches);
  $("meta[name='theme-color']").content = dark ? "#000000" : "#f2f2f7";
}

function drawLineChart(canvas, points, selected, type) {
  const ratio = Math.min(devicePixelRatio || 1, 3);
  const rect = canvas.getBoundingClientRect();
  if (!rect.width || !rect.height) return;
  canvas.width = rect.width * ratio; canvas.height = rect.height * ratio;
  const ctx = canvas.getContext("2d"); ctx.scale(ratio, ratio);
  const style = getComputedStyle(document.documentElement);
  const accent = type === "month" ? style.getPropertyValue("--accent-2").trim() : style.getPropertyValue("--accent").trim();
  const secondary = style.getPropertyValue("--secondary").trim();
  const separator = style.getPropertyValue("--separator").trim();
  const padding = { left: 52, right: 14, top: 14, bottom: 30 };
  const width = rect.width - padding.left - padding.right, height = rect.height - padding.top - padding.bottom;
  const maximum = Math.max(1, ...points.map(item => item.value));
  const domainMin = type === "month" ? 1 : Math.min(...points.map(item => item.key), nowYear());
  const domainMax = type === "month" ? 12 : Math.max(...points.map(item => item.key), domainMin + 1);
  const x = key => padding.left + ((key - domainMin) / Math.max(1, domainMax - domainMin)) * width;
  const y = value => padding.top + height - (value / maximum) * height;
  ctx.font = "10px -apple-system, sans-serif"; ctx.fillStyle = secondary; ctx.textAlign = "right"; ctx.textBaseline = "middle";
  for (let i = 0; i <= 3; i++) {
    const yy = padding.top + height * i / 3;
    ctx.strokeStyle = separator; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(padding.left, yy); ctx.lineTo(rect.width - padding.right, yy); ctx.stroke();
    ctx.fillText(compactCurrency(maximum * (1 - i / 3)), padding.left - 7, yy);
  }
  const coords = points.map(item => ({ ...item, x: x(item.key), y: y(item.value) }));
  if (coords.length) {
    const gradient = ctx.createLinearGradient(0, padding.top, 0, padding.top + height); gradient.addColorStop(0, `${accent}44`); gradient.addColorStop(1, `${accent}00`);
    ctx.beginPath(); ctx.moveTo(coords[0].x, padding.top + height); coords.forEach(p => ctx.lineTo(p.x, p.y)); ctx.lineTo(coords.at(-1).x, padding.top + height); ctx.closePath(); ctx.fillStyle = gradient; ctx.fill();
    ctx.beginPath(); coords.forEach((p, i) => i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y)); ctx.strokeStyle = accent; ctx.lineWidth = 3; ctx.lineJoin = "round"; ctx.lineCap = "round"; ctx.stroke();
    coords.forEach(p => { ctx.beginPath(); ctx.arc(p.x, p.y, p.key === selected ? 6 : 3.5, 0, Math.PI * 2); ctx.fillStyle = p.key === selected ? style.getPropertyValue("--card").trim() : accent; ctx.fill(); ctx.strokeStyle = accent; ctx.lineWidth = p.key === selected ? 3 : 0; ctx.stroke(); });
  }
  ctx.fillStyle = secondary; ctx.textAlign = "center"; ctx.textBaseline = "top";
  const ticks = type === "month" ? [1,3,5,7,9,11] : points.map(p => p.key);
  ticks.forEach(key => ctx.fillText(type === "month" ? MONTHS_SHORT[key - 1] : String(key), x(key), padding.top + height + 9));
  canvas._chart = { coords, type };
}

function chartSelection(event) {
  const canvas = event.target.closest("canvas");
  if (!canvas?._chart?.coords.length) return;
  const rect = canvas.getBoundingClientRect();
  const px = event.clientX - rect.left;
  const nearest = canvas._chart.coords.reduce((best, point) => !best || Math.abs(point.x - px) < Math.abs(best.x - px) ? point : best, null);
  if (Math.abs(nearest.x - px) > 32) return;
  if (canvas._chart.type === "year") {
    state.selectedYear = nearest.key;
    $("#annual-selection").innerHTML = annualSelectionHTML(yearStatistics());
    drawLineChart(canvas, yearStatistics().map(item => ({ key: item.year, value: item.total })), state.selectedYear, "year");
  } else {
    state.selectedMonth = nearest.key;
    $("#monthly-selection").innerHTML = monthlySelectionHTML(monthStatistics(state.detailYear));
    drawLineChart(canvas, monthStatistics(state.detailYear).filter(item => item.amount != null).map(item => ({ key: item.month, value: item.amount })), state.selectedMonth, "month");
  }
}

function editorHTML(entry, year, month) {
  const current = CURRENCIES[state.currency];
  const years = Array.from({ length: 71 }, (_, i) => nowYear() - 50 + i);
  return `<div class="modal-backdrop" data-action="close-modal"><section class="modal-sheet" role="dialog" aria-modal="true" aria-label="${entry ? "Редактирование" : "Новый доход"}" data-modal-sheet>
    <div class="modal-nav"><button class="text-button secondary" data-action="close-modal">Отмена</button><strong>${entry ? "Редактирование" : "Новый доход"}</strong><button class="text-button" data-action="save-entry" data-id="${entry?.id || ""}">Сохранить</button></div>
    <div class="editor"><div class="card form-card"><div class="form-label">▣ Период</div><div class="select-row">
      <select id="entry-month" aria-label="Месяц">${MONTHS.map((name, i) => `<option value="${i + 1}" ${i + 1 === month ? "selected" : ""}>${name}</option>`).join("")}</select><span class="divider"></span>
      <select id="entry-year" aria-label="Год">${years.map(value => `<option value="${value}" ${value === year ? "selected" : ""}>${value}</option>`).join("")}</select></div></div>
      <div class="card form-card"><div class="form-label">◉ Доход</div><div class="amount-row"><input id="entry-amount" class="field amount-field" type="text" inputmode="decimal" placeholder="0" value="${entry ? escapeHTML(entry.amount) : ""}" autocomplete="off"><span class="amount-symbol">${current.symbol}</span></div><div class="hint">Сумма вводится в ${current.title.toLowerCase()}. Нулевое значение не считается отсутствием данных.</div></div>
      ${entry ? `<button class="danger-button" data-action="delete-entry" data-id="${entry.id}">⌫ Удалить запись</button>` : ""}
    </div></section></div>`;
}

function showEditor(entry = null, year = nowYear(), month = nowMonth()) {
  state.modal = "editor";
  $("#modal-root").innerHTML = editorHTML(entry, entry?.year || year, entry?.month || month);
  setTimeout(() => $("#entry-amount")?.focus(), 150);
}

function currencyHTML() {
  const current = CURRENCIES[state.currency];
  return `<div class="modal-backdrop" data-action="close-modal"><section class="modal-sheet" role="dialog" aria-modal="true" data-modal-sheet>
    <div class="modal-nav"><button class="text-button secondary" data-action="close-modal">Отмена</button><strong>Валюта</strong><button class="text-button" data-action="save-currency">Сохранить</button></div>
    <div class="currency-list"><div><div class="settings-group-title">Валюта приложения</div><div class="card currency-card">${Object.entries(CURRENCIES).map(([code, item]) => `<button class="currency-option" data-action="choose-currency" data-code="${code}"><span class="currency-flag">${item.flag}</span><span class="list-main"><span class="list-primary">${item.title}</span><span class="list-secondary">${code} · ${item.symbol}</span></span><span class="currency-check">${state.currencyDraft === code ? "●" : ""}</span></button>`).join("")}</div></div>
    ${state.currencyDraft !== state.currency ? `<div><div class="settings-group-title">Что сделать с историей</div><div class="card form-card"><div class="mode-toggle"><button class="${state.currencyMode === "keep" ? "active" : ""}" data-action="currency-mode" data-mode="keep">Без пересчёта</button><button class="${state.currencyMode === "convert" ? "active" : ""}" data-action="currency-mode" data-mode="convert">По курсу</button></div>
      ${state.currencyMode === "keep" ? `<div class="hint">Числа останутся прежними, изменится только знак валюты. Например, ${currency(100000)} станет ${currency(100000, state.currencyDraft)}.</div>` : `<div class="rate-box"><div class="hint">Сколько ${current.short.toLowerCase()} стоит одна единица новой валюты:</div><div class="amount-row"><strong>1 ${CURRENCIES[state.currencyDraft].symbol} =</strong><input id="exchange-rate" class="field rate-input" type="text" inputmode="decimal" placeholder="Курс" value="${escapeHTML(state.exchangeRate || "")}"><strong>${current.symbol}</strong></div></div>`}
    </div></div>` : ""}</div></section></div>`;
}

function showCurrency() {
  state.modal = "currency"; state.currencyDraft = state.currency; state.currencyMode = "keep"; state.exchangeRate = "";
  $("#modal-root").innerHTML = currencyHTML();
}

function closeModal() { state.modal = null; $("#modal-root").innerHTML = ""; }

function dialog(title, message, confirmText, onConfirm, danger = false) {
  const root = $("#modal-root");
  root.innerHTML = `<div class="dialog-backdrop"><section class="dialog" role="alertdialog"><div class="dialog-body"><h3>${escapeHTML(title)}</h3><p>${escapeHTML(message)}</p></div><div class="dialog-actions"><button data-action="dialog-confirm" class="${danger ? "danger" : ""}">${escapeHTML(confirmText)}</button><button data-action="dialog-cancel">Отмена</button></div></section></div>`;
  root._onConfirm = onConfirm;
}

function toast(message) {
  const root = $("#toast-root"); root.innerHTML = `<div class="toast">${escapeHTML(message)}</div>`;
  setTimeout(() => { if (root.textContent === message) root.innerHTML = ""; }, 2600);
}

function normalizedNumber(text) {
  const normalized = String(text).replace(/[\s\u00a0]/g, "").replace(",", ".");
  if (!/^\d+(\.\d+)?$/.test(normalized)) return null;
  const value = Number(normalized); return Number.isFinite(value) && value >= 0 ? value : null;
}

async function saveEditor(id) {
  const year = Number($("#entry-year").value), month = Number($("#entry-month").value), amount = normalizedNumber($("#entry-amount").value);
  if (amount == null) return toast("Введите корректную неотрицательную сумму");
  const collision = state.entries.find(item => item.year === year && item.month === month && item.id !== id);
  if (collision) return toast("За выбранный месяц уже есть запись");
  const existing = state.entries.find(item => item.id === id);
  const timestamp = new Date().toISOString();
  await putEntry({ id: id || uid(), year, month, amount: String(amount), createdAt: existing?.createdAt || timestamp, updatedAt: timestamp });
  state.entries = await loadEntries(); closeModal(); render();
}

async function removeEntry(id) {
  await deleteEntry(id); state.entries = await loadEntries(); closeModal(); render();
}

async function saveCurrency() {
  const code = state.currencyDraft;
  if (code === state.currency) return closeModal();
  if (state.currencyMode === "convert") {
    const rate = normalizedNumber($("#exchange-rate")?.value || "");
    if (!rate || rate <= 0) return toast("Введите корректный курс больше нуля");
    const updates = state.entries.map(item => ({ ...item, amount: String(Number(item.amount) / rate), updatedAt: new Date().toISOString() }));
    for (const item of updates) await putEntry(item);
    state.entries = await loadEntries();
  }
  state.currency = code; localStorage.setItem("finance.currency", code); closeModal(); render();
}

function backupObject() {
  return { version: 1, createdAt: new Date().toISOString(), currencyCode: state.currency, entries: state.entries };
}

function downloadBackup() {
  const blob = new Blob([JSON.stringify(backupObject(), null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob); const link = document.createElement("a");
  link.href = url; link.download = `FinanceApp-Backup-${new Date().toISOString().slice(0, 10)}.json`; link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000); toast("Резервная копия создана");
}

function validateBackup(data) {
  if (!data || data.version !== 1 || !CURRENCIES[data.currencyCode] || !Array.isArray(data.entries)) throw new Error("Неподдерживаемая резервная копия");
  if (!data.entries.every(item => item.id && Number.isInteger(item.year) && item.year >= 1900 && item.year <= 2200 && Number.isInteger(item.month) && item.month >= 1 && item.month <= 12 && normalizedNumber(item.amount) != null)) throw new Error("Копия содержит некорректные записи");
  return data;
}

async function importBackup(file) {
  try {
    const data = validateBackup(JSON.parse(await file.text()));
    dialog("Восстановить резервную копию?", "Периоды из копии заменят совпадающие записи. Остальные записи сохранятся.", "Восстановить", async () => {
      const byPeriod = new Map(state.entries.map(item => [`${item.year}-${item.month}`, item]));
      for (const incoming of data.entries) {
        const existing = byPeriod.get(`${incoming.year}-${incoming.month}`);
        await putEntry({ ...incoming, id: existing?.id || incoming.id, amount: String(incoming.amount) });
      }
      state.currency = data.currencyCode; localStorage.setItem("finance.currency", state.currency);
      state.entries = await loadEntries(); closeModal(); render(); toast(`Восстановлено записей: ${data.entries.length}`);
    });
  } catch (error) { toast(error.message || "Не удалось прочитать файл"); }
}

function buildPrintReport(year = null) {
  $(".print-report")?.remove();
  const report = document.createElement("section"); report.className = "print-report";
  const stats = year == null ? yearStatistics().slice().reverse() : monthStatistics(year);
  const rows = year == null
    ? stats.map(item => `<tr><td>${item.year}</td><td>${currency(item.total)}</td><td>${currency(item.average)}</td><td>${percent(item.change)}</td></tr>`).join("")
    : stats.map(item => `<tr><td>${MONTHS[item.month - 1]}</td><td>${item.amount == null ? "Нет данных" : currency(item.amount)}</td><td>${percent(item.change)}</td></tr>`).join("");
  report.innerHTML = `<div class="print-header"><h1>${year == null ? "Динамика дохода" : `Доход за ${year}`}</h1><div>Finance • Личный отчёт • ${new Intl.DateTimeFormat("ru-RU", { dateStyle: "long" }).format(new Date())}</div></div>
    <h2>${year == null ? "Статистика по годам" : "Доход по месяцам"}</h2><table><thead><tr>${year == null ? "<th>Год</th><th>Доход</th><th>Среднее / мес.</th><th>Изменение</th>" : "<th>Месяц</th><th>Доход</th><th>Изменение</th>"}</tr></thead><tbody>${rows}</tbody></table>`;
  document.body.append(report); window.print(); setTimeout(() => report.remove(), 1000);
}

document.addEventListener("click", async event => {
  if (event.target.closest("canvas")) return chartSelection(event);
  const target = event.target.closest("[data-action]"); if (!target) return;
  const action = target.dataset.action;
  if (action === "tab") { state.tab = target.dataset.tab; state.detailYear = null; state.selectedMonth = null; scrollTo(0, 0); render(); }
  else if (action === "back") { state.detailYear = null; state.selectedMonth = null; render(); }
  else if (action === "open-year") { state.detailYear = Number(target.dataset.year); state.selectedMonth = null; scrollTo(0, 0); render(); }
  else if (action === "add-entry") showEditor();
  else if (action === "add-for-year") showEditor(null, Number(target.dataset.year), Number(target.dataset.year) === nowYear() ? nowMonth() : 1);
  else if (action === "edit-month") { const year = Number(target.dataset.year), month = Number(target.dataset.month); showEditor(state.entries.find(item => item.year === year && item.month === month), year, month); }
  else if (action === "close-modal" && (target === event.target || !event.target.closest("[data-modal-sheet]"))) closeModal();
  else if (action === "save-entry") await saveEditor(target.dataset.id || null);
  else if (action === "delete-entry") dialog("Удалить доход?", "Запись исчезнет из статистики и графиков. Это действие нельзя отменить.", "Удалить", () => removeEntry(target.dataset.id), true);
  else if (action === "theme") { state.appearance = target.dataset.theme; localStorage.setItem("finance.appearance", state.appearance); render(); }
  else if (action === "currency") showCurrency();
  else if (action === "choose-currency") { state.currencyDraft = target.dataset.code; $("#modal-root").innerHTML = currencyHTML(); }
  else if (action === "currency-mode") { state.exchangeRate = $("#exchange-rate")?.value || state.exchangeRate; state.currencyMode = target.dataset.mode; $("#modal-root").innerHTML = currencyHTML(); }
  else if (action === "save-currency") await saveCurrency();
  else if (action === "export-backup") downloadBackup();
  else if (action === "import-backup") $("#backup-input").click();
  else if (action === "delete-all") dialog("Удалить всю историю?", "Записи и рассчитанная статистика будут удалены без возможности восстановления.", "Удалить все данные", async () => { await clearEntries(); state.entries = []; closeModal(); render(); }, true);
  else if (action === "dialog-confirm") { const fn = $("#modal-root")._onConfirm; if (fn) await fn(); }
  else if (action === "dialog-cancel") closeModal();
  else if (action === "print-overview") buildPrintReport();
  else if (action === "print-year") buildPrintReport(Number(target.dataset.year));
});

$("#backup-input").addEventListener("change", event => { const file = event.target.files[0]; if (file) importBackup(file); event.target.value = ""; });
window.addEventListener("resize", () => { if ($("#annual-chart") || $("#monthly-chart")) render(); });
matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => { if (state.appearance === "system") render(); });

async function start() {
  try {
    db = await openDatabase(); state.entries = await loadEntries(); render();
    if ("serviceWorker" in navigator) navigator.serviceWorker.register("./sw.js").catch(() => {});
  } catch (error) {
    $("#app").innerHTML = `<div class="empty-state"><h2>Не удалось открыть локальное хранилище</h2><p>${escapeHTML(error.message || "Разрешите Safari хранить данные этого сайта и перезагрузите страницу.")}</p></div>`;
  }
}

start();
