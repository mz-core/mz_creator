(function () {
  "use strict";

  const resource =
    typeof GetParentResourceName === "function"
      ? GetParentResourceName()
      : "mz_creator";

  const categories = [
    { id: "identity", label: "Identidade", icon: "id-card", helper: "Defina as informações básicas do personagem.", camera: "body" },
    { id: "heritage", label: "Herança", icon: "dna", helper: "Escolha os pais e ajuste a mistura genética.", camera: "face" },
    { id: "face", label: "Rosto", icon: "scan-face", helper: "Modele os traços e proporções do rosto.", camera: "face" },
    { id: "skin", label: "Pele", icon: "sparkles", helper: "Ajuste idade, textura e detalhes naturais.", camera: "face" },
    { id: "hair", label: "Cabelo", icon: "scissors", helper: "Escolha corte, textura e cores do cabelo.", camera: "face" },
    { id: "eyebrows", label: "Sobrancelhas", icon: "sparkles", helper: "Ajuste estilo, intensidade e tonalidade.", camera: "face" },
    { id: "eyes", label: "Olhos", icon: "eye", helper: "Escolha a cor e a abertura dos olhos.", camera: "face" },
    { id: "beard", label: "Barba", icon: "beard", helper: "Configure barba, pelos faciais e corporais.", camera: "face" },
    { id: "makeup", label: "Maquiagem", icon: "palette", helper: "Aplique maquiagem, blush e batom.", camera: "face" },
    { id: "marks", label: "Marcas", icon: "star", helper: "Adicione sardas, sinais e imperfeições.", camera: "face" },
    { id: "review", label: "Revisão", icon: "clipboard", helper: "Revise os dados antes de salvar.", camera: "body" },
  ];

  const fatherCatalog = [
    [0, "Benjamin"], [1, "Daniel"], [2, "Joshua"], [3, "Noah"],
    [4, "Andrew"], [5, "Juan"], [6, "Alex"], [7, "Isaac"],
    [8, "Evan"], [9, "Ethan"], [10, "Vincent"], [11, "Angel"],
    [12, "Diego"], [13, "Adrian"], [14, "Gabriel"], [15, "Michael"],
    [16, "Santiago"], [17, "Kevin"], [18, "Louis"], [19, "Samuel"],
    [20, "Anthony"], [42, "Claude"], [43, "Niko"], [44, "John"],
  ].map(([id, name]) => ({ id, name, image: `assets/${name}.webp` }));

  const motherCatalog = [
    [21, "Hannah"], [22, "Audrey"], [23, "Jasmine"], [24, "Giselle"],
    [25, "Amelia"], [26, "Isabella"], [27, "Zoe"], [28, "Ava"],
    [29, "Camila"], [30, "Violet"], [31, "Sophia"], [32, "Evelyn"],
    [33, "Nicole"], [34, "Ashley"], [35, "Grace"], [36, "Brianna"],
    [37, "Natalie"], [38, "Olivia"], [39, "Elizabeth"], [40, "Charlotte"],
    [41, "Emma"], [45, "Misty"],
  ].map(([id, name]) => ({ id, name, image: `assets/${name}.webp` }));

  const faceGroups = [
    {
      title: "Nariz",
      icon: "scan-face",
      subtitle: "Formato, posição e inclinação.",
      controls: [
        ["Largura", "faceFeatures.noseWidth"],
        ["Altura da ponta", "faceFeatures.nosePeakHeight"],
        ["Comprimento", "faceFeatures.nosePeakLength"],
        ["Altura do osso", "faceFeatures.noseBoneHeight"],
        ["Inclinação da ponta", "faceFeatures.nosePeakLowering"],
        ["Torção", "faceFeatures.noseBoneTwist"],
      ],
    },
    {
      title: "Sobrancelhas e olhos",
      icon: "eye",
      subtitle: "Expressão e abertura do olhar.",
      controls: [
        ["Altura da sobrancelha", "faceFeatures.eyebrowHeight"],
        ["Profundidade da sobrancelha", "faceFeatures.eyebrowDepth"],
        ["Abertura dos olhos", "faceFeatures.eyesOpening"],
      ],
    },
    {
      title: "Bochechas",
      icon: "scan-face",
      subtitle: "Maçãs e largura facial.",
      controls: [
        ["Altura das maçãs", "faceFeatures.cheekboneHeight"],
        ["Largura das maçãs", "faceFeatures.cheekboneWidth"],
        ["Largura das bochechas", "faceFeatures.cheeksWidth"],
      ],
    },
    {
      title: "Boca e maxilar",
      icon: "scan-face",
      subtitle: "Lábios, mandíbula e pescoço.",
      controls: [
        ["Espessura dos lábios", "faceFeatures.lipsThickness"],
        ["Largura do maxilar", "faceFeatures.jawBoneWidth"],
        ["Comprimento do maxilar", "faceFeatures.jawBoneLength"],
        ["Espessura do pescoço", "faceFeatures.neckThickness"],
      ],
    },
    {
      title: "Queixo",
      icon: "scan-face",
      subtitle: "Altura, comprimento e formato.",
      controls: [
        ["Altura", "faceFeatures.chinBoneHeight"],
        ["Comprimento", "faceFeatures.chinBoneLength"],
        ["Largura", "faceFeatures.chinBoneWidth"],
        ["Covinha", "faceFeatures.chinHole"],
      ],
    },
  ];

  const overlayLimits = {
    blemishes: 23,
    facialHair: 28,
    eyebrows: 33,
    ageing: 14,
    makeup: 74,
    blush: 6,
    complexion: 11,
    sunDamage: 10,
    lipstick: 9,
    molesFreckles: 17,
    chestHair: 16,
    bodyBlemishes: 11,
    addBodyBlemishes: 1,
  };

  const componentLabels = {
    "1": "Máscara",
    "3": "Braços",
    "4": "Calça",
    "5": "Mochila",
    "6": "Calçado",
    "7": "Acessório",
    "8": "Camiseta interna",
    "9": "Colete",
    "10": "Decalque",
    "11": "Parte superior",
  };

  const propLabels = {
    "0": "Chapéu",
    "1": "Óculos",
    "2": "Orelha",
    "6": "Relógio",
    "7": "Pulseira",
  };

  const hairPalette = buildPalette(64, "hair");
  const eyePalette = buildPalette(32, "eyes");

  const state = {
    open: false,
    mode: "manual",
    defaults: {},
    appearance: null,
    identity: null,
    activeCategory: "identity",
    cameraMode: "body",
    allowCameraRotation: true,
    previewTimer: null,
    toastTimer: null,
    saving: false,
    parentPages: { father: 0, mother: 0 },
  };

  const creatorEl = document.getElementById("creator");
  const menuEl = document.getElementById("category-menu");
  const selectedCategoryEl = document.getElementById("selected-category");
  const settingsContentEl = document.getElementById("settings-content");
  const toastEl = document.getElementById("toast");
  const saveButtonEl = document.getElementById("save-button");
  const randomButtonEl = document.getElementById("random-button");
  const backButtonEl = document.getElementById("back-button");

  function icon(name, className = "") {
    return `<svg class="${className}" aria-hidden="true"><use href="#i-${name}"></use></svg>`;
  }

  function escapeHtml(value) {
    return String(value ?? "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");
  }

  function sanitizeText(value, maxLength) {
    return String(value ?? "")
      .replace(/[<>`{}\\]/g, "")
      .replace(/\s+/g, " ")
      .trimStart()
      .slice(0, maxLength);
  }

  function clone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  async function post(name, data) {
    const response = await fetch(`https://${resource}/${name}`, {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=UTF-8" },
      body: JSON.stringify(data || {}),
    });
    const text = await response.text();
    return text ? JSON.parse(text) : {};
  }

  function showToast(message, type = "error") {
    window.clearTimeout(state.toastTimer);
    toastEl.textContent = message || "Não foi possível concluir a ação.";
    toastEl.dataset.type = type;
    toastEl.classList.add("is-visible");
    state.toastTimer = window.setTimeout(
      () => toastEl.classList.remove("is-visible"),
      2800,
    );
  }

  function getPath(target, path) {
    return path
      .split(".")
      .reduce((current, key) => (current == null ? undefined : current[key]), target);
  }

  function setPath(target, path, value) {
    const keys = path.split(".");
    const last = keys.pop();
    let cursor = target;
    for (const key of keys) {
      if (!cursor[key] || typeof cursor[key] !== "object") cursor[key] = {};
      cursor = cursor[key];
    }
    cursor[last] = value;
  }

  function clamp(value, min, max) {
    return Math.min(max, Math.max(min, value));
  }

  function buildPalette(count, kind) {
    const hairBase = [
      "#111315", "#211814", "#34231b", "#4a2f20", "#613d25", "#7b5435",
      "#9a7048", "#b88c5e", "#d0ad79", "#ead5a3", "#f0e5c8", "#d9d9d5",
      "#adaca9", "#78372d", "#9d3f2f", "#ba4d32", "#7a2938", "#8e2f53",
      "#5e355f", "#44346a", "#304674", "#285c79", "#23727b", "#2e7768",
      "#427452", "#67763f", "#7d6b38", "#65523a", "#4a4140", "#2d2e32",
      "#181b22", "#0c0f13",
    ];
    const eyeBase = [
      "#45798a", "#537f91", "#62879a", "#699188", "#71806b", "#858167",
      "#8c7052", "#755741", "#5e483a", "#45423b", "#737d76", "#93a3a5",
      "#79a27f", "#a28b5d", "#6f5d78", "#7a5154", "#333536", "#afb0aa",
      "#2e5968", "#376f79", "#4c8582", "#5e8d76", "#817f55", "#a08258",
      "#5b4438", "#3d302c", "#657274", "#899697", "#49736d", "#6b825f",
      "#8c856f", "#b1aea3",
    ];
    const source = kind === "eyes" ? eyeBase : hairBase;
    return Array.from({ length: count }, (_, index) => ({
      index,
      color: source[index % source.length],
    }));
  }

  function schedulePreview() {
    window.clearTimeout(state.previewTimer);
    state.previewTimer = window.setTimeout(() => {
      if (!state.open || !state.appearance) return;
      post("previewAppearance", { appearance_json: state.appearance }).catch(() => {});
    }, 65);
  }

  function modelForGender(gender) {
    return gender === "female" ? "mp_f_freemode_01" : "mp_m_freemode_01";
  }

  function genderForModel(model) {
    return model === "mp_f_freemode_01" ? "female" : "male";
  }

  function buildIdentity(charinfo, appearance) {
    const gender = charinfo?.gender || genderForModel(appearance?.model);
    return {
      firstname: charinfo?.firstname || "",
      lastname: charinfo?.lastname || "",
      birthdate: charinfo?.birthdate || "",
      gender: gender === "female" ? "female" : "male",
      nationality: charinfo?.nationality || "Brasileira",
      phone: charinfo?.phone || "",
    };
  }

  function normalizeAppearance(appearance) {
    const result = clone(appearance || {});
    result.headBlend ||= {};
    result.faceFeatures ||= {};
    result.headOverlays ||= {};
    result.hair ||= { style: 0, texture: 0, color: 0, highlight: 0 };
    result.components ||= {};
    result.props ||= {};
    return result;
  }

  function findSelectedParent(type) {
    const catalog = type === "father" ? fatherCatalog : motherCatalog;
    const firstKey = type === "father" ? "shapeFirst" : "shapeSecond";
    const secondKey = type === "father" ? "shapeSecond" : "shapeFirst";
    const first = Number(state.appearance?.headBlend?.[firstKey]);
    const second = Number(state.appearance?.headBlend?.[secondKey]);
    return catalog.find((entry) => entry.id === first)?.id
      ?? catalog.find((entry) => entry.id === second)?.id
      ?? catalog[0].id;
  }

  function syncParentPages() {
    for (const type of ["father", "mother"]) {
      const catalog = type === "father" ? fatherCatalog : motherCatalog;
      const selected = findSelectedParent(type);
      const index = catalog.findIndex((entry) => entry.id === selected);
      state.parentPages[type] = Math.max(0, Math.floor(Math.max(index, 0) / 3));
    }
  }

  function renderCategoryMenu() {
    menuEl.innerHTML = categories
      .map(
        (category) => `
          <button class="category-item" type="button" data-category="${category.id}" aria-label="Abrir ${category.label}">
            ${icon(category.icon, "item-icon")}
            <span class="item-label">${category.label}</span>
          </button>`,
      )
      .join("");
    syncCategoryLayout();
    syncActiveCategoryVisuals();
  }

  function syncCategoryLayout() {
    const buttons = [...menuEl.querySelectorAll(".category-item")];
    const height = window.innerHeight;
    const scale = clamp(Math.min(window.innerWidth / 1920, height / 1080), 0.72, 1.15);
    const top = height < 820 ? 54 : 66;
    const bottom = height < 820 ? 70 : 86;
    const usable = Math.max(420, height - top - bottom);

    buttons.forEach((button, index) => {
      const ratio = categories.length === 1 ? 0 : index / (categories.length - 1);
      const curve = Math.pow(Math.abs(ratio - 0.5) * 2, 1.55);
      const x = (106 + curve * 104) * scale;
      const y = top + ratio * usable;
      button.style.setProperty("--item-x", `${Math.round(x)}px`);
      button.style.setProperty("--item-y", `${Math.round(y)}px`);
    });
  }

  function syncActiveCategoryVisuals() {
    const index = categories.findIndex((entry) => entry.id === state.activeCategory);
    const category = categories[index] || categories[0];
    menuEl.querySelectorAll(".category-item").forEach((button) => {
      const active = button.dataset.category === category.id;
      button.classList.toggle("is-active", active);
      button.setAttribute("aria-current", active ? "step" : "false");
    });
    document.documentElement.style.setProperty(
      "--progress",
      String(Math.max(4, ((index + 1) / categories.length) * 100)),
    );

    selectedCategoryEl.classList.add("is-changing");
    window.setTimeout(() => {
      selectedCategoryEl.querySelector("use").setAttribute("href", `#i-${category.icon}`);
      selectedCategoryEl.querySelector("strong").textContent = category.label.toUpperCase();
      selectedCategoryEl.querySelector("span").textContent = category.helper;
      selectedCategoryEl.classList.remove("is-changing");
    }, 70);

    backButtonEl.querySelector("span").textContent = index === 0 ? "SAIR" : "VOLTAR";
  }

  function setCameraMode(mode, notifyGame = true) {
    state.cameraMode = mode;
    document.querySelectorAll(".camera-button").forEach((button) => {
      button.classList.toggle("is-active", button.dataset.mode === mode);
    });
    if (notifyGame) post("setCameraMode", { mode }).catch(() => {});
  }

  function setActiveCategory(id, options = {}) {
    const category = categories.find((entry) => entry.id === id);
    if (!category || state.activeCategory === id && options.force !== true) return;
    state.activeCategory = category.id;
    syncActiveCategoryVisuals();
    setCameraMode(category.camera, true);
    renderSettings();
  }

  function moduleTemplate(title, iconName, subtitle, body, extraClass = "") {
    return `
      <section class="ui-module ${extraClass}">
        <header class="module-header">
          ${icon(iconName)}
          <div class="module-heading">
            <strong>${escapeHtml(title)}</strong>
            ${subtitle ? `<span>${escapeHtml(subtitle)}</span>` : ""}
          </div>
        </header>
        <div class="module-body">${body}</div>
      </section>`;
  }

  function identityModule() {
    const identity = state.identity || {};
    return moduleTemplate(
      "IDENTIDADE",
      "id-card",
      "Informe os dados básicos do personagem.",
      `<div class="form-grid">
        ${fieldTemplate("Nome", "firstname", identity.firstname, "text", "user", 24)}
        ${fieldTemplate("Sobrenome", "lastname", identity.lastname, "text", "user", 24)}
        ${fieldTemplate("Nascimento", "birthdate", identity.birthdate, "date", "calendar")}
        ${fieldTemplate("Nacionalidade", "nationality", identity.nationality, "text", "globe", 32)}
      </div>`,
    );
  }

  function fieldTemplate(label, key, value, type = "text", iconName, maxLength) {
    const max = maxLength ? ` maxlength="${maxLength}"` : "";
    return `
      <label class="field">
        <span>${escapeHtml(label)}</span>
        <span class="field-control ${iconName ? "has-icon" : ""}">
          ${iconName ? icon(iconName) : ""}
          <input type="${type}" data-identity="${key}" value="${escapeHtml(value)}"${max} autocomplete="off">
        </span>
      </label>`;
  }

  function modelModule() {
    const gender = genderForModel(state.appearance?.model);
    return moduleTemplate(
      "SEXO / MODELO",
      "mars",
      "A base define o modelo freemode utilizado.",
      `<div class="model-grid">
        <button class="model-card ${gender === "male" ? "is-active" : ""}" type="button" data-model="mp_m_freemode_01" data-gender="male">
          ${icon("mars")}<strong>Masculino</strong><small>Modelo masculino</small>
        </button>
        <button class="model-card ${gender === "female" ? "is-active" : ""}" type="button" data-model="mp_f_freemode_01" data-gender="female">
          ${icon("venus")}<strong>Feminino</strong><small>Modelo feminino</small>
        </button>
      </div>`,
    );
  }

  function parentCard(entry, type) {
    const selected = findSelectedParent(type) === entry.id;
    return `
      <button class="parent-card ${selected ? "is-active" : ""}" type="button"
        data-parent-type="${type}" data-parent-id="${entry.id}" data-name="${escapeHtml(entry.name)}"
        aria-label="Selecionar ${escapeHtml(entry.name)}" aria-pressed="${selected}">
        <img src="${entry.image}" alt="${escapeHtml(entry.name)}" loading="lazy" draggable="false">
      </button>`;
  }

  function parentRow(type, compact = false) {
    const catalog = type === "father" ? fatherCatalog : motherCatalog;
    const pageCount = Math.ceil(catalog.length / 3);
    const page = clamp(state.parentPages[type] || 0, 0, pageCount - 1);
    const visible = catalog.slice(page * 3, page * 3 + 3);
    const title = type === "father" ? "PAI" : "MÃE";
    return `
      <div class="parent-row" data-parent-row="${type}">
        <div class="parent-row-title"><span>${title}</span><span>${page + 1} / ${pageCount}</span></div>
        <div class="parent-selector">
          <button class="parent-nav" type="button" data-parent-nav="${type}" data-direction="-1" aria-label="Página anterior de ${title.toLowerCase()}">${icon("chevron-left")}</button>
          <div class="parent-grid">${visible.map((entry) => parentCard(entry, type)).join("")}</div>
          <button class="parent-nav" type="button" data-parent-nav="${type}" data-direction="1" aria-label="Próxima página de ${title.toLowerCase()}">${icon("chevron-right")}</button>
        </div>
      </div>${compact ? "" : ""}`;
  }

  function heritageModule(compact = false) {
    const shapeMix = Number(getPath(state.appearance, "headBlend.shapeMix") ?? 0.5);
    const skinMix = Number(getPath(state.appearance, "headBlend.skinMix") ?? 0.5);
    const body = `
      ${parentRow("father", compact)}
      ${parentRow("mother", compact)}
      <div class="slider-stack" style="margin-top:12px">
        ${sliderTemplate({ label: "Mistura genética", path: "headBlend.shapeMix", min: 0, max: 1, step: 0.01, format: "percent" })}
        ${compact ? "" : sliderTemplate({ label: "Mistura do tom de pele", path: "headBlend.skinMix", min: 0, max: 1, step: 0.01, format: "percent" })}
      </div>
      <div class="mix-labels"><span>Pai <strong>${Math.round((1 - shapeMix) * 100)}%</strong></span><span>Mãe <strong>${Math.round(shapeMix * 100)}%</strong></span></div>
      ${compact ? "" : `<div class="mix-labels"><span>Pele do pai <strong>${Math.round((1 - skinMix) * 100)}%</strong></span><span>Pele da mãe <strong>${Math.round(skinMix * 100)}%</strong></span></div>`}
    `;
    return moduleTemplate(
      "HERANÇA",
      "dna",
      "Escolha os pais biológicos e ajuste a influência.",
      body,
      compact ? "is-compact-heritage" : "",
    );
  }

  function sliderTemplate(def) {
    const value = Number(getPath(state.appearance, def.path) ?? def.min ?? 0);
    const min = Number(def.min ?? 0);
    const max = Number(def.max ?? 1);
    const step = Number(def.step ?? 1);
    const percent = max === min ? 0 : ((value - min) / (max - min)) * 100;
    return `
      <div class="control-row">
        <div class="control-heading">
          <span>${escapeHtml(def.label)}</span>
          <output data-output-for="${def.path}">${formatValue(value, def)}</output>
        </div>
        <div class="range-line">
          <button class="step-button" type="button" data-step-path="${def.path}" data-step="${-step}" aria-label="Diminuir ${escapeHtml(def.label)}">${icon("minus")}</button>
          <input type="range" data-path="${def.path}" min="${min}" max="${max}" step="${step}" value="${value}" style="--range-progress:${percent}%" aria-label="${escapeHtml(def.label)}">
          <button class="step-button" type="button" data-step-path="${def.path}" data-step="${step}" aria-label="Aumentar ${escapeHtml(def.label)}">${icon("plus")}</button>
        </div>
      </div>`;
  }

  function formatValue(value, def) {
    if (def.format === "percent") return `${Math.round(Number(value) * 100)}%`;
    if (def.format === "neutral") {
      const numeric = Number(value);
      if (Math.abs(numeric) < 0.005) return "Neutro";
      return numeric > 0 ? `+${numeric.toFixed(2)}` : numeric.toFixed(2);
    }
    if (Number(def.step) < 1) return Number(value).toFixed(2);
    return String(Math.round(Number(value)));
  }

  function swatchesTemplate(label, path, palette) {
    const selected = Number(getPath(state.appearance, path) ?? 0);
    return `
      <div class="swatch-block">
        <div class="swatch-heading"><span>${escapeHtml(label)}</span><output>Cor ${selected}</output></div>
        <div class="swatches" role="listbox" aria-label="${escapeHtml(label)}">
          ${palette.map((entry) => `
            <button class="swatch ${entry.index === selected ? "is-active" : ""}" type="button"
              style="--swatch:${entry.color}" data-color-path="${path}" data-color-index="${entry.index}"
              title="Cor ${entry.index}" aria-label="Selecionar cor ${entry.index}" aria-selected="${entry.index === selected}"></button>`).join("")}
        </div>
      </div>`;
  }

  function overlayControls(key, label, options = {}) {
    const limit = overlayLimits[key] ?? 30;
    const controls = [
      sliderTemplate({ label: `${label}: estilo`, path: `headOverlays.${key}.style`, min: 0, max: limit, step: 1 }),
      sliderTemplate({ label: "Intensidade", path: `headOverlays.${key}.opacity`, min: 0, max: 1, step: 0.01, format: "percent" }),
    ];
    if (options.color) controls.push(swatchesTemplate("Cor", `headOverlays.${key}.color`, hairPalette));
    return controls.join("");
  }

  function faceSettings() {
    return faceGroups
      .map((group) => moduleTemplate(
        group.title.toUpperCase(),
        group.icon,
        group.subtitle,
        `<div class="slider-stack">${group.controls.map(([label, path]) => sliderTemplate({ label, path, min: -1, max: 1, step: 0.01, format: "neutral" })).join("")}</div>`,
      ))
      .join("");
  }

  function skinSettings() {
    return [
      moduleTemplate("IDADE E COMPLEXÃO", "sparkles", "Textura, idade e exposição natural.", `<div class="slider-stack">
        ${overlayControls("ageing", "Envelhecimento")}
        ${overlayControls("complexion", "Textura da pele")}
        ${overlayControls("sunDamage", "Danos solares")}
      </div>`),
      moduleTemplate("CORPO", "sparkles", "Detalhes corporais disponíveis no modelo.", `<div class="slider-stack">
        ${overlayControls("bodyBlemishes", "Imperfeições corporais")}
        ${overlayControls("addBodyBlemishes", "Imperfeições adicionais")}
      </div>`),
    ].join("");
  }

  function hairSettings() {
    return [
      moduleTemplate("CABELO", "scissors", "Corte, textura e variações instaladas.", `<div class="slider-stack">
        ${sliderTemplate({ label: "Corte", path: "hair.style", min: 0, max: 80, step: 1 })}
        ${sliderTemplate({ label: "Textura", path: "hair.texture", min: 0, max: 20, step: 1 })}
      </div>
      <div style="height:10px"></div>
      ${swatchesTemplate("Cor principal", "hair.color", hairPalette)}
      <div style="height:10px"></div>
      ${swatchesTemplate("Mechas", "hair.highlight", hairPalette)}`),
    ].join("");
  }

  function eyebrowSettings() {
    return moduleTemplate(
      "SOBRANCELHAS",
      "sparkles",
      "Formato, intensidade e tonalidade.",
      `<div class="slider-stack">${overlayControls("eyebrows", "Sobrancelha", { color: true })}</div>`,
    );
  }

  function eyeSettings() {
    return [
      moduleTemplate("OLHOS", "eye", "Cor e abertura do olhar.", `
        ${swatchesTemplate("Cor dos olhos", "eyeColor", eyePalette)}
        <div style="height:10px"></div>
        <div class="slider-stack">${sliderTemplate({ label: "Abertura dos olhos", path: "faceFeatures.eyesOpening", min: -1, max: 1, step: 0.01, format: "neutral" })}</div>`),
    ].join("");
  }

  function beardSettings() {
    return [
      moduleTemplate("BARBA", "beard", "Pelos faciais e tonalidade.", `<div class="slider-stack">${overlayControls("facialHair", "Barba", { color: true })}</div>`),
      moduleTemplate("PELOS DO PEITO", "beard", "Detalhes corporais opcionais.", `<div class="slider-stack">${overlayControls("chestHair", "Pelos do peito", { color: true })}</div>`),
    ].join("");
  }

  function makeupSettings() {
    return [
      moduleTemplate("MAQUIAGEM", "palette", "Estilo, intensidade e cor.", `<div class="slider-stack">${overlayControls("makeup", "Maquiagem", { color: true })}</div>`),
      moduleTemplate("BLUSH E BATOM", "palette", "Cores e intensidade do acabamento.", `<div class="slider-stack">
        ${overlayControls("blush", "Blush", { color: true })}
        ${overlayControls("lipstick", "Batom", { color: true })}
      </div>`),
    ].join("");
  }

  function marksSettings() {
    return [
      moduleTemplate("ROSTO", "star", "Imperfeições, sardas e sinais.", `<div class="slider-stack">
        ${overlayControls("blemishes", "Imperfeições")}
        ${overlayControls("molesFreckles", "Sardas e sinais")}
      </div>`),
      moduleTemplate("DETALHES NATURAIS", "star", "Use intensidades baixas para resultados sutis.", `<div class="section-note">${icon("info")}<span>Os índices são os mesmos utilizados pelo FiveM. A opacidade zero mantém o detalhe invisível sem alterar o índice salvo.</span></div>`),
    ].join("");
  }

  function clothingSettings() {
    const componentControls = Object.entries(componentLabels)
      .map(([id, label]) => `
        ${sliderTemplate({ label: `${label}: modelo`, path: `components.${id}.drawable`, min: 0, max: 255, step: 1 })}
        ${sliderTemplate({ label: `${label}: textura`, path: `components.${id}.texture`, min: 0, max: 100, step: 1 })}`)
      .join("");
    const propControls = Object.entries(propLabels)
      .map(([id, label]) => `
        ${sliderTemplate({ label: `${label}: modelo`, path: `props.${id}.drawable`, min: -1, max: 255, step: 1 })}
        ${sliderTemplate({ label: `${label}: textura`, path: `props.${id}.texture`, min: 0, max: 100, step: 1 })}`)
      .join("");
    return [
      moduleTemplate("VESTUÁRIO", "shirt", "Componentes iniciais do modelo freemode.", `<div class="slider-stack">${componentControls}</div>`),
      moduleTemplate("ACESSÓRIOS", "shirt", "Props removíveis e suas texturas.", `<div class="slider-stack">${propControls}</div>`),
    ].join("");
  }

  function reviewSettings() {
    const identity = state.identity || {};
    const father = fatherCatalog.find((entry) => entry.id === findSelectedParent("father"));
    const mother = motherCatalog.find((entry) => entry.id === findSelectedParent("mother"));
    const gender = genderForModel(state.appearance?.model) === "female" ? "Feminino" : "Masculino";
    return [
      moduleTemplate("RESUMO FINAL", "clipboard", "Confira os dados antes de salvar.", `
        <div class="review-grid">
          <div class="review-card"><span>Personagem</span><strong>${escapeHtml(`${identity.firstname || "Sem nome"} ${identity.lastname || ""}`.trim())}</strong></div>
          <div class="review-card"><span>Modelo</span><strong>${gender}</strong></div>
          <div class="review-card"><span>Nascimento</span><strong>${escapeHtml(identity.birthdate || "Não informado")}</strong></div>
          <div class="review-card"><span>Nacionalidade</span><strong>${escapeHtml(identity.nationality || "Não informada")}</strong></div>
          <div class="review-card"><span>Pai</span><strong>${escapeHtml(father?.name || "Padrão")}</strong></div>
          <div class="review-card"><span>Mãe</span><strong>${escapeHtml(mother?.name || "Padrão")}</strong></div>
          <div class="review-card"><span>Cabelo</span><strong>Modelo ${Number(state.appearance?.hair?.style ?? 0)}</strong></div>
          <div class="review-card"><span>Olhos</span><strong>Cor ${Number(state.appearance?.eyeColor ?? 0)}</strong></div>
        </div>
        <div class="section-note">${icon("info")}<span>Ao salvar, o servidor continuará validando identidade, modelo e aparência usando os mesmos callbacks existentes.</span></div>`),
    ].join("");
  }

  function identitySettings() {
    return identityModule() + modelModule() + heritageModule(true);
  }

  function renderSettings() {
    if (!state.appearance) return;
    const renderers = {
      identity: identitySettings,
      heritage: () => heritageModule(false),
      face: faceSettings,
      skin: skinSettings,
      hair: hairSettings,
      eyebrows: eyebrowSettings,
      eyes: eyeSettings,
      beard: beardSettings,
      makeup: makeupSettings,
      marks: marksSettings,
      review: reviewSettings,
    };
    settingsContentEl.innerHTML = (renderers[state.activeCategory] || identitySettings)();
    settingsContentEl.scrollTop = 0;
    settingsContentEl.classList.remove("is-entering");
    void settingsContentEl.offsetWidth;
    settingsContentEl.classList.add("is-entering");
    syncRangeVisuals();
  }

  function syncRangeVisuals(root = settingsContentEl) {
    root.querySelectorAll('input[type="range"]').forEach((input) => {
      const min = Number(input.min);
      const max = Number(input.max);
      const value = Number(input.value);
      const percentage = max === min ? 0 : ((value - min) / (max - min)) * 100;
      input.style.setProperty("--range-progress", `${percentage}%`);
    });
  }

  function updateRangeInput(input) {
    const path = input.dataset.path;
    if (!path || !state.appearance) return;
    const step = Number(input.step || 1);
    const value = step < 1 ? Number(input.value) : Math.round(Number(input.value));
    setPath(state.appearance, path, value);
    const output = settingsContentEl.querySelector(`[data-output-for="${path}"]`);
    const definition = {
      step,
      format: path.includes("Mix") || path.endsWith("opacity") ? "percent" : path.startsWith("faceFeatures.") ? "neutral" : undefined,
    };
    if (output) output.textContent = formatValue(value, definition);
    syncRangeVisuals(input.parentElement);
    schedulePreview();
  }

  function selectParent(type, id) {
    const numeric = Number(id);
    if (!Number.isInteger(numeric) || !state.appearance) return;
    if (type === "father") {
      state.appearance.headBlend.shapeFirst = numeric;
      state.appearance.headBlend.skinFirst = numeric;
    } else {
      state.appearance.headBlend.shapeSecond = numeric;
      state.appearance.headBlend.skinSecond = numeric;
    }
    schedulePreview();
    renderSettings();
  }

  function changeParentPage(type, direction) {
    const catalog = type === "father" ? fatherCatalog : motherCatalog;
    const pageCount = Math.ceil(catalog.length / 3);
    state.parentPages[type] = (state.parentPages[type] + direction + pageCount) % pageCount;
    renderSettings();
  }

  async function changeModel(model) {
    const fallback = state.defaults?.[model];
    if (!fallback) {
      showToast("O modelo selecionado não está disponível.");
      return;
    }
    state.appearance = normalizeAppearance(fallback);
    state.identity = state.identity || buildIdentity({}, state.appearance);
    state.identity.gender = genderForModel(model);
    syncParentPages();
    renderSettings();

    try {
      const result = await post("setModel", { model });
      if (result?.appearance) {
        state.appearance = normalizeAppearance(result.appearance);
        syncParentPages();
        renderSettings();
      }
    } catch {
      showToast("Não foi possível trocar o modelo.");
    }
  }

  function randomBetween(min, max, step = 1) {
    const steps = Math.floor((max - min) / step);
    return min + Math.floor(Math.random() * (steps + 1)) * step;
  }

  function randomizeCurrentCategory() {
    if (!state.appearance) return;
    const randomFeature = () => Number((Math.random() * 1.2 - 0.6).toFixed(2));
    const randomOverlay = (key, max, useColor = false) => {
      const enabled = Math.random() > 0.28;
      const overlay = state.appearance.headOverlays[key] || (state.appearance.headOverlays[key] = {});
      overlay.style = randomBetween(0, max, 1);
      overlay.opacity = enabled ? Number((0.25 + Math.random() * 0.65).toFixed(2)) : 0;
      if (useColor) {
        overlay.color = randomBetween(0, 31, 1);
        overlay.secondaryColor = overlay.color;
      }
    };

    switch (state.activeCategory) {
      case "heritage": {
        const father = fatherCatalog[Math.floor(Math.random() * fatherCatalog.length)];
        const mother = motherCatalog[Math.floor(Math.random() * motherCatalog.length)];
        state.appearance.headBlend.shapeFirst = father.id;
        state.appearance.headBlend.skinFirst = father.id;
        state.appearance.headBlend.shapeSecond = mother.id;
        state.appearance.headBlend.skinSecond = mother.id;
        state.appearance.headBlend.shapeMix = Number((0.25 + Math.random() * 0.5).toFixed(2));
        state.appearance.headBlend.skinMix = Number((0.25 + Math.random() * 0.5).toFixed(2));
        syncParentPages();
        break;
      }
      case "face":
        Object.keys(state.appearance.faceFeatures).forEach((key) => {
          state.appearance.faceFeatures[key] = randomFeature();
        });
        break;
      case "skin":
        randomOverlay("ageing", overlayLimits.ageing);
        randomOverlay("complexion", overlayLimits.complexion);
        randomOverlay("sunDamage", overlayLimits.sunDamage);
        break;
      case "hair":
        state.appearance.hair.style = randomBetween(0, 80, 1);
        state.appearance.hair.texture = 0;
        state.appearance.hair.color = randomBetween(0, 31, 1);
        state.appearance.hair.highlight = randomBetween(0, 31, 1);
        break;
      case "eyebrows":
        randomOverlay("eyebrows", overlayLimits.eyebrows, true);
        break;
      case "eyes":
        state.appearance.eyeColor = randomBetween(0, 31, 1);
        state.appearance.faceFeatures.eyesOpening = randomFeature();
        break;
      case "beard":
        randomOverlay("facialHair", overlayLimits.facialHair, true);
        randomOverlay("chestHair", overlayLimits.chestHair, true);
        break;
      case "makeup":
        randomOverlay("makeup", overlayLimits.makeup, true);
        randomOverlay("blush", overlayLimits.blush, true);
        randomOverlay("lipstick", overlayLimits.lipstick, true);
        break;
      case "marks":
        randomOverlay("blemishes", overlayLimits.blemishes);
        randomOverlay("molesFreckles", overlayLimits.molesFreckles);
        break;
      default:
        showToast("A randomização desta etapa foi bloqueada para evitar dados inválidos.", "info");
        return;
    }
    schedulePreview();
    renderSettings();
  }

  function validateBeforeSave() {
    const identity = state.identity || {};
    if (!String(identity.firstname || "").trim()) return "Informe o nome do personagem.";
    if (!String(identity.lastname || "").trim()) return "Informe o sobrenome do personagem.";
    if (!String(identity.birthdate || "").trim()) return "Informe a data de nascimento.";
    if (!String(identity.nationality || "").trim()) return "Informe a nacionalidade.";
    return null;
  }

  async function saveCharacter() {
    if (!state.appearance || state.saving) return;
    const validationError = validateBeforeSave();
    if (validationError) {
      showToast(validationError);
      setActiveCategory("identity", { force: true });
      return;
    }

    state.saving = true;
    saveButtonEl.disabled = true;
    const previousText = saveButtonEl.querySelector("span").textContent;
    saveButtonEl.querySelector("span").textContent = "SALVANDO...";

    try {
      const result = await post("saveCharacter", {
        identity: state.identity,
        appearance: state.appearance,
      });
      if (!result || result.ok !== true) {
        showToast(result?.detail || result?.error || "Não foi possível salvar.");
      }
    } catch {
      showToast("Não foi possível salvar o personagem.");
    } finally {
      state.saving = false;
      saveButtonEl.disabled = false;
      saveButtonEl.querySelector("span").textContent = previousText;
    }
  }

  function requestClose() {
    post("close")
      .then((result) => {
        if (!result || result.ok !== true) {
          showToast(result?.detail || result?.error || "Salve o personagem antes de sair.");
        }
      })
      .catch(() => {
        if (state.mode === "first_login") {
          showToast("Salve o personagem antes de sair.");
          return;
        }
        closeCreator();
      });
  }

  function openCreator(data) {
    state.open = true;
    state.mode = data.mode || "manual";
    state.defaults = data.defaults || {};
    state.appearance = normalizeAppearance(
      data.appearance || state.defaults.mp_m_freemode_01 || previewAppearance(),
    );
    state.identity = buildIdentity(data.state?.player?.charinfo, state.appearance);
    state.allowCameraRotation = data.allowCameraRotation !== false;
    state.activeCategory = "identity";
    syncParentPages();

    document.body.classList.add("is-open");
    creatorEl.setAttribute("aria-hidden", "false");
    document.querySelectorAll("#rotate-left, #rotate-right").forEach((button) => {
      button.hidden = !state.allowCameraRotation;
    });
    syncActiveCategoryVisuals();
    setCameraMode("body", false);
    renderSettings();
  }

  function closeCreator() {
    state.open = false;
    state.mode = "manual";
    state.saving = false;
    window.clearTimeout(state.previewTimer);
    document.body.classList.remove("is-open");
    creatorEl.setAttribute("aria-hidden", "true");
  }

  function previewAppearance(model = "mp_m_freemode_01") {
    const overlay = (opacity = 0) => ({ style: 0, opacity });
    return {
      version: 1,
      model,
      headBlend: { shapeFirst: 13, shapeSecond: 25, shapeThird: 0, skinFirst: 13, skinSecond: 25, skinThird: 0, shapeMix: 0.46, skinMix: 0.48, thirdMix: 0 },
      faceFeatures: {
        noseWidth: 0, nosePeakHeight: 0, nosePeakLength: 0, noseBoneHeight: 0,
        nosePeakLowering: 0, noseBoneTwist: 0, eyebrowHeight: 0, eyebrowDepth: 0,
        cheekboneHeight: 0, cheekboneWidth: 0, cheeksWidth: 0, eyesOpening: 0,
        lipsThickness: 0, jawBoneWidth: 0, jawBoneLength: 0, chinBoneHeight: 0,
        chinBoneLength: 0, chinBoneWidth: 0, chinHole: 0, neckThickness: 0,
      },
      headOverlays: {
        blemishes: overlay(), facialHair: { ...overlay(0.7), color: 2, secondaryColor: 2 },
        eyebrows: { ...overlay(1), color: 2, secondaryColor: 2 }, ageing: overlay(),
        makeup: { ...overlay(), color: 0, secondaryColor: 0 }, blush: { ...overlay(), color: 0 },
        complexion: overlay(), sunDamage: overlay(), lipstick: { ...overlay(), color: 0 },
        molesFreckles: overlay(), chestHair: { ...overlay(), color: 0 }, bodyBlemishes: overlay(), addBodyBlemishes: overlay(),
      },
      hair: { style: 17, texture: 0, color: 2, highlight: 4 },
      eyeColor: 2,
      components: { "1": { drawable: 0, texture: 0 }, "3": { drawable: 15, texture: 0 }, "4": { drawable: 21, texture: 0 }, "5": { drawable: 0, texture: 0 }, "6": { drawable: 34, texture: 0 }, "7": { drawable: 0, texture: 0 }, "8": { drawable: 15, texture: 0 }, "9": { drawable: 0, texture: 0 }, "10": { drawable: 0, texture: 0 }, "11": { drawable: 15, texture: 0 } },
      props: { "0": { drawable: -1, texture: 0 }, "1": { drawable: -1, texture: 0 }, "2": { drawable: -1, texture: 0 }, "6": { drawable: -1, texture: 0 }, "7": { drawable: -1, texture: 0 } },
      tattoos: [],
    };
  }

  function previewDefaults() {
    return {
      mp_m_freemode_01: previewAppearance("mp_m_freemode_01"),
      mp_f_freemode_01: previewAppearance("mp_f_freemode_01"),
    };
  }

  menuEl.addEventListener("click", (event) => {
    const button = event.target.closest("[data-category]");
    if (button) setActiveCategory(button.dataset.category);
  });

  settingsContentEl.addEventListener("input", (event) => {
    const target = event.target;
    if (target.matches("[data-identity]")) {
      const key = target.dataset.identity;
      const max = key === "nationality" ? 32 : 24;
      if (target.type === "text") target.value = sanitizeText(target.value, max);
      state.identity[key] = target.value;
      return;
    }
    if (target.matches('input[type="range"][data-path]')) updateRangeInput(target);
  });

  settingsContentEl.addEventListener("change", (event) => {
    const target = event.target;
    if (target.matches("[data-identity]")) {
      state.identity[target.dataset.identity] = target.value;
    }
  });

  settingsContentEl.addEventListener("click", (event) => {
    const modelButton = event.target.closest("[data-model]");
    if (modelButton) {
      changeModel(modelButton.dataset.model);
      return;
    }

    const parentNav = event.target.closest("[data-parent-nav]");
    if (parentNav) {
      changeParentPage(parentNav.dataset.parentNav, Number(parentNav.dataset.direction));
      return;
    }

    const parentButton = event.target.closest("[data-parent-type][data-parent-id]");
    if (parentButton) {
      selectParent(parentButton.dataset.parentType, parentButton.dataset.parentId);
      return;
    }

    const swatch = event.target.closest("[data-color-path]");
    if (swatch) {
      setPath(state.appearance, swatch.dataset.colorPath, Number(swatch.dataset.colorIndex));
      schedulePreview();
      renderSettings();
      return;
    }

    const stepButton = event.target.closest("[data-step-path]");
    if (stepButton) {
      const path = stepButton.dataset.stepPath;
      const input = settingsContentEl.querySelector(`input[data-path="${path}"]`);
      if (!input) return;
      const next = clamp(Number(input.value) + Number(stepButton.dataset.step), Number(input.min), Number(input.max));
      input.value = String(next);
      input.dispatchEvent(new Event("input", { bubbles: true }));
    }
  });

  document.querySelectorAll(".camera-button").forEach((button) => {
    button.addEventListener("click", () => setCameraMode(button.dataset.mode));
  });

  document.getElementById("rotate-left").addEventListener("click", () => {
    post("rotate", { amount: -12 }).catch(() => {});
  });

  document.getElementById("rotate-right").addEventListener("click", () => {
    post("rotate", { amount: 12 }).catch(() => {});
  });

  document.getElementById("close-button").addEventListener("click", requestClose);
  randomButtonEl.addEventListener("click", randomizeCurrentCategory);
  saveButtonEl.addEventListener("click", saveCharacter);

  backButtonEl.addEventListener("click", () => {
    const index = categories.findIndex((entry) => entry.id === state.activeCategory);
    if (index <= 0) requestClose();
    else setActiveCategory(categories[index - 1].id);
  });

  window.addEventListener("message", (event) => {
    const data = event.data || {};
    if (data.action === "open") openCreator(data);
    if (data.action === "close") closeCreator();
  });

  window.addEventListener("resize", syncCategoryLayout, { passive: true });

  window.addEventListener("keydown", (event) => {
    if (!state.open) return;
    const typing = ["INPUT", "SELECT", "TEXTAREA"].includes(document.activeElement?.tagName);
    if (event.key === "Escape") {
      event.preventDefault();
      requestClose();
      return;
    }
    if (!typing && state.allowCameraRotation && event.key.toLowerCase() === "a") {
      post("rotate", { amount: -5 }).catch(() => {});
    }
    if (!typing && state.allowCameraRotation && event.key.toLowerCase() === "d") {
      post("rotate", { amount: 5 }).catch(() => {});
    }
  });

  renderCategoryMenu();

  const previewMode = new URLSearchParams(window.location.search).get("preview") === "1";

  if (previewMode) {
    const defaults = previewDefaults();
    openCreator({
      mode: "manual",
      defaults,
      appearance: defaults.mp_m_freemode_01,
      state: { player: { charinfo: { firstname: "Mazus", lastname: "Kiroz", birthdate: "1998-04-15", gender: "male", nationality: "Brasileira" } } },
      allowCameraRotation: true,
    });
  }

  if (!previewMode) post("ready").catch(() => {});
})();
