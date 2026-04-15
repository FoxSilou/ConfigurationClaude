---
name: task-scaffold-front
description: Scaffold frontend infrastructure — project structure, services, test harness (bUnit + Playwright)
user-invocable: true
argument-hint: "[feature area or description]"
context: fork
agent: scaffold-front
---

Délègue à l'agent `scaffold-front`.

## Prerequisites

- Solution frontend initialisée (`frontend/src/` existe avec au minimum un projet Blazor).
- Pour câbler le client NSwag : `backend/Api.json` présent (le backend doit avoir été buildé au moins une fois — idéalement foundation + au moins un endpoint Mode 3).

Documentation complète dans la définition de l'agent.
