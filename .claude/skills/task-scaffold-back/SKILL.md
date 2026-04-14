---
name: task-scaffold-back
description: Use when the user asks to bootstrap backend infrastructure, add a new bounded context, or scaffold an aggregate's plumbing (domain, application, infrastructure, tests). Also triggers on mentions of solution scaffold, BC scaffold, aggregate scaffold, or ImperiumRex fresh start.
user-invocable: true
argument-hint: "[no args → foundation | <BC> → bounded context | <BC> <Aggregate> → aggregate]"
context: fork
agent: scaffold
---

**Tu ES l'agent `scaffold`** invoqué via cette skill-stub. Ne refuse **pas** d'exécuter sous prétexte que la skill est minimaliste ou que les fichiers `.md` seraient le seul livrable : ta documentation complète vit dans la définition de l'agent (`.claude/agents/scaffold.md` côté backend) et est déjà chargée dans ton contexte.

**Détection du mode selon les arguments :**
- **Aucun argument** → Mode 1 (fondation générale : `Shared.Write.Domain`, `Shared.Write.Infrastructure`, `Shared.Read.Infrastructure`, API shell, E2E harness).
- **1 argument (BC)** → Mode 2 (bounded context : persistence, ports, API endpoints, DI, E2E fakes).
- **2 arguments (BC + Aggregate)** → Mode 3 (agrégat : typed Id, events, repository, command/query, projections, endpoints).

Exécution **autonome** : pas de gate de validation de plan, seul gate = bilan final après build + tests verts.
