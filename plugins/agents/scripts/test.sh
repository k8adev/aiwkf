#!/usr/bin/env bash
#
# Tests for the agents/*.md <-> codex/*.toml parity/validity and the
# marketplace/plugin manifests. Never touches the real ~/.codex.
#
#   bash scripts/test.sh

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_PLUGIN="$(cd "${HERE}/.." && pwd)"
REPO_ROOT="$(cd "${HERE}/../../.." && pwd)"

fail() { echo "FAIL: $1" >&2; exit 1; }

EXPECTED_TOMLS="builder.toml operator.toml researcher.toml reviewer.toml specialist.toml"

if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import tomllib' >/dev/null 2>&1; then
  fail "python3 with tomllib (3.11+) is required to run this suite"
fi

# ============================================================================
# agents/*.md <-> codex/*.toml parity, and codex/*.toml validity
# ============================================================================

md_names="$(cd "${AGENTS_PLUGIN}/agents" && ls *.md | sed 's/\.md$//' | sort)"
toml_names="$(cd "${AGENTS_PLUGIN}/codex" && ls *.toml | sed 's/\.toml$//' | sort)"
[ "${md_names}" = "${toml_names}" ] || fail "agents/*.md and codex/*.toml name sets differ:
md:   $(tr '\n' ' ' <<<"${md_names}")
toml: $(tr '\n' ' ' <<<"${toml_names}")"

for f in ${EXPECTED_TOMLS}; do
  toml="${AGENTS_PLUGIN}/codex/${f}"
  [ -f "${toml}" ] || fail "missing codex/${f}"

  stem="${f%.toml}"
  python3 - "${toml}" "${stem}" <<'PY' || fail "${f} failed validation"
import sys, tomllib
path, stem = sys.argv[1], sys.argv[2]
with open(path, "rb") as fh:
    data = tomllib.load(fh)
missing = [k for k in ("name", "description", "model", "developer_instructions") if not str(data.get(k, "")).strip()]
if missing:
    sys.exit(f"{path}: missing/empty required key(s): {', '.join(missing)}")
if data["name"].lower() != stem:
    sys.exit(f"{path}: name {data['name']!r} does not match filename {stem}.toml")
PY
done
echo "PASS: agents/*.md <-> codex/*.toml parity and validity"

# ============================================================================
# marketplace / plugin manifest parity
# ============================================================================
python3 - "${REPO_ROOT}" <<'PY' || fail "marketplace/manifest parity check failed"
import json, sys
root = sys.argv[1]

def load(rel):
    with open(f"{root}/{rel}") as f:
        return json.load(f)

claude_mp = load(".claude-plugin/marketplace.json")
codex_mp = load(".agents/plugins/marketplace.json")

claude_plugins = {p["name"]: p["source"] for p in claude_mp["plugins"]}
codex_plugins = {p["name"]: p["source"]["path"] for p in codex_mp["plugins"]}

if set(claude_plugins) != set(codex_plugins):
    sys.exit(f"plugin name sets differ: claude={sorted(claude_plugins)} codex={sorted(codex_plugins)}")
for name, claude_path in claude_plugins.items():
    codex_path = codex_plugins[name]
    if claude_path.rstrip("/") != codex_path.rstrip("/"):
        sys.exit(f"path mismatch for '{name}': claude={claude_path!r} codex={codex_path!r}")

claude_manifest = load("plugins/agents/.claude-plugin/plugin.json")
portable_manifest = load("plugins/agents/plugin.json")
if claude_manifest["version"] != portable_manifest["version"]:
    sys.exit(
        f"plugin.json version mismatch: .claude-plugin={claude_manifest['version']!r} "
        f"portable={portable_manifest['version']!r}"
    )

print("marketplace/manifest parity OK")
PY
echo "PASS: marketplace/manifest parity"

# ============================================================================
# portable plugin.json — offline structural check
#
# The manifest was validated by hand against the published Agent Plugins
# schema (https://agent-plugins.org/schemas/1.0.0/plugin.schema.json). Tests
# must be offline and deterministic, so this checks structure only, no
# network fetch: the exact $schema URL, a present kebab-case `name`, a
# semver `version`, and that `name` matches .claude-plugin/plugin.json.
# ============================================================================
python3 - "${AGENTS_PLUGIN}/plugin.json" "${AGENTS_PLUGIN}/.claude-plugin/plugin.json" <<'PY' \
  || fail "plugin.json structural check failed"
import json, re, sys

