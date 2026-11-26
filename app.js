const express = require("express");
const cors = require("cors");
const { exec } = require("child_process");
const jwt = require("jsonwebtoken");
const serialize = require("node-serialize");

const app = express();

const JWT_SECRET = "supersecret123";

app.use(cors({ origin: "*" }));

app.get("/", (req, res) => {
  res.send("AuDeSec PoC Running");
});

app.get("/health", (req, res) => {
  res.send("OK");
});

app.get("/eval", (req, res) => {
  res.send(String(eval(req.query.code)));
});

app.get("/ping", (req, res) => {
  exec("ping -c 1 " + req.query.host, (err, stdout) => {
    res.send(stdout);
  });
});

app.get("/hello", (req, res) => {
  res.send("<h1>Hello " + req.query.name + "</h1>");
});

app.get("/deserialize", (req, res) => {
  const obj = serialize.unserialize(req.query.data);
  res.json(obj);
});

app.get("/token", (req, res) => {
  res.send(jwt.sign({ user: req.query.user }, JWT_SECRET));
});

app.listen(3000, () => {
  console.log("Server started");
});
