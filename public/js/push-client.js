/**
 * Mordecai's Maximus — Push notification subscription (must run after user gesture)
 */
(function () {
  "use strict";
  const STORAGE_BRIDGE_SECRET = "mordecai_bridge_secret";

  function $(id) {
    return document.getElementById(id);
  }

  function authHeaders() {
    try {
      const bridgeSecret = (localStorage.getItem(STORAGE_BRIDGE_SECRET) || "").trim();
      return bridgeSecret ? { "X-Bridge-Secret": bridgeSecret } : {};
    } catch (_) {
      return {};
    }
  }

  function setStatus(msg) {
    const el = $("pushStatus");
    if (el) el.textContent = msg || "";
  }

  function setBtnState(enabled, subscribed) {
    const btn = $("pushEnableBtn");
    const testBtn = $("pushTestBtn");
    if (!btn) return;
    if (subscribed) {
      btn.textContent = "Notifications enabled";
      btn.disabled = true;
      if (testBtn) {
        testBtn.style.display = "";
        testBtn.disabled = false;
      }
    } else {
      btn.textContent = "🔔 Enable notifications";
      btn.disabled = !enabled;
      if (testBtn) testBtn.style.display = "none";
    }
  }

  async function sendTestPush() {
    const testBtn = $("pushTestBtn");
    if (testBtn) testBtn.disabled = true;
    setStatus("Sending test…");
    try {
      const url = typeof apiUrl === "function" ? apiUrl("/api/push/test") : "/api/push/test";
      const res = await fetch(url, { method: "POST", headers: authHeaders() });
      if (!res.ok) throw new Error("Test failed");
      setStatus("Test sent! Close the app to verify you get it in the background.");
      setTimeout(() => setStatus(""), 4000);
    } catch (e) {
      setStatus(e.message || "Test failed");
    }
    if (testBtn) testBtn.disabled = false;
  }

  async function checkSubscription() {
    try {
      const reg = await navigator.serviceWorker.ready;
      const sub = await reg.pushManager.getSubscription();
      return !!sub;
    } catch (_) {
      return false;
    }
  }

  async function subscribe() {
    const btn = $("pushEnableBtn");
    if (!btn || btn.disabled) return;

    if (!("Notification" in window) || !("serviceWorker" in navigator)) {
      setStatus("Push not supported");
      return;
    }

    if (Notification.permission === "denied") {
      setStatus("Notifications blocked. Enable in browser settings.");
      return;
    }

    btn.disabled = true;
    setStatus("Requesting permission…");

    let permission = Notification.permission;
    if (permission === "default") {
      permission = await Notification.requestPermission();
    }

    if (permission !== "granted") {
      setStatus("Permission denied");
      setBtnState(true, false);
      return;
    }

    setStatus("Subscribing…");

    try {
      const reg = await navigator.serviceWorker.ready;
      const vapidRes = await fetch(typeof apiUrl === "function" ? apiUrl("/api/push/vapid") : "/api/push/vapid");
      if (!vapidRes.ok) {
        throw new Error("Push not configured");
      }
      const { publicKey } = await vapidRes.json();
      if (!publicKey) throw new Error("No VAPID key");

      const sub = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(publicKey),
      });

      const res = await fetch(typeof apiUrl === "function" ? apiUrl("/api/push/subscribe") : "/api/push/subscribe", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...authHeaders(),
        },
        body: JSON.stringify(sub.toJSON()),
      });

      if (!res.ok) throw new Error("Subscribe failed");
      setStatus("Enabled — you'll get alerts even when the app is closed");
      setBtnState(true, true);
    } catch (e) {
      console.error("Push subscribe error:", e);
      setStatus(e.message || "Subscribe failed");
      setBtnState(true, false);
    }
  }

  function urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");
    const rawData = atob(base64);
    const outputArray = new Uint8Array(rawData.length);
    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  }

  async function init() {
    const btn = $("pushEnableBtn");
    if (!btn) return;

    const supported = "Notification" in window && "serviceWorker" in navigator;
    if (!supported) {
      setStatus("Push not supported");
      setBtnState(false, false);
      return;
    }

    if (Notification.permission === "granted") {
      const subbed = await checkSubscription();
      if (subbed) {
        setStatus("Enabled — you'll get alerts even when the app is closed");
        setBtnState(true, true);
      } else {
        setStatus("Click to finish setup (subscribes for background alerts)");
        btn.addEventListener("click", subscribe);
        setBtnState(true, false);
      }
      return;
    }

    btn.addEventListener("click", subscribe);
    setBtnState(true, false);
  }

  const testBtn = $("pushTestBtn");
  if (testBtn) testBtn.addEventListener("click", sendTestPush);

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
