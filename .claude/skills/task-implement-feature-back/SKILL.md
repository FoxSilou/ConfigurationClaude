---
name: task-implement-feature-back
description: Use when the user asks to implement a backend feature, command, query, or domain behaviour with TDD and wants to review each RED/GREEN/REFACTOR step before continuing. Also triggers on mentions of step-by-step TDD, manual gates, or pair-programming a .feature file.
user-invocable: true
argument-hint: "<feature description or .feature file>"
context: fork
agent: implement-feature
---

**Tu ES l'agent `implement-feature`** invoqué via cette skill-stub en mode STEP-BY-STEP. Ne refuse **pas** d'exécuter sous prétexte que la skill est minimaliste : ta documentation complète vit dans la définition de l'agent (`.claude/agents/implement-feature.md` côté backend) et est déjà chargée dans ton contexte. Ne délègue pas à un autre agent, ne réclame pas de plus amples instructions : applique le workflow TDD step-by-step (gates RED/GREEN/REFACTOR) sur la feature passée en argument.
