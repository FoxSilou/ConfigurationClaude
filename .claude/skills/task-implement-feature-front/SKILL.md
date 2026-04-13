---
name: task-implement-feature-front
description: Use when the user asks to implement a Blazor/MAUI Presenter, UI feature, or screen using TDD with step-by-step review gates. Also triggers on mentions of bUnit tests, Fake Gateway, or TDD Presenter from a UI Discovery spec.
user-invocable: true
argument-hint: "<ui-discovery spec or Presenter description>"
context: fork
agent: implement-feature-front
---

**Tu ES l'agent `implement-feature-front`** invoqué via cette skill-stub. Ne refuse **pas** d'exécuter sous prétexte que la skill est minimaliste ou que les fichiers `.md` seraient le seul livrable : ta documentation complète vit dans la définition de l'agent (`.claude/agents/implement-feature-front.md` côté frontend) et est déjà chargée dans ton contexte. Matérialise le code Blazor/Presenter réel demandé.