portable_path, claude_path = sys.argv[1], sys.argv[2]
with open(portable_path) as f:
    manifest = json.load(f)
with open(claude_path) as f:
    claude_manifest = json.load(f)

SCHEMA_URL = "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json"
KEBAB_CASE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")

errors = []
if manifest.get("$schema") != SCHEMA_URL:
    errors.append(f"$schema must be {SCHEMA_URL!r}, got {manifest.get('$schema')!r}")
name = manifest.get("name")
if not name:
    errors.append("name is required")
elif not KEBAB_CASE.fullmatch(name):
    errors.append(f"name {name!r} is not kebab-case")
version = manifest.get("version")
if not version or not SEMVER.fullmatch(version):
    errors.append(f"version {version!r} is not semver")
if name != claude_manifest.get("name"):
    errors.append(f"name {name!r} does not match .claude-plugin/plugin.json name {claude_manifest.get('name')!r}")

if errors:
    sys.exit("plugin.json failed structural check:\n  " + "\n  ".join(errors))
PY
echo "PASS: plugin.json structural check"

# ============================================================================
# orchestrate skill — frontmatter present, and its agent table matches the
# agents/*.md and codex/*.toml name fields exactly (no extras, no duplicates)
# ============================================================================
python3 - "${AGENTS_PLUGIN}/skills/orchestrate/SKILL.md" "${AGENTS_PLUGIN}/agents" "${AGENTS_PLUGIN}/codex" <<'PY' \
  || fail "orchestrate skill check failed"
import pathlib, re, sys, tomllib

skill_path, agents_dir, codex_dir = (pathlib.Path(a) for a in sys.argv[1:4])

text = skill_path.read_text()
m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.S)
if not m:
    sys.exit(f"{skill_path}: missing frontmatter fence")
front, body = m.group(1), m.group(2)

frontmatter = {}
for line in front.splitlines():
    if ":" in line:
        key, value = line.split(":", 1)
        frontmatter[key.strip()] = value.strip()

if frontmatter.get("name") != "orchestrate":
    sys.exit(f"{skill_path}: frontmatter 'name' must be 'orchestrate', got {frontmatter.get('name')!r}")
description = (frontmatter.get("description") or "").strip("'\"")
if not description:
    sys.exit(f"{skill_path}: frontmatter 'description' is required and non-empty")

# Pull agent names from the "Request -> agent" table's second column.
table_names = []
for line in body.splitlines():
    line = line.strip()
    if not line.startswith("|") or not line.endswith("|"):
        continue
    cells = [c.strip() for c in line.strip("|").split("|")]
    if len(cells) != 2:
        continue
    if re.fullmatch(r"-+", cells[0]) and re.fullmatch(r"-+", cells[1]):
        continue  # header separator row
    if cells[0] == "Request" and cells[1] == "Agent":
        continue  # header row
    table_names.append(cells[1].strip("`"))

if not table_names:
    sys.exit(f"{skill_path}: could not find the Request -> agent table")

dupes = sorted({n for n in table_names if table_names.count(n) > 1})
if dupes:
    sys.exit(f"{skill_path}: duplicate agent name(s) in table: {dupes}")
skill_names = set(table_names)

md_names = set()
for md in agents_dir.glob("*.md"):
    fm_match = re.match(r"^---\n(.*?)\n---\n", md.read_text(), re.S)
    for line in fm_match.group(1).splitlines():
        if line.startswith("name:"):
            md_names.add(line.split(":", 1)[1].strip())

toml_names = set()
for toml in codex_dir.glob("*.toml"):
    with open(toml, "rb") as fh:
        toml_names.add(tomllib.load(fh)["name"])

if not (skill_names == md_names == toml_names):
    sys.exit(
        "agent name sets differ:\n"
        f"  skill table: {sorted(skill_names)}\n"
        f"  agents/*.md: {sorted(md_names)}\n"
        f"  codex/*.toml: {sorted(toml_names)}"
    )
PY
echo "PASS: orchestrate skill"

# ============================================================================
# static checks
# ============================================================================
bash -n "${HERE}/test.sh" || fail "bash -n test.sh"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "${HERE}/test.sh" || fail "shellcheck reported issues"
else
  echo "shellcheck not found, skipping"
fi
echo "PASS: static checks"

# Safety: this suite must never have touched the real ~/.codex.
[ "${CODEX_HOME:-unset}" = unset ] || fail "CODEX_HOME leaked out of the test"
echo "ALL PASS"
