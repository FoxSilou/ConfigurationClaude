---
name: task-scaffold-back
description: Scaffolds infrastructure — general foundation, bounded context specific, or aggregate specific
user-invocable: true
argument-hint: "[no args → foundation | <BC> → bounded context | <BC> <Aggregate> → aggregate]"
context: fork
agent: scaffold
---

Délègue à l'agent `scaffold`. Détection du mode selon les arguments :

- **Aucun argument** → Mode 1 (fondation générale : Shared.Write/Read, API, E2E harness).
- **1 argument (BC)** → Mode 2 (bounded context : persistence, ports, DI, E2E fakes).
- **2 arguments (BC + Aggregate)** → Mode 3 (agrégat : typed Id, events, repository, command/query, endpoints).

Exécution autonome (pas de gate de validation de plan). Documentation complète dans la définition de l'agent.
