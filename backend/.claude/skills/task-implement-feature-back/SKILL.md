---
name: task-implement-feature-back
description: Implement a new feature using TDD step-by-step (user gate after each RED, GREEN, and REFACTOR)
user-invocable: true
argument-hint: "<feature description or .feature file>"
context: fork
agent: implement-feature
---

Délègue à l'agent `implement-feature` en mode **STEP-BY-STEP** : gate utilisateur après chaque RED, GREEN, REFACTOR.

## Prerequisites

- Mode 1 foundation exécuté (`backend/src/Shared/` existe).
- BC scaffoldé (`backend/src/<BC>/` existe, Mode 2).
- Agrégat scaffoldé si la feature le cible (Mode 3).
- `.feature` Gherkin écrit (sortie de `/task-bdd-workshop`) — ou description fonctionnelle détaillée si pas de BDD formel.

## Step-by-step vs autonome

Utiliser cette commande quand l'utilisateur veut **contrôler chaque cycle TDD** (revue du test avant GREEN, revue du code avant REFACTOR, choix des actions de refactor). Pour exécuter toute la liste de tests sans interruption avec 2 gates globaux (validation périmètre + revue finale), utiliser `/task-implement-feature-auto-back`.

Documentation complète dans la définition de l'agent.
