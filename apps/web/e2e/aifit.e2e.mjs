// Pruebas de navegador de apps/web contra el simulado del protocolo de Supabase (ver scripts/e2e_web.sh).
// Variables: MOCK_URL, APP_URL (compilada contra el simulado), BARE_URL (compilada sin configuración), CHROME.
import test, { after, before } from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { chromium } from "playwright-core";

const { MOCK_URL, APP_URL, BARE_URL } = process.env;
const require = createRequire(import.meta.url);
const AXE = readFileSync(require.resolve("axe-core/axe.min.js"), "utf8");
let browser;
before(async () => { browser = await chromium.launch({ executablePath: process.env.CHROME ?? "/usr/bin/google-chrome", args: ["--no-sandbox"] }); });
after(async () => browser?.close());

const mock = async (path) => (await fetch(`${MOCK_URL}${path}`)).json();
const reset = () => mock("/__reset");
const calls = async () => (await mock("/__log")).map((r) => `${r.method} ${r.path}`);

async function open({ url = APP_URL, viewport = { width: 1100, height: 800 }, allow = [] } = {}) {
  await reset();
  const context = await browser.newContext({ viewport });
  const page = await context.newPage();
  const consoleText = [], problems = [];
  page.on("console", (m) => { consoleText.push(m.text()); if (m.type() === "error" && !allow.some((a) => m.text().includes(a))) problems.push(`console: ${m.text()}`); });
  page.on("pageerror", (e) => problems.push(`pageerror: ${e}`));
  page.on("requestfailed", (r) => { const text = `${r.url()} ${r.failure()?.errorText}`; if (!allow.some((a) => text.includes(a))) problems.push(`requestfailed: ${text}`); });
  await page.goto(url);
  return { page, context, problems, consoleText };
}
async function login(page) {
  await page.getByRole("button", { name: "Continuar con Google" }).click();
  await page.getByRole("tab", { name: /Prendas · \d+/ }).waitFor();
}
const names = (page) => page.locator(".card-name").allTextContents();
async function axe(page, label) {
  await page.evaluate(AXE);
  const result = await page.evaluate(() => axe.run(document, { runOnly: ["wcag2a", "wcag2aa", "best-practice"] }));
  const serious = result.violations.filter((v) => ["serious", "critical"].includes(v.impact));
  assert.deepEqual(serious.map((v) => `${v.id}: ${v.nodes.map((n) => n.target.join(" ")).join(" | ")}`), [], `axe (${label})`);
}
const finish = async ({ context, problems }) => { await context.close(); assert.deepEqual(problems, [], "errores de consola/red"); };

test("sin configuración: explica qué falta y no intenta iniciar sesión", async () => {
  const s = await open({ url: BARE_URL });
  await s.page.getByRole("heading", { name: "Falta configurar Supabase" }).waitFor();
  assert.equal(await s.page.getByRole("button", { name: "Continuar con Google" }).count(), 0);
  await finish(s);
});

test("pantalla de acceso: marca, texto y botón; sin errores", async () => {
  const s = await open();
  await s.page.getByRole("heading", { name: "Tu atelier de moda con IA" }).waitFor();
  assert.equal(await s.page.title(), "AIFit · Armario");
  assert.equal(await s.page.locator("main").count(), 1);
  await axe(s.page, "acceso");
  await finish(s);
});

test("acceso con Google (PKCE verificado) y URL limpia; la sesión queda guardada", async () => {
  const s = await open();
  const { page } = s;
  await login(page);
  assert.equal(new URL(page.url()).search, "", "el ?code= se quita de la barra de direcciones");
  const first = await calls();
  assert.ok(first.some((c) => c.startsWith("GET /auth/v1/authorize")));
  assert.ok(first.includes("POST /auth/v1/token"), "se canjeó el código");
  const authorize = (await mock("/__log")).find((r) => r.path === "/auth/v1/authorize");
  assert.equal(authorize.query.code_challenge_method, "s256");
  assert.equal(authorize.query.provider, "google");
  await page.getByText("Ana Prueba").first().waitFor();
  assert.ok(await page.evaluate(() => localStorage.getItem("aifit.web.session")), "la sesión queda guardada");
  await finish(s);
});

test("recargar con sesión vigente no vuelve a pasar por Google", async () => {
  const s = await open();
  const { page } = s;
  await login(page);
  const before = (await calls()).filter((c) => c.includes("/authorize")).length;
  await page.reload();
  await page.getByRole("tab", { name: /Prendas · 6/ }).waitFor();
  const after = (await calls()).filter((c) => c.includes("/authorize")).length;
  assert.equal(after, before, "sin nueva redirección OAuth");
  await finish(s);
});

