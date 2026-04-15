---
name: task-implement-feature-auto-back
description: Implement a new feature using TDD autonomously (2 user gates — Phase 0 scope + final review — but no intermediate RED/GREEN/REFACTOR gates)
user-invocable: true
argument-hint: "<feature description or .feature file>"
context: fork
agent: implement-feature
---

Délègue à l'agent `implement-feature` en mode **AUTONOME** : 2 gates seulement (validation périmètre Phase 0 + revue finale), pas de gate par cycle RED/GREEN/REFACTOR.

## Prerequisites

- Mode 1 foundation exécuté (`backend/src/Shared/` existe).
- BC scaffoldé (`backend/src/<BC>/` existe, Mode 2).
- Agrégat scaffoldé si la feature le cible (Mode 3).
- `.feature` Gherkin écrit (sortie de `/task-bdd-workshop`) — ou description fonctionnelle détaillée si pas de BDD formel.

## Autonome vs step-by-step

Utiliser cette commande pour **dérouler la liste complète de tests sans interruption** (refactoring conservateur autonome, bilan présenté en fin de course). Pour contrôler chaque cycle individuellement (gate après RED, GREEN, REFACTOR), utiliser `/task-implement-feature-back`.

Documentation complète dans la définition de l'agent.
