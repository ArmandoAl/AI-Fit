#!/usr/bin/env node
// Servidor simulado del protocolo de Supabase para pruebas de navegador SIN credenciales ni producción:
// OAuth (authorize + PKCE verificado de verdad), /auth/v1/token|user|logout, PostgREST (/rest/v1/...) y Storage firmado.
// Los datos son sintéticos. Lo que valida es el cliente real (GoTrue/PostgREST/Storage de `supabase`) contra el contrato,
// no el proyecto real de AI-Fit ni Google.   PORT=7712 node mock_supabase.mjs
import { createServer } from "node:http";
import { createHash, randomUUID } from "node:crypto";

const PORT = parseInt(process.env.PORT ?? "7712", 10);
const BASE = `http://127.0.0.1:${PORT}`;
const USER = { id: "11111111-1111-4111-8111-111111111111", email: "ana.prueba@example.test", name: "Ana Prueba" };
const b64 = (o) => Buffer.from(typeof o === "string" ? o : JSON.stringify(o)).toString("base64url");
const jwt = (sub, exp) => `${b64({ alg: "HS256", typ: "JWT" })}.${b64({ sub, role: "authenticated", aud: "authenticated", exp, email: USER.email })}.firma-de-prueba`;

const fresh = () => ({
  items: [
    { id: "it-1", name: "Camisa azul", category: "top", subtype: "shirt", source_path: "u/camisa.svg", colors: ["blue"], style_tags: ["casual"], seasons: ["spring", "summer"], brand: "Marca A", created_at: "2026-10-20T10:00:00Z", processing_status: "ready" },
    { id: "it-2", name: "Jeans oscuros", category: "bottom", subtype: "jeans", source_path: `${BASE}/img/jeans.svg`, colors: ["navy"], style_tags: ["casual"], seasons: ["fall"], created_at: "2026-10-19T10:00:00Z", processing_status: "ready" },
    { id: "it-3", name: "Vestido rojo", category: "dress", subtype: "dress", source_path: "u/vestido.svg", cutout_path: "u/vestido-cut.svg", colors: ["red"], style_tags: ["elegant"], seasons: ["summer"], created_at: "2026-10-18T10:00:00Z", processing_status: "ready" },
    { id: "it-4", name: "Tenis blancos", category: "shoes", subtype: "sneakers", source_path: "u/tenis.svg", colors: ["white"], created_at: "2026-10-17T10:00:00Z", processing_status: "processing" },
    { id: "it-5", name: "Abrigo gris", category: "outerwear", subtype: "coat", source_path: "u/abrigo.svg", colors: ["gray"], created_at: "2026-10-16T10:00:00Z", processing_status: "failed" },
    { id: "it-6", name: "Playera negra", category: "top", subtype: "t-shirt", source_path: "u/playera.svg", colors: ["black"], created_at: "2026-10-15T10:00:00Z", processing_status: "ready" },
  ].map((r) => ({ ...r, user_id: USER.id })),
  profile: { id: USER.id, display_name: "Ana Prueba", avatar_path: "u/avatar.svg", onboarding_completed: true, preferences: {}, identity_version: 2,
    identity_profile: { skin_tone: { primary: "medium", undertone: "warm" }, hair: { color: "dark brown", style: "wavy" }, body: { type: "hourglass", build: "athletic" } } },
  photos: [{ user_id: USER.id, kind: "body", storage_path: "u/b1.svg" }, { user_id: USER.id, kind: "body", storage_path: "u/b2.svg" }, { user_id: USER.id, kind: "face", storage_path: "u/f1.svg" }],
});
let db = fresh(), log = [], mode = { deleteFails: false, expired: false, restFails: false };
const codes = new Map(), tokens = new Set(), refresh = new Map();
let session = null;

const newSession = () => {
  const exp = Math.floor(Date.now() / 1000) + 3600, access = jwt(USER.id, exp), r = `refresh-${randomUUID()}`;
  tokens.add(access); refresh.set(r, true);
  return { access_token: access, token_type: "bearer", expires_in: 3600, expires_at: exp, refresh_token: r, user: userJson() };
};
const userJson = () => ({ id: USER.id, aud: "authenticated", role: "authenticated", email: USER.email, email_confirmed_at: "2026-10-01T00:00:00Z", phone: "", app_metadata: { provider: "google", providers: ["google"] },
  user_metadata: { full_name: USER.name, avatar_url: `${BASE}/img/avatar.svg`, email: USER.email }, identities: [], created_at: "2026-10-01T00:00:00Z", updated_at: "2026-10-01T00:00:00Z" });
const svg = (label, hue) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 220"><rect width="200" height="220" fill="hsl(${hue} 40% 30%)"/><text x="100" y="116" font-size="20" text-anchor="middle" fill="#fff">${label}</text></svg>`;
const hueOf = (s) => [...s].reduce((a, c) => (a * 31 + c.charCodeAt(0)) % 360, 7);

function cors(req, res) {
  res.setHeader("Access-Control-Allow-Origin", req.headers.origin ?? "*");
  res.setHeader("Access-Control-Allow-Headers", req.headers["access-control-request-headers"] ?? "*");
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,PATCH,DELETE,OPTIONS");
  res.setHeader("Access-Control-Expose-Headers", "*");
  res.setHeader("Vary", "Origin");
}
const send = (res, status, body, type = "application/json") => { res.writeHead(status, { "content-type": type }); res.end(body === undefined ? undefined : typeof body === "string" ? body : JSON.stringify(body)); };
const readBody = (req) => new Promise((ok) => { let d = ""; req.on("data", (c) => (d += c)); req.on("end", () => ok(d)); });
const authed = (req) => tokens.has((req.headers.authorization ?? "").replace(/^Bearer /, ""));
const inList = (v) => (v ?? "").replace(/^in\./, "").replace(/^\(|\)$/g, "").split(",").map((x) => x.replace(/^"|"$/g, ""));

