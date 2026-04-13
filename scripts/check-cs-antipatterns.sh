#!/usr/bin/env bash
# Hook PostToolUse(Edit|Write) : signale des anti-patterns dans le code C# édité.
# Entrée : JSON sur stdin (format Claude Code hook).
# Sortie : exit 2 + message stderr = warning visible par Claude (non bloquant puisque PostToolUse).

set -u

# Extraire le file_path du JSON d'entrée sans dépendre de jq
INPUT=$(cat)
FILE=$(echo "$INPUT" | grep -oE '"file_path"\s*:\s*"[^"]+"' | head -n 1 | sed -E 's/.*"file_path"\s*:\s*"([^"]+)".*/\1/')

# Seulement les fichiers C#
case "$FILE" in
    *.cs) ;;
    *) exit 0 ;;
esac

# Le fichier peut ne pas exister (Edit d'un fichier virtuel / suppression) — sortir silencieusement
[ -f "$FILE" ] || exit 0

VIOLATIONS=""

# 1. Mocks interdits (fakes only)
if grep -qE '^\s*using\s+(Moq|NSubstitute|FakeItEasy)\s*;' "$FILE"; then
    VIOLATIONS="${VIOLATIONS}- using Moq/NSubstitute/FakeItEasy détecté — la convention impose des fakes explicites, pas de mocks.\n"
fi
if grep -qE '\bnew\s+Mock\s*<' "$FILE"; then
    VIOLATIONS="${VIOLATIONS}- new Mock<...> détecté — remplacer par un fake.\n"
fi

# 2. DateTime nu (non DateTimeOffset) — ignore DateTimeOffset, DateTimeKind, DateTimeStyles
if grep -nE '\bDateTime\s*\.\s*(UtcNow|Now|Today)\b' "$FILE" | grep -v DateTimeOffset >/dev/null 2>&1; then
    VIOLATIONS="${VIOLATIONS}- DateTime.UtcNow/Now/Today détecté — utiliser TimeProvider (injecté) et DateTimeOffset.\n"
fi

# 3. XML doc comments interdits sur code métier
if grep -qE '^\s*///\s*<summary>' "$FILE"; then
    VIOLATIONS="${VIOLATIONS}- /// <summary> détecté — XML docs interdits, le nommage doit suffire.\n"
fi

# 4. using MediatR en dehors de Infrastructure/Api
case "$FILE" in
    *Infrastructure*|*Api*|*/Api/*) ;;
    *)
        if grep -qE '^\s*using\s+MediatR\s*;' "$FILE"; then
            VIOLATIONS="${VIOLATIONS}- using MediatR dans un projet Domain/Application — MediatR est un adapter d'infra uniquement.\n"
        fi
        ;;
esac

if [ -n "$VIOLATIONS" ]; then
    echo -e "Anti-patterns détectés dans ${FILE} :\n${VIOLATIONS}Voir backend/.claude/rules/*.md pour les conventions." >&2
    exit 2
fi

exit 0
