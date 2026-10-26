// Interacciones críticas del armario contra el simulado de Supabase (latencia local ≈ 0: mide el costo del cliente).
//   node perf.mjs [APP_URL] [MOCK_URL] [corridas=5]
import { chromium } from "playwright-core";
const APP = process.argv[2] ?? process.env.APP_URL, MOCK = process.argv[3] ?? process.env.MOCK_URL, RUNS = parseInt(process.argv[4] ?? "5", 10);
const median = (xs) => [...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)];
const browser = await chromium.launch({ executablePath: process.env.CHROME ?? "/usr/bin/google-chrome", args: ["--no-sandbox"] });

async function once(throttled) {
  await fetch(`${MOCK}/__reset`);
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: throttled, hasTouch: throttled });
  const page = await context.newPage();
  const cdp = await context.newCDPSession(page);
  await cdp.send("Performance.enable");
  if (throttled) await cdp.send("Emulation.setCPUThrottlingRate", { rate: 4 });
  await page.addInitScript(() => {
    window.__m = { inp: 0, tbt: 0 };
    new PerformanceObserver((l) => { for (const e of l.getEntries()) window.__m.inp = Math.max(window.__m.inp, e.duration); }).observe({ type: "event", durationThreshold: 16, buffered: true });
    new PerformanceObserver((l) => { for (const e of l.getEntries()) if (e.duration > 50) window.__m.tbt += e.duration - 50; }).observe({ type: "longtask", buffered: true });
  });
  await page.goto(APP);
  await page.getByRole("button", { name: "Continuar con Google" }).waitFor();
  const t0 = Date.now();
  await page.getByRole("button", { name: "Continuar con Google" }).click();
  await page.getByRole("tab", { name: /Prendas · 6/ }).waitFor();
  await page.waitForFunction(() => [...document.querySelectorAll(".card-img")].every((i) => i.tagName === "IMG" && i.complete && i.naturalWidth > 0));
  const login = Date.now() - t0;
  const tf = Date.now();
  await page.getByRole("button", { name: "SUPERIOR" }).click();
  await page.waitForFunction(() => document.querySelectorAll(".card").length === 2);
  const filter = Date.now() - tf;
  await page.getByRole("button", { name: "TODO" }).click();
  await page.waitForFunction(() => document.querySelectorAll(".card").length === 6);
  const td = Date.now();
  await page.getByRole("link", { name: "Abrir Camisa azul" }).click();
  await page.getByRole("heading", { name: "Camisa azul" }).waitFor();
  const detail = Date.now() - td;
  await page.getByRole("link", { name: "← Armario" }).click();
  await page.getByRole("tab", { name: /Prendas/ }).waitFor();
  await page.getByRole("checkbox", { name: "Seleccionar Jeans oscuros" }).check();
  await page.getByRole("button", { name: "Eliminar" }).click();
  await page.getByRole("dialog").waitFor();
  const tx = Date.now();
  await page.getByRole("dialog").getByRole("button", { name: "Eliminar" }).click();
  await page.getByRole("tab", { name: "Prendas · 5" }).waitFor();
  const del = Date.now() - tx;
  const heap = (await cdp.send("Performance.getMetrics")).metrics.find((m) => m.name === "JSHeapUsedSize")?.value ?? 0;
  const m = await page.evaluate(() => ({ ...window.__m }));
  await context.close();
  return { accesoYArmarioMs: login, filtrarMs: filter, abrirFichaMs: detail, borrarMs: del, inpMs: m.inp, tbtMs: m.tbt, heapMB: heap / 1048576 };
}
const out = { app: APP, runs: RUNS, chrome: browser.version(), nota: "Servidor simulado local: no incluye latencia de red ni de Supabase real.", profiles: {} };
for (const [name, throttled] of [["escritorio", false], ["telefono_cpu4x", true]]) {
  const rs = []; for (let i = 0; i < RUNS; i++) rs.push(await once(throttled));
  out.profiles[name] = Object.fromEntries(Object.keys(rs[0]).map((k) => [k, +median(rs.map((r) => r[k])).toFixed(1)]));
}
console.log(JSON.stringify(out, null, 2));
await browser.close();
