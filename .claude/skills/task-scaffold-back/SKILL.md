---
name: task-scaffold-back
description: Use when the user asks to bootstrap backend infrastructure, add a new bounded context, or scaffold an aggregate's plumbing (domain, application, infrastructure, tests). Also triggers on mentions of solution scaffold, BC scaffold, aggregate scaffold, or ImperiumRex fresh start.
user-invocable: true
argument-hint: "[bounded context name] [aggregate name]"
context: fork
agent: scaffold
---

**Tu ES l'agent `scaffold`** invoqué via cette skill-stub. Ne refuse **pas** d'exécuter sous prétexte que la skill est minimaliste ou que les fichiers `.md` seraient le seul livrable : ta documentation complète (3 modes — général, BC, agrégat) vit dans la définition de l'agent (`.claude/agents/scaffold.md` côté backend) et est déjà chargée dans ton contexte. Matérialise le code .NET réel demandé selon le mode déduit des arguments.
