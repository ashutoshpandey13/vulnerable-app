const crypto = require("crypto");
const express = require("express");

const app = express();

const SAFE_METHODS = new Set(["GET", "HEAD", "OPTIONS"]);
const CSRF_COOKIE = "csrf_token";
const CSRF_HEADER = "x-csrf-token";

function parseCookies(header) {
  const cookies = {};
  if (!header) {
    return cookies;
  }
  for (const part of header.split(";")) {
    const index = part.indexOf("=");
    if (index > 0) {
      cookies[part.slice(0, index).trim()] = part.slice(index + 1).trim();
    }
  }
  return cookies;
}

function tokensMatch(a, b) {
  if (typeof a !== "string" || typeof b !== "string") {
    return false;
  }
  const bufA = Buffer.from(a);
  const bufB = Buffer.from(b);
  return bufA.length === bufB.length && crypto.timingSafeEqual(bufA, bufB);
}

function csrfProtection(req, res, next) {
  const cookies = parseCookies(req.headers.cookie);
  let token = cookies[CSRF_COOKIE];

  if (!token || !/^[a-f0-9]{64}$/.test(token)) {
    token = crypto.randomBytes(32).toString("hex");
    res.cookie(CSRF_COOKIE, token, {
      httpOnly: false,
      sameSite: "strict",
      secure: process.env.NODE_ENV === "production",
      path: "/",
    });
    if (!SAFE_METHODS.has(req.method)) {
      return res.status(403).send("Forbidden");
    }
  }

  if (!SAFE_METHODS.has(req.method)) {
    if (!tokensMatch(token, req.get(CSRF_HEADER))) {
      return res.status(403).send("Forbidden");
    }
  }

  res.locals.csrfToken = token;
  next();
}

app.disable("x-powered-by");
app.use(csrfProtection);

app.get("/", (req, res) => {
  res.send("AuDeSec PoC Running");
});

app.get("/health", (req, res) => {
  res.send("OK");
});

const port = Number.parseInt(process.env.PORT, 10) || 3000;
const host = process.env.HOST || "127.0.0.1";

app.listen(port, host, () => {
  console.log("Server started");
});
