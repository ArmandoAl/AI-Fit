#!/usr/bin/env node
// Servidor estático para el preview de apps/web: MIME correctos, gzip, rutas desconocidas sin extensión -> index.html.
//   ROOT=apps/web/build/jaspr PORT=7702 node scripts/static_spa.mjs      (sólo desarrollo; escucha en 127.0.0.1)
import { createServer } from "node:http";
import { readFileSync, statSync } from "node:fs";
import { gzipSync } from "node:zlib";
import { extname, join, normalize, resolve, sep } from "node:path";

const ROOT = resolve(process.env.ROOT || "apps/web/build/jaspr");
const PORT = parseInt(process.env.PORT || "7702", 10);
const HOST = process.env.HOST || "127.0.0.1";
const MIME = {
  ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8", ".json": "application/json; charset=utf-8", ".wasm": "application/wasm",
  ".map": "application/json", ".png": "image/png", ".jpg": "image/jpeg", ".svg": "image/svg+xml", ".ico": "image/x-icon", ".txt": "text/plain; charset=utf-8",
};
const COMPRESSIBLE = new Set([".html", ".js", ".mjs", ".css", ".json", ".svg", ".map", ".wasm"]);

function fileFor(urlPath) {
  const clean = normalize(decodeURIComponent(urlPath.split("?")[0])).replace(/^(\.\.[/\\])+/, "");
  const candidate = join(ROOT, clean);
  if (candidate !== ROOT && !candidate.startsWith(ROOT + sep)) return null;
  try {
    const st = statSync(candidate);
    if (st.isFile()) return candidate;
    if (st.isDirectory()) return fileFor(join(clean, "index.html"));
  } catch {}
  return null;
}

createServer((req, res) => {
  if (req.method !== "GET" && req.method !== "HEAD") return void res.writeHead(405).end();
  let file = fileFor(req.url);
  if (!file && !extname(req.url.split("?")[0])) file = fileFor("/index.html");
  if (!file) return void res.writeHead(404, { "content-type": "text/plain; charset=utf-8" }).end("No encontrado");
  const ext = extname(file);
  let body = readFileSync(file);
  const headers = { "content-type": MIME[ext] || "application/octet-stream", "cache-control": "no-store", "x-content-type-options": "nosniff" };
  if (COMPRESSIBLE.has(ext) && /\bgzip\b/.test(req.headers["accept-encoding"] || "")) {
    body = gzipSync(body); headers["content-encoding"] = "gzip"; headers["vary"] = "Accept-Encoding";
  }
  headers["content-length"] = body.length;
  res.writeHead(200, headers);
  res.end(req.method === "HEAD" ? undefined : body);
}).listen(PORT, HOST, () => console.log(`static_spa: ${ROOT} en http://${HOST}:${PORT}`));
