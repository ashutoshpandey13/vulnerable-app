const express = require("express");
const crypto = require("crypto");

const app = express();

const SAFE_METHODS = new Set(["GET", "HEAD", "OPTIONS"]);
const TOKEN_PATTERN = /^[a-f0-9]{64}$/;

function parseCookies(header) {
  const cookies = {};
  if (!header) {
    return cookies;
  }
  header.split(";").forEach((pair) => {
    const index = pair.indexOf("=");
    if (index > 0) {
      cookies[pair.slice(0, index).trim()] = pair.slice(index + 1).trim();
    }
  });
  return cookies;
}

function tokensMatch(expected, submitted) {
  if (typeof submitted !== "string") {
    return false;
  }
  const a = Buffer.from(expected);
  const b = Buffer.from(submitted);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

app.use((req, res, next) => {
  const cookies = parseCookies(req.headers.cookie);
  let token = cookies["csrf-token"];

  if (!token || !TOKEN_PATTERN.test(token)) {
    token = crypto.randomBytes(32).toString("hex");
    res.cookie("csrf-token", token, {
      httpOnly: true,
      sameSite: "strict",
      secure: process.env.NODE_ENV === "production",
    });
  }

  res.set("X-CSRF-Token", token);

  if (!SAFE_METHODS.has(req.method) && !tokensMatch(token, req.get("x-csrf-token"))) {
    return res.status(403).send("Forbidden");
  }

  next();
});

app.get("/", (req, res) => {
  res.send("AuDeSec PoC Running");
});

app.get("/health", (req, res) => {
  res.send("OK");
});

app.listen(3000, "127.0.0.1", () => {
  console.log("Server started");
});
