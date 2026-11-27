const express = require("express");
const crypto = require("crypto");

const app = express();

const SAFE_METHODS = new Set(["GET", "HEAD", "OPTIONS"]);
const TOKEN_PATTERN = /^[A-Za-z0-9_-]{43}$/;

function readCookie(header, name) {
  if (!header) {
    return undefined;
  }
  for (const part of header.split(";")) {
    const index = part.indexOf("=");
    if (index === -1) {
      continue;
    }
    if (part.slice(0, index).trim() === name) {
      return part.slice(index + 1).trim();
    }
  }
  return undefined;
}

function tokensMatch(expected, supplied) {
  if (typeof supplied !== "string") {
    return false;
  }
  const a = Buffer.from(expected);
  const b = Buffer.from(supplied);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

app.use((req, res, next) => {
  let token = readCookie(req.headers.cookie, "csrf_token");

  if (!token || !TOKEN_PATTERN.test(token)) {
    token = crypto.randomBytes(32).toString("base64url");
    res.cookie("csrf_token", token, {
      httpOnly: true,
      sameSite: "strict",
      secure: process.env.NODE_ENV === "production",
    });
  }

  res.set("X-CSRF-Token", token);

  if (!SAFE_METHODS.has(req.method) && !tokensMatch(token, req.get("x-csrf-token"))) {
    res.status(403).send("Forbidden");
    return;
  }

  next();
});

app.get("/", (req, res) => {
  res.send("AuDeSec PoC Running");
});

app.get("/health", (req, res) => {
  res.send("OK");
});

const port = Number(process.env.PORT) || 3000;
const host = process.env.HOST || "127.0.0.1";

app.listen(port, host, () => {
  console.log("Server started");
});
