console.log("inject.js loaded (FINAL)");

(function () {

  function setOnce(el, key) {
    if (!el) return false;
    if (el.dataset[key]) return false;
    el.dataset[key] = "1";
    return true;
  }

  // Capture l’ID du challenge au clic sur .challenge-button
  document.addEventListener("click", (e) => {
    const btn = e.target.closest(".challenge-button");
    if (btn) {
      const cid = btn.getAttribute("value");
      if (cid) {
        window.__myplugin_cid = cid;
        console.log("[MyPlugin] Challenge clicked → id =", cid);
      }
    }
  });

  const observer = new MutationObserver(async () => {

    // =======================================================
    // BOUTON PDF (/user)
    // =======================================================
    if (/^\/user\/?$/.test(window.location.pathname)) {
      const h1 = document.querySelector("main .jumbotron .container h1");
      if (h1 && setOnce(h1, "pdfInjected")) {

        const me = await fetch("/api/v1/users/me").then(r => r.json()).catch(() => null);
        if (!me || !me.data) return;
        const uid = me.data.id;

        const a = document.createElement("a");
        a.href = "/report/user/" + uid + "/pdf";
        a.textContent = "⬇️ Download my report (PDF)";
        a.style.display = "block";
        a.style.marginTop = "10px";
        a.style.fontWeight = "bold";
        a.style.color = "#007bff";

        h1.insertAdjacentElement("afterend", a);
        console.log("[MyPlugin] PDF button injected");
      }
    }

    // =======================================================
    // BONUS DANS LA MODALE CHALLENGE
    // =======================================================
    const title = document.querySelector(".challenge-name");
    if (!title || !setOnce(title, "bonusInjected")) return;

    console.log("[MyPlugin] Modal opened. Resolving bonus…");

    let cid = window.__myplugin_cid;
    if (!cid) {
      console.warn("[MyPlugin] No challenge ID captured.");
      return;
    }

    // Appel backend
    const bonus = await fetch(`/report/bonus/${cid}`, { credentials: "same-origin" })
      .then(r => r.json()).catch(() => null);

    const box = document.createElement("div");
    box.style.marginTop = "10px";
    box.style.fontWeight = "bold";

    if (bonus && bonus.available) {
      box.style.color = "green";
      box.textContent = `⚡ Bonus available for the next ${bonus.remaining} solvers`;
    } else if (bonus) {
      box.style.color = "red";
      box.textContent = "⛔ Speed bonus expired.";
    } else {
      box.style.color = "green";
      box.textContent = "⚡ Bonus available for the next 5 solvers";
    }

    title.insertAdjacentElement("afterend", box);
    console.log("[MyPlugin] Bonus message displayed for challenge", cid);

  });

  observer.observe(document.body, { childList: true, subtree: true });
})();
