---
name: task-implement-feature-front
description: Implement a frontend feature using TDD on Presenters (step-by-step by default; autonome mode available)
user-invocable: true
argument-hint: "<ui-discovery spec or Presenter description>"
context: fork
agent: implement-feature-front
---

Délègue à l'agent `implement-feature-front`. Mode **STEP-BY-STEP** par défaut (gate après chaque RED/GREEN/REFACTOR). L'agent supporte un mode **autonome** (à demander explicitement dans l'invocation) qui déroule toute la liste sans interruption.

## Prerequisites

- Scaffold frontend exécuté (`frontend/src/<Projet>.UI.Domain/` + `.UI.Infrastructure/` + `.UI.Domain.Tests/` existent).
- Client NSwag généré — rebuild nécessaire si `backend/Api.json` a changé.
- **Backend de l'US livré** si le Presenter consomme un nouvel endpoint (vérification équivalente à celle de `/task-resume` pour les lignes `implement-feature-*-front`).
- Spec Presenter issue d'`/task-ui-discovery` (état, propriétés dérivées, actions, liste de tests TDD) — ou description Presenter détaillée.

Documentation complète dans la définition de l'agent.
