import hashlib
import os
import pickle
import sqlite3
import subprocess

import requests
import yaml
from flask import Flask, request

app = Flask(__name__)


def run_command(user_input):
    os.system(user_input)


def run_shell(cmd):
    return subprocess.call(cmd, shell=True)


def get_user(username):
    conn = sqlite3.connect("users.db")
    cursor = conn.cursor()
    query = "SELECT * FROM users WHERE name = '%s'" % username
    cursor.execute(query)
    return cursor.fetchall()


def load_session(data):
    return pickle.loads(data)


def load_config(text):
    return yaml.load(text)


def calculate(expression):
    return eval(expression)


def hash_password(password):
    return hashlib.md5(password.encode()).hexdigest()


def fetch(url):
    return requests.get(url, verify=False)


def read_file(name):
    with open("/var/data/" + name) as f:
        return f.read()


@app.route("/user")
def user():
    return str(get_user(request.args.get("name")))


@app.route("/calc")
def calc():
    return str(calculate(request.args.get("expr")))


@app.route("/file")
def file():
    return read_file(request.args.get("name"))


password = "admin123"

if __name__ == "__main__":
    app.run(host="0.0.0.0", debug=True)
