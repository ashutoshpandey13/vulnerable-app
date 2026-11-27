const express = require("express");
const crypto = require("crypto");

const app = express();
app.disable("x-powered-by");

const CSRF_SECRET =
  process.env.CSRF_SECRET || crypto.randomBytes(32).toString("hex");
const CSRF_COOKIE = "csrf_token";
const CSRF_HEADER = "x-csrf-token";
const SAFE_METHODS = new Set(["GET", "HEAD", "OPTIONS"]);

function sign(value) {
  return crypto.createHmac("sha256", CSRF_SECRET).update(value).digest("hex");
}

function issueToken() {
  const value = crypto.randomBytes(32).toString("hex");
  return `${value}.${sign(value)}`;
}

function safeEqual(a, b) {
  const bufA = Buffer.from(String(a));
  const bufB = Buffer.from(String(b));
  return bufA.length === bufB.length && crypto.timingSafeEqual(bufA, bufB);
}

function isValidToken(token) {
  if (typeof token !== "string") {
    return false;
  }
  const parts = token.split(".");
  if (parts.length !== 2) {
    return false;
  }
  return safeEqual(parts[1], sign(parts[0]));
}

function readCookie(req, name) {
  const header = req.headers.cookie;
  if (!header) {
    return undefined;
  }
  for (const part of header.split(";")) {
    const index = part.indexOf("=");
    if (index === -1) {
      continue;
    }
    if (part.slice(0, index).trim() === name) {
      return decodeURIComponent(part.slice(index + 1).trim());
    }
  }
  return undefined;
}

function csrfProtection(req, res, next) {
  let cookieToken = readCookie(req, CSRF_COOKIE);
  if (!isValidToken(cookieToken)) {
    cookieToken = issueToken();
    res.cookie(CSRF_COOKIE, cookieToken, {
      httpOnly: false,
      sameSite: "strict",
      secure: process.env.NODE_ENV === "production",
    });
  }
  res.locals.csrfToken = cookieToken;

  if (SAFE_METHODS.has(req.method)) {
    return next();
  }

  const headerToken = req.headers[CSRF_HEADER];
  if (
    typeof headerToken !== "string" ||
    !isValidToken(headerToken) ||
    !safeEqual(headerToken, cookieToken)
  ) {
    return res.status(403).json({ error: "Invalid CSRF token" });
  }
  return next();
}

app.use(csrfProtection);

app.get("/", (req, res) => {
  res.send("AuDeSec PoC Running");
});

app.get("/health", (req, res) => {
  res.send("OK");
});

app.listen(3000, "127.0.0.1", () => {
  console.log("Server started");
});