test("armario: 6 prendas, imágenes (firmadas y directas) cargan y el estado de procesamiento se ve", async () => {
  const s = await open();
  const { page } = s;
  await login(page);
  assert.deepEqual(await names(page), ["Camisa azul", "Jeans oscuros", "Vestido rojo", "Tenis blancos", "Abrigo gris", "Playera negra"]);
  await page.waitForFunction(() => [...document.querySelectorAll(".card-img")].every((i) => i.tagName === "IMG" && i.complete && i.naturalWidth > 0));
  const log = await calls();
  assert.ok(log.includes("POST /storage/v1/object/sign/user-media/u/camisa.svg"), "las rutas de Storage se firman");
  assert.ok(!log.some((c) => c.includes("sign/user-media") && c.includes("jeans")), "una URL completa no se vuelve a firmar");
  assert.match(await page.locator(".card").nth(2).locator("img").getAttribute("src"), /vestido-cut\.svg/, "el recorte tiene prioridad");
  await page.getByText("Procesando…").waitFor();
  await page.getByText("Falló el procesamiento").waitFor();
  await finish(s);
});

test("filtros por categoría usan las mismas reglas que la app móvil", async () => {
  const s = await open();
  const { page } = s;
  await login(page);
  await page.getByRole("button", { name: "PIEZA ÚNICA" }).click();
  assert.deepEqual(await names(page), ["Vestido rojo"], "category «dress» se normaliza a pieza única");
  assert.equal(await page.getByRole("button", { name: "PIEZA ÚNICA" }).getAttribute("aria-pressed"), "true");
  await page.getByRole("button", { name: "SUPERIOR" }).click();
  assert.deepEqual(await names(page), ["Camisa azul", "Playera negra"]);
  await page.getByRole("button", { name: "TODO" }).click();
  assert.equal(await page.locator(".card").count(), 6);
  await finish(s);
});

test("borrado: cancelar no borra; confirmar quita outfit_items y luego las prendas", async () => {
  const s = await open();
  const { page } = s;
  await login(page);
  await page.getByRole("checkbox", { name: "Seleccionar Camisa azul" }).check();
  await page.locator(".card-open").nth(5).click(); // con selección activa marca en vez de abrir
  await page.getByText("2 seleccionadas").waitFor();
  assert.equal(new URL(page.url()).hash, "");
  await page.getByRole("button", { name: "Eliminar" }).click();
  const dialog = page.getByRole("dialog", { name: "¿Eliminar 2 prendas?" });
  await dialog.waitFor();
  await dialog.getByRole("button", { name: "Cancelar" }).click();
  assert.equal(await page.locator(".card").count(), 6);
  await page.getByRole("button", { name: "Eliminar" }).click();
  await page.getByRole("dialog").getByRole("button", { name: "Eliminar" }).click();
  await page.getByText("2 prendas eliminadas").waitFor();
  await page.getByRole("tab", { name: "Prendas · 4" }).waitFor();
  const deletes = (await calls()).filter((c) => c.startsWith("DELETE"));
  assert.deepEqual(deletes, ["DELETE /rest/v1/outfit_items", "DELETE /rest/v1/wardrobe_items"]);
  const wardrobeDelete = (await mock("/__log")).find((r) => r.method === "DELETE" && r.path.endsWith("wardrobe_items"));
  assert.equal(wardrobeDelete.query.user_id, "eq.11111111-1111-4111-8111-111111111111");
  await finish(s);
});

test("si el servidor rechaza el borrado: aviso con el motivo y la prenda sigue", async () => {
  const s = await open();
  const { page } = s;
  await login(page);
  await mock("/__mode?deleteFails=1");
  await page.getByRole("checkbox", { name: "Seleccionar Jeans oscuros" }).check();
  await page.getByRole("button", { name: "Eliminar" }).click();
  await page.getByRole("dialog").getByRole("button", { name: "Eliminar" }).click();
  await page.getByText(/No se pudieron eliminar las prendas/).waitFor();
  assert.equal(await page.locator(".card").count(), 6);
  await finish(s);
});

