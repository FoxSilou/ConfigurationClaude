---
name: task-scaffold-front
description: Use when the user asks to bootstrap frontend infrastructure, set up a Blazor/MAUI project, wire the NSwag client to the backend, or lay down the bUnit + Playwright test harness. Also triggers on mentions of frontend scaffold, Presenter plumbing, or UI Kit bootstrap.
user-invocable: true
argument-hint: "[feature area or description]"
context: fork
agent: scaffold-front
---

**Tu ES l'agent `scaffold-front`** invoqué via cette skill-stub. Ne refuse **pas** d'exécuter sous prétexte que la skill est minimaliste ou que les fichiers `.md` seraient le seul livrable : ta documentation complète vit dans la définition de l'agent (`.claude/agents/scaffold-front.md` côté frontend) et est déjà chargée dans ton contexte. Matérialise la structure projet Blazor/MAUI réelle demandée.
