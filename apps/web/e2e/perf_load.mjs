// Carga en frío comparable entre dos apps: bytes por la red (gzip), FCP, LCP, TBT y tiempo hasta interfaz lista.
//   node perf_load.mjs NOMBRE URL SELECTOR_LISTO [corridas=5]
// Perfiles: escritorio sin limitar y «teléfono» (CPU x4, 4G: 1.6 Mbps/150 ms). Caché desactivada.
import { chromium } from "playwright-core";
const [name, url, ready, runsArg] = process.argv.slice(2);
const RUNS = parseInt(runsArg ?? "5", 10);
const median = (xs) => [...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)];
const browser = await chromium.launch({ executablePath: process.env.CHROME ?? "/usr/bin/google-chrome", args: ["--no-sandbox"] });

async function once(throttled) {
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: throttled, hasTouch: throttled });
  const page = await context.newPage();
  const cdp = await context.newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
  if (throttled) {
    await cdp.send("Emulation.setCPUThrottlingRate", { rate: 4 });
    await cdp.send("Network.emulateNetworkConditions", { offline: false, latency: 150, downloadThroughput: (1.6 * 1024 * 1024) / 8, uploadThroughput: (750 * 1024) / 8 });
  }
  const origin = new URL(url).origin, urls = new Map(); let own = 0, external = 0, count = 0;
  cdp.on("Network.responseReceived", (e) => urls.set(e.requestId, e.response.url));
  cdp.on("Network.loadingFinished", (e) => { const u = urls.get(e.requestId) ?? ""; if (!u.startsWith("http")) return; count++; if (u.startsWith(origin)) own += e.encodedDataLength; else external += e.encodedDataLength; });
  await page.addInitScript(() => {
    window.__m = { lcp: 0, fcp: 0, tbt: 0, cls: 0 };
    new PerformanceObserver((l) => { for (const e of l.getEntries()) window.__m.lcp = e.startTime; }).observe({ type: "largest-contentful-paint", buffered: true });
    new PerformanceObserver((l) => { for (const e of l.getEntries()) if (e.name === "first-contentful-paint") window.__m.fcp = e.startTime; }).observe({ type: "paint", buffered: true });
    new PerformanceObserver((l) => { for (const e of l.getEntries()) if (e.duration > 50) window.__m.tbt += e.duration - 50; }).observe({ type: "longtask", buffered: true });
    new PerformanceObserver((l) => { for (const e of l.getEntries()) if (!e.hadRecentInput) window.__m.cls += e.value; }).observe({ type: "layout-shift", buffered: true });
  });
  const t0 = Date.now();
  await page.goto(url, { waitUntil: "load" });
  await page.locator(ready).first().waitFor({ state: "attached", timeout: 120000 });
  const readyMs = Date.now() - t0;
  await page.waitForTimeout(1500);
  const m = await page.evaluate(() => ({ ...window.__m }));
  await context.close();
  return { ownKB: own / 1024, externalKB: external / 1024, requests: count, readyMs, fcpMs: m.fcp, lcpMs: m.lcp, tbtMs: m.tbt, cls: m.cls };
}
const out = { name, url, runs: RUNS, chrome: browser.version(), profiles: {} };
for (const [profile, throttled] of [["escritorio", false], ["telefono_cpu4x_4g", true]]) {
  const rs = []; for (let i = 0; i < RUNS; i++) rs.push(await once(throttled));
  out.profiles[profile] = Object.fromEntries(Object.keys(rs[0]).map((k) => [k, +median(rs.map((r) => r[k])).toFixed(k === "cls" ? 4 : 1)]));
}
console.log(JSON.stringify(out));
await browser.close();