createServer(async (req, res) => {
  cors(req, res);
  if (req.method === "OPTIONS") return send(res, 204);
  const url = new URL(req.url, BASE), q = url.searchParams, path = url.pathname;
  const body = ["POST", "PATCH", "DELETE"].includes(req.method) ? await readBody(req) : "";
  if (!path.startsWith("/__")) log.push({ method: req.method, path, query: Object.fromEntries(q) });

  // ---- utilidades de prueba
  if (path === "/__reset") { db = fresh(); log = []; mode = { deleteFails: false, expired: false, restFails: false }; codes.clear(); tokens.clear(); refresh.clear(); return send(res, 200, { ok: true }); }
  if (path === "/__log") return send(res, 200, log);
  if (path === "/__mode") { Object.assign(mode, Object.fromEntries([...q].map(([k, v]) => [k, v === "1"]))); return send(res, 200, mode); }
  if (path === "/__expire") { tokens.clear(); return send(res, 200, { ok: true }); }

  // ---- OAuth / GoTrue
  if (path === "/auth/v1/authorize") {
    const code = `code-${randomUUID()}`;
    codes.set(code, { challenge: q.get("code_challenge"), method: q.get("code_challenge_method") });
    const back = new URL(q.get("redirect_to") ?? "/"); back.searchParams.set("code", code);
    res.writeHead(302, { location: back.toString() }); return res.end();
  }
  if (path === "/auth/v1/token") {
    const data = body ? JSON.parse(body) : {};
    if (q.get("grant_type") === "pkce") {
      const entry = codes.get(data.auth_code); codes.delete(data.auth_code);
      if (!entry) return send(res, 400, { error: "invalid_grant", error_description: "código desconocido o ya usado" });
      const method = (entry.method ?? "plain").toLowerCase();
      const computed = method === "s256" ? createHash("sha256").update(data.code_verifier ?? "").digest("base64url") : data.code_verifier;
      if (computed !== entry.challenge) return send(res, 400, { error: "invalid_grant", error_description: "PKCE: el verificador no coincide" });
      return send(res, 200, (session = newSession()));
    }
    if (q.get("grant_type") === "refresh_token") {
      if (!refresh.has(data.refresh_token)) return send(res, 400, { error: "invalid_grant", error_description: "refresh token inválido" });
      return send(res, 200, (session = newSession()));
    }
    return send(res, 400, { error: "unsupported_grant_type" });
  }
  if (path === "/auth/v1/user") return authed(req) ? send(res, 200, userJson()) : send(res, 401, { code: 401, msg: "invalid JWT" });
  if (path === "/auth/v1/logout") { tokens.clear(); return send(res, 204); }

  // ---- PostgREST
  if (path.startsWith("/rest/v1/")) {
    if (mode.expired || !authed(req)) return send(res, 401, { code: "PGRST301", message: "JWT expired", details: null, hint: null });
    if (mode.restFails) return send(res, 500, { code: "XX000", message: "fallo simulado del servidor" });
    const table = path.slice("/rest/v1/".length), eq = (k) => (q.get(k) ?? "").replace(/^eq\./, "");
    const single = /pgrst\.object\+json/.test(req.headers.accept ?? "");
    if (table === "wardrobe_items" && req.method === "GET") {
      const rows = db.items.filter((r) => r.user_id === eq("user_id")).sort((a, b) => b.created_at.localeCompare(a.created_at));
      return send(res, 200, rows);
    }
    if (table === "outfit_items" && req.method === "DELETE") return send(res, 204);
    if (table === "wardrobe_items" && req.method === "DELETE") {
      if (mode.deleteFails) return send(res, 200, []); // RLS: no borró nada
      const ids = inList(q.get("id")), gone = db.items.filter((r) => r.user_id === eq("user_id") && ids.includes(r.id));
      db.items = db.items.filter((r) => !gone.includes(r));
      return send(res, 200, gone.map((r) => ({ id: r.id })));
    }
    if (table === "profiles" && req.method === "GET") {
      const row = eq("id") === db.profile.id ? db.profile : null;
      if (single) return row ? send(res, 200, row) : send(res, 406, { code: "PGRST116", message: "The result contains 0 rows", details: "Results contain 0 rows", hint: null });
      return send(res, 200, row ? [row] : []);
    }
    if (table === "user_photos" && req.method === "GET") return send(res, 200, db.photos.filter((r) => r.user_id === eq("user_id")));
    return send(res, 404, { code: "42P01", message: `tabla desconocida: ${table}` });
  }

  // ---- Storage (buckets privados: se firma y luego se descarga con el token)
  const sign = path.match(/^\/storage\/v1\/object\/sign\/user-media\/(.+)$/);
  if (sign && req.method === "POST") {
    if (!authed(req)) return send(res, 401, { statusCode: "401", error: "Unauthorized", message: "invalid JWT" });
    return send(res, 200, { signedURL: `/object/sign/user-media/${sign[1]}?token=firma-${Date.now()}` });
  }
  if (sign && req.method === "GET") return q.get("token") ? send(res, 200, svg(decodeURIComponent(sign[1]).split("/").pop(), hueOf(sign[1])), "image/svg+xml") : send(res, 400, "falta token", "text/plain");
  const img = path.match(/^\/img\/(.+)$/);
  if (img) return send(res, 200, svg(img[1], hueOf(img[1])), "image/svg+xml");
  send(res, 404, { error: "no encontrado", path });
}).listen(PORT, "127.0.0.1", () => console.log(`mock_supabase en ${BASE}`));
