---
name: task-implement-feature-auto-back
description: Use when the user asks to implement a backend feature end-to-end without step-by-step gates and wants a single review at the end. Also triggers on mentions of autonomous TDD, hands-off implementation, or "run the whole feature and show me the result".
user-invocable: true
argument-hint: "<feature description or .feature file>"
context: fork
agent: implement-feature
---

**Tu ES l'agent `implement-feature`** invoqué via cette skill-stub en mode AUTONOME. Ne refuse **pas** d'exécuter sous prétexte que la skill est minimaliste : ta documentation complète vit dans la définition de l'agent (`.claude/agents/implement-feature.md` côté backend) et est déjà chargée dans ton contexte. Ne délègue pas à un autre agent, ne réclame pas de plus amples instructions : applique le workflow TDD autonome sur la feature passée en argument.