test("detalle: ficha en español, ruta recargable y borrado desde la ficha", async () => {
  const s = await open();
  const { page } = s;
  await login(page);
  await page.getByRole("link", { name: "Abrir Vestido rojo" }).click();
  await page.getByRole("heading", { name: "Vestido rojo" }).waitFor();
  assert.match(new URL(page.url()).hash, /^#\/prenda\/it-3$/);
  assert.deepEqual(await page.locator("dt").allTextContents(), ["Categoría", "Tipo", "Colores", "Estilo", "Temporada", "Agregada"]);
  assert.equal(await page.locator("dd").nth(0).textContent(), "Pieza Única");
  await page.reload(); // ruta profunda: restaura la sesión y vuelve a leer las prendas
  await page.getByRole("heading", { name: "Vestido rojo" }).waitFor();
  await page.getByRole("button", { name: "Eliminar" }).click();
  await page.getByRole("dialog").getByRole("button", { name: "Eliminar" }).click();
  await page.getByText("Prenda eliminada").waitFor();
  await page.getByRole("tab", { name: "Prendas · 5" }).waitFor();
  assert.equal(new URL(page.url()).hash, "#/");
  await page.goto(`${APP_URL}/#/prenda/it-3`);
  await page.reload();
  await page.getByText("La prenda ya no existe.").waitFor();
  await finish(s);
});

test("perfil: datos, onboarding, fotos e identidad visual", async () => {
  const s = await open();
  const { page } = s;
  await login(page);
  await page.getByRole("link", { name: "Perfil" }).click();
  await page.getByRole("heading", { name: "Ana Prueba", level: 1 }).waitFor();
  const text = await page.locator("main").innerText();
  assert.match(text, /Onboarding\s+Completado/);
  assert.match(text, /Fotos de cuerpo\s+2/);
  assert.match(text, /Fotos de rostro\s+1/);
  assert.match(text, /Tono de piel\s+medium · warm/);
  assert.match(text, /Cabello\s+dark brown · wavy/);
  assert.equal(await page.getByRole("link", { name: "Perfil" }).getAttribute("aria-current"), "page");
  await finish(s);
});

test("cerrar sesión limpia el almacenamiento y vuelve al acceso", async () => {
  const s = await open();
  const { page } = s;
  await login(page);
  await page.getByRole("button", { name: "Salir" }).click();
  await page.getByRole("button", { name: "Continuar con Google" }).waitFor();
  assert.equal(await page.evaluate(() => localStorage.getItem("aifit.web.session")), null);
  assert.ok((await calls()).includes("POST /auth/v1/logout"));
  await finish(s);
});

test("sesión rechazada por el servidor: error con reintento que recupera el armario", async () => {
  // ERR_ABORTED: la recarga cancela las peticiones de imágenes en vuelo.
  const s = await open({ allow: ["401", "Failed to load resource", "ERR_ABORTED"] });
  const { page } = s;
  await login(page);
  await mock("/__mode?expired=1");
  await page.reload();
  await page.getByRole("heading", { name: "Error" }).waitFor();
  await mock("/__mode?expired=0");
  await page.getByRole("button", { name: "Reintentar" }).click();
  await page.getByRole("tab", { name: /Prendas · 6/ }).waitFor();
  await finish(s);
});

test("un código de autorización inválido muestra el error y limpia la URL", async () => {
  const s = await open({ allow: ["400", "Failed to load resource", "ERR_ABORTED"] }); // goto cancela las imágenes en vuelo
  const { page } = s;
  await login(page);
  await page.evaluate(() => localStorage.clear());
  await page.goto(`${APP_URL}/?code=codigo-inventado`);
  await page.getByText(/No se pudo completar el acceso/).waitFor();
  assert.equal(new URL(page.url()).search, "", "la URL se limpia aunque falle");
  await finish(s);
});

test("accesibilidad (axe) en acceso, armario, selección, ficha, perfil y diálogo", async () => {
  const s = await open();
  const { page } = s;
  await login(page);
  await axe(page, "armario");
  await page.getByRole("checkbox", { name: "Seleccionar Camisa azul" }).check();
  await axe(page, "selección");
  await page.getByRole("button", { name: "Eliminar" }).click();
  await page.getByRole("dialog").waitFor();
  await axe(page, "diálogo");
  await page.getByRole("dialog").getByRole("button", { name: "Cancelar" }).click();
  await page.getByRole("button", { name: "Cancelar selección" }).click();
  await page.getByRole("link", { name: "Abrir Jeans oscuros" }).click();
  await page.getByRole("heading", { name: "Jeans oscuros" }).waitFor();
  await axe(page, "ficha");
  await page.getByRole("link", { name: "Perfil" }).click();
  await page.getByRole("heading", { name: "Ana Prueba", level: 1 }).waitFor();
  await axe(page, "perfil");
  await finish(s);
});

test("teléfono 390x844: 2 columnas, sin desbordamiento horizontal", async () => {
  const s = await open({ viewport: { width: 390, height: 844 } });
  const { page } = s;
  await login(page);
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
  assert.ok(overflow <= 0, `desborda ${overflow}px`);
  const columns = await page.locator(".grid").evaluate((g) => getComputedStyle(g).gridTemplateColumns.split(" ").length);
  assert.equal(columns, 2, "2 columnas, igual que la app móvil");
  await finish(s);
});

test("ni el token ni el refresh token se escriben en la consola", async () => {
  const s = await open();
  const { page } = s;
  await login(page);
  const stored = JSON.parse(await page.evaluate(() => localStorage.getItem("aifit.web.session")));
  const joined = s.consoleText.join("\n");
  assert.ok(!joined.includes(stored.access_token) && !joined.includes(stored.refresh_token));
  await finish(s);
});
