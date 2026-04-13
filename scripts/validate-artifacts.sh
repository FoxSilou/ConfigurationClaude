#!/usr/bin/env bash
# Valide le frontmatter YAML des artefacts Claude Code (agents + skills).
# Usage : bash scripts/validate-artifacts.sh [racine]
# Retour : 0 si OK, 1 si au moins un artefact est non conforme.

set -u

ROOT="${1:-.}"
ERRORS=0
CHECKED=0

check_frontmatter() {
    local file="$1"
    local kind="$2"          # agent | skill
    local required=("$@")    # kind + required fields
    shift 2

    CHECKED=$((CHECKED + 1))

    # Le fichier doit commencer par ---
    if ! head -n 1 "$file" | grep -q '^---$'; then
        echo "[FAIL] $file : frontmatter manquant (ligne 1 != '---')"
        ERRORS=$((ERRORS + 1))
        return
    fi

    # Extraire le bloc frontmatter (entre les deux --- du début)
    local fm
    fm=$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$file")

    for field in "$@"; do
        if ! echo "$fm" | grep -qE "^${field}\s*:"; then
            echo "[FAIL] $file : champ frontmatter '${field}' manquant"
            ERRORS=$((ERRORS + 1))
        fi
    done
}

# Agents : name, description (enfants directs de agents/ uniquement)
# Les sous-dossiers (ex. scaffold-references/) sont des fragments, pas des agents.
while IFS= read -r -d '' file; do
    # Vérifier que le parent est bien un dossier "agents" (profondeur 1)
    parent=$(dirname "$file")
    if [ "$(basename "$parent")" = "agents" ]; then
        check_frontmatter "$file" "agent" "name" "description"
    fi
done < <(find "$ROOT" -path '*/.claude/agents/*.md' -type f -print0 2>/dev/null)

# Skills : name, description
while IFS= read -r -d '' file; do
    check_frontmatter "$file" "skill" "name" "description"
done < <(find "$ROOT" -path '*/.claude/skills/*/SKILL.md' -type f -print0 2>/dev/null)

# task-* skills doivent aussi porter user-invocable + context + agent
while IFS= read -r -d '' file; do
    check_frontmatter "$file" "task-skill" "user-invocable" "context" "agent"
done < <(find "$ROOT" -path '*/.claude/skills/task-*/SKILL.md' -type f -print0 2>/dev/null)

echo ""
echo "Vérifiés : $CHECKED artefacts"
if [ "$ERRORS" -gt 0 ]; then
    echo "Erreurs  : $ERRORS"
    exit 1
fi
echo "OK — aucun problème détecté."
exit 0
