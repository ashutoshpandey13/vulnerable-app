#!/usr/bin/env bash
# Runs all scanners on this folder. Does not call Bob or modify any source file.
# Usage: ./scan.sh [--no-image]   (--no-image skips the image build + CVE scan)

cd "$(dirname "$0")" || exit 1

OUT=$(mktemp -d)
IMAGE=vulnerable-node-app-test
SKIP_IMAGE=0
[ "$1" = "--no-image" ] && SKIP_IMAGE=1

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing tool: $1"; return 1; }; }

echo "== Trivy config: deployment.yaml"
need trivy && trivy config --quiet --format json -o "$OUT/k8s.json" deployment.yaml

echo "== Trivy config: Dockerfile"
need trivy && trivy config --quiet --format json -o "$OUT/dockerfile.json" Dockerfile

echo "== Semgrep (SAST)"
need semgrep && semgrep scan --quiet --config auto --json --output "$OUT/sast.json" . >/dev/null 2>&1

echo "== Gitleaks (secrets)"
need gitleaks && gitleaks dir . --no-banner --report-format json --report-path "$OUT/secrets.json" >/dev/null 2>&1

if [ "$SKIP_IMAGE" = "0" ]; then
  echo "== Image build + Trivy CVE scan"
  # Use Podman (and its socket, so trivy can find the image) when Docker isn't reachable
  BUILDER=docker
  if ! docker info >/dev/null 2>&1 && command -v podman >/dev/null 2>&1; then
    BUILDER=podman
    export DOCKER_HOST="unix://$(podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}')"
  fi
  # docker can fail on a missing credential helper; retry with podman if available
  if ! "$BUILDER" build -q -t "$IMAGE" . >/dev/null 2>&1 \
     && [ "$BUILDER" = "docker" ] && command -v podman >/dev/null 2>&1; then
    BUILDER=podman
    export DOCKER_HOST="unix://$(podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}')"
    "$BUILDER" build -q -t "$IMAGE" . >/dev/null 2>&1
  fi
  if "$BUILDER" images -q "$IMAGE" 2>/dev/null | grep -q .; then
    trivy image --quiet --format json -o "$OUT/image.json" "$IMAGE"
    "$BUILDER" rmi "$IMAGE" >/dev/null 2>&1
  else
    echo "image build failed (is Docker/Podman running?) - skipping CVE scan"
  fi
fi

OUT="$OUT" python3 - <<'EOF'
import json, os, collections

out = os.environ["OUT"]

def load(name):
    try:
        with open(os.path.join(out, name)) as f:
            return json.load(f)
    except Exception:
        return None

def sev(items):
    c = collections.Counter(items)
    order = ["CRITICAL", "HIGH", "MEDIUM", "LOW", "UNKNOWN", "ERROR", "WARNING", "INFO"]
    return ", ".join(f"{c[s]} {s}" for s in order if c[s]) or "none"

print("\n================ SUMMARY ================")

for label, name in (("Trivy config  deployment.yaml", "k8s.json"),
                    ("Trivy config  Dockerfile", "dockerfile.json")):
    d = load(name)
    if d is None:
        print(f"{label}: not run"); continue
    m = [x for r in d.get("Results", []) for x in r.get("Misconfigurations", [])]
    print(f"{label}: {len(m)} ({sev(x['Severity'] for x in m)})")

d = load("sast.json")
if d is None:
    print("Semgrep: not run")
else:
    r = d.get("results", [])
    print(f"Semgrep: {len(r)} ({sev(x['extra']['severity'] for x in r)})")
    for x in r:
        print(f"   {x['path']}:{x['start']['line']}  {x['check_id'].split('.')[-1]}")

d = load("secrets.json")
if d is None:
    print("Gitleaks: not run")
else:
    print(f"Gitleaks: {len(d)}")
    for x in d:
        print(f"   {x['File']}:{x['StartLine']}  {x['RuleID']}")

d = load("image.json")
if d is None:
    print("Trivy image CVEs: not run")
else:
    v = [x for r in d.get("Results", []) for x in r.get("Vulnerabilities", [])]
    print(f"Trivy image CVEs: {len(v)} ({sev(x['Severity'] for x in v)})")
    npm = collections.Counter()
    for r in d.get("Results", []):
        if r.get("Class") == "lang-pkgs":
            for x in r.get("Vulnerabilities", []):
                npm[f"{x['PkgName']}@{x['InstalledVersion']}"] += 1
    print(f"   npm package CVEs: {sum(npm.values())} in {len(npm)} packages")
EOF

rm -rf "$OUT"
