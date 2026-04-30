(function () {
  "use strict";

  const resource =
    typeof GetParentResourceName === "function"
      ? GetParentResourceName()
      : "mz_creator";

  const sliderDefs = [
    {
      label: "Mistura do rosto",
      path: "headBlend.shapeMix",
      min: 0,
      max: 1,
      step: 0.01,
    },
    {
      label: "Tom da pele",
      path: "headBlend.skinMix",
      min: 0,
      max: 1,
      step: 0.01,
    },
    { label: "Cabelo", path: "hair.style", min: 0, max: 80, step: 1 },
    { label: "Cor do cabelo", path: "hair.color", min: 0, max: 63, step: 1 },
    { label: "Cor dos olhos", path: "eyeColor", min: 0, max: 31, step: 1 },
    {
      label: "Largura do nariz",
      path: "faceFeatures.noseWidth",
      min: -1,
      max: 1,
      step: 0.01,
    },
    {
      label: "Altura do nariz",
      path: "faceFeatures.nosePeakHeight",
      min: -1,
      max: 1,
      step: 0.01,
    },
    {
      label: "Altura da sobrancelha",
      path: "faceFeatures.eyebrowHeight",
      min: -1,
      max: 1,
      step: 0.01,
    },
    {
      label: "Macas do rosto",
      path: "faceFeatures.cheekboneHeight",
      min: -1,
      max: 1,
      step: 0.01,
    },
    {
      label: "Maxilar",
      path: "faceFeatures.jawBoneWidth",
      min: -1,
      max: 1,
      step: 0.01,
    },
    {
      label: "Labios",
      path: "faceFeatures.lipsThickness",
      min: -1,
      max: 1,
      step: 0.01,
    },
    {
      label: "Queixo",
      path: "faceFeatures.chinBoneHeight",
      min: -1,
      max: 1,
      step: 0.01,
    },
  ];

  const state = {
    open: false,
    mode: "manual",
    defaults: {},
    appearance: null,
    identity: null,
    previewTimer: null,
  };

  const slidersEl = document.getElementById("sliders");
  const toastEl = document.getElementById("toast");
  const identityEls = {
    firstname: document.getElementById("firstname"),
    lastname: document.getElementById("lastname"),
    birthdate: document.getElementById("birthdate"),
    gender: document.getElementById("gender"),
    nationality: document.getElementById("nationality"),
  };

  function clone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  function post(name, data) {
    return fetch(`https://${resource}/${name}`, {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=UTF-8" },
      body: JSON.stringify(data || {}),
    }).then((response) => response.json());
  }

  function showToast(message) {
    toastEl.textContent = message || "Erro ao executar acao.";
    toastEl.classList.add("is-visible");
    setTimeout(() => toastEl.classList.remove("is-visible"), 2600);
  }

  function getPath(target, path) {
    return path
      .split(".")
      .reduce((acc, key) => (acc ? acc[key] : undefined), target);
  }

  function setPath(target, path, value) {
    const parts = path.split(".");
    const last = parts.pop();
    let cursor = target;

    for (const part of parts) {
      cursor[part] = cursor[part] || {};
      cursor = cursor[part];
    }

    cursor[last] = value;
  }

  function formatValue(value, step) {
    return Number(step) < 1
      ? Number(value).toFixed(2)
      : String(Math.floor(Number(value)));
  }

  function schedulePreview() {
    clearTimeout(state.previewTimer);
    state.previewTimer = setTimeout(() => {
      if (!state.appearance) return;
      post("previewAppearance", { appearance_json: state.appearance }).catch(
        () => {},
      );
    }, 45);
  }

  function syncModelButtons() {
    document.querySelectorAll(".model-button").forEach((button) => {
      button.classList.toggle(
        "is-active",
        button.dataset.model === state.appearance?.model,
      );
    });
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

  function syncIdentityFields() {
    if (!state.identity) return;
    identityEls.firstname.value = state.identity.firstname || "";
    identityEls.lastname.value = state.identity.lastname || "";
    identityEls.birthdate.value = state.identity.birthdate || "";
    identityEls.gender.value = state.identity.gender || "male";
    identityEls.nationality.value = state.identity.nationality || "";
  }

  function readIdentity() {
    return {
      firstname: identityEls.firstname.value.trim(),
      lastname: identityEls.lastname.value.trim(),
      birthdate: identityEls.birthdate.value,
      gender: identityEls.gender.value,
      nationality: identityEls.nationality.value.trim(),
      phone: state.identity?.phone || "",
    };
  }

  function renderSliders() {
    slidersEl.innerHTML = "";

    for (const def of sliderDefs) {
      const value = getPath(state.appearance, def.path) ?? def.min;
      const row = document.createElement("label");
      row.className = "slider-row";

      const label = document.createElement("div");
      label.className = "slider-label";

      const text = document.createElement("span");
      text.textContent = def.label;

      const output = document.createElement("output");
      output.textContent = formatValue(value, def.step);

      const input = document.createElement("input");
      input.type = "range";
      input.min = String(def.min);
      input.max = String(def.max);
      input.step = String(def.step);
      input.value = String(value);

      input.addEventListener("input", () => {
        const next =
          Number(def.step) < 1
            ? Number(input.value)
            : Math.floor(Number(input.value));
        setPath(state.appearance, def.path, next);
        output.textContent = formatValue(next, def.step);
        schedulePreview();
      });

      label.append(text, output);
      row.append(label, input);
      slidersEl.append(row);
    }
  }

  function setCameraButton(mode) {
    document.querySelectorAll(".camera-button").forEach((button) => {
      button.classList.toggle("is-active", button.dataset.mode === mode);
    });
  }

  function openCreator(data) {
    state.open = true;
    state.mode = data.mode || "manual";
    state.defaults = data.defaults || {};
    state.appearance = clone(
      data.appearance || state.defaults.mp_m_freemode_01,
    );
    state.identity = buildIdentity(
      data.state?.player?.charinfo,
      state.appearance,
    );
    document.body.classList.add("is-open");
    syncModelButtons();
    syncIdentityFields();
    setCameraButton("face");
    renderSliders();

    // Oculta botões de rotação se não permitido
    const rotateButtons = document.querySelectorAll(
      "#rotate-left, #rotate-right",
    );
    if (data.allowCameraRotation === false) {
      rotateButtons.forEach((btn) => (btn.style.display = "none"));
    } else {
      rotateButtons.forEach((btn) => (btn.style.display = ""));
    }
  }

  function closeCreator() {
    state.open = false;
    state.mode = "manual";
    document.body.classList.remove("is-open");
  }

  function requestClose() {
    post("close")
      .then((result) => {
        if (!result || result.ok !== true) {
          showToast(
            result?.detail ||
              result?.error ||
              "Salve seu personagem antes de sair.",
          );
        }
      })
      .catch(() => {
        if (state.mode === "first_login") {
          showToast("Salve seu personagem antes de sair.");
          return;
        }

        closeCreator();
      });
  }

  window.addEventListener("message", (event) => {
    const data = event.data || {};
    if (data.action === "open") openCreator(data);
    if (data.action === "close") closeCreator();
  });

  document.querySelectorAll(".model-button").forEach((button) => {
    button.addEventListener("click", () => {
      const model = button.dataset.model;
      const fallback = state.defaults[model];
      if (!fallback) return;

      state.appearance = clone(fallback);
      state.identity = state.identity || buildIdentity({}, state.appearance);
      state.identity.gender = genderForModel(model);
      syncModelButtons();
      syncIdentityFields();
      renderSliders();

      post("setModel", { model })
        .then((result) => {
          if (result?.appearance) {
            state.appearance = result.appearance;
            renderSliders();
          }
        })
        .catch(() => showToast("Nao foi possivel trocar o modelo."));
    });
  });

  document.querySelectorAll(".camera-button").forEach((button) => {
    button.addEventListener("click", () => {
      const mode = button.dataset.mode;
      setCameraButton(mode);
      post("setCameraMode", { mode }).catch(() => {});
    });
  });

  identityEls.gender.addEventListener("change", () => {
    const model = modelForGender(identityEls.gender.value);
    const fallback = state.defaults[model];
    if (!fallback) return;

    state.identity = readIdentity();
    state.appearance = clone(fallback);
    syncModelButtons();
    renderSliders();

    post("setModel", { model })
      .then((result) => {
        if (result?.appearance) {
          state.appearance = result.appearance;
          renderSliders();
        }
      })
      .catch(() => showToast("Nao foi possivel trocar o modelo."));
  });

  document.getElementById("rotate-left").addEventListener("click", () => {
    post("rotate", { amount: -12 }).catch(() => {});
  });

  document.getElementById("rotate-right").addEventListener("click", () => {
    post("rotate", { amount: 12 }).catch(() => {});
  });

  document.getElementById("cancel-button").addEventListener("click", () => {
    requestClose();
  });

  document.getElementById("save-button").addEventListener("click", () => {
    if (!state.appearance) return;
    state.identity = readIdentity();

    post("saveCharacter", {
      identity: state.identity,
      appearance: state.appearance,
    })
      .then((result) => {
        if (!result || result.ok !== true) {
          showToast(
            result?.detail || result?.error || "Nao foi possivel salvar.",
          );
        }
      })
      .catch(() => showToast("Nao foi possivel salvar."));
  });

  window.addEventListener("keydown", (event) => {
    if (!state.open) return;
    if (event.key.toLowerCase() === "a")
      post("rotate", { amount: -5 }).catch(() => {});
    if (event.key.toLowerCase() === "d")
      post("rotate", { amount: 5 }).catch(() => {});
    if (event.key === "Escape") requestClose();
  });

  post("ready").catch(() => {});
})();
