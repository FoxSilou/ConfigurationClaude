---
name: tdd-workflow
description: >
  TDD execution discipline (RED/GREEN/REFACTOR cycle).
  Use when implementing a feature or fixing a bug using test-driven development.
  Covers: analysis phase with ordered test list, Transformation Priority Premise (TPP),
  step-by-step vs autonomous execution modes, baby steps, and violation detection.
  Builds on the unit-testing skill.
user-invocable: false
---


# Skill: TDD Workflow

## Prerequisite

This skill builds on the `unit-testing` skill. All test structure, naming, test doubles, and assertion conventions defined there apply here without exception.

---

## Execution Modes

This skill supports two execution modes. The mode is determined by the calling agent or command.

### Mode STEP-BY-STEP (default)

Full user control. **Three user gates per test**: after RED, after GREEN, after REFACTOR proposal. The user validates each step before proceeding.

```
RED → ⛔ user gate → GREEN → ⛔ user gate → REFACTOR → ⛔ user gate → next test
```

### Mode AUTONOME

Autonomous execution. The agent runs the full TDD cycle (RED → GREEN → REFACTOR) for all tests in the list **without interruption**. A single user gate at the end presents a complete summary of everything that was produced.

In autonomous mode:
- The agent still follows TDD strictly (RED → GREEN → REFACTOR for each test, TPP order, baby steps).
- Refactoring decisions are made autonomously, favoring safe, conservative improvements.
- The agent reports progress internally but does not pause for user input.
- At the end, a **detailed summary** is presented for user review.

---

## Core Discipline

TDD is not a testing technique — it is a **design discipline**. Tests drive the emergence of the right design by forcing you to think about usage before implementation.

The cycle is non-negotiable:

```
ANALYSE → RED → GREEN → REFACTOR → RED → ...
```

- **No production code without a failing test first.** Ever.
- **No more code than needed to pass the test.** The simplest transformation wins.
- **No refactoring on a red test.** Only refactor when all tests are green.

---

## Phase 0 — ANALYSE (mandatory before every new requirement)

Before writing any test, produce an **ordered test list** for the requirement.

### Rules

- List all scenarios that need to be covered.
- Order them by **TPP priority** — start with the simplest transformation possible.
- Start with the degenerate/empty case, then the simplest happy path, then edge cases and failures.
- Label each test with its expected TPP transformation (see TPP table below).
- This list is the plan. Do not skip ahead. Do not reorder on the fly without justification.

### Output format

```
Requirement: CreerPartie — créer une nouvelle partie de jeu

Test list (TPP order):
1. [nil→constant]    CreerPartie_doit_retourner_un_id_quand_les_donnees_sont_valides
2. [constant→scalar] CreerPartie_doit_persister_la_partie_avec_le_nom_fourni
3. [conditional]     CreerPartie_doit_echouer_quand_le_nom_est_vide
4. [conditional]     CreerPartie_doit_echouer_quand_le_nom_est_trop_long
```

---

## Transformation Priority Premise (TPP)

When making a test pass, always use the **highest-priority (lowest number) transformation** that works. Never skip to a more complex transformation when a simpler one suffices.

| Priority | Transformation | Description |
|---|---|---|
| 1 | `{} → nil` | Return null / nothing |
| 2 | `nil → constant` | Return a fixed constant |
| 3 | `constant → constant+` | Return a slightly more complex constant |
| 4 | `constant → scalar` | Replace constant with a variable/parameter |
| 5 | `statement → statements` | Add a statement |
| 6 | `unconditional → conditional` | Introduce an if |
| 7 | `scalar → array` | Replace scalar with a collection |
| 8 | `array → container` | Replace array with a richer structure |
| 9 | `statement → recursion` | Replace iteration with recursion |
| 10 | `conditional → while` | Replace conditional with a loop |
| 11 | `expression → function` | Extract expression to a function |
| 12 | `variable → assignment` | Mutate a variable |

### Baby steps rule

Apply **one transformation per test**. If making a test pass requires two transformations, the test list was not granular enough — split the test.

---

## Phase 1 — RED (user gate)

1. Pick the next test from the ordered list.
2. Write the test using the naming and structure from the `unit-testing` skill.
3. Write **only** the test — no production code yet.
4. If the test references classes or methods that do not exist, create the **minimum stubs** needed for the code to compile (empty classes, methods that throw `NotImplementedException`). Nothing more.
5. Run the tests. The new test **must fail** with a meaningful error (assertion failure, not compilation error).
6. If the test passes without production code → the test is wrong or already covered. Stop and reassess.

### Baby steps in RED

- One test at a time.
- One assertion per test whenever possible.
- The test calls classes and methods that **do not exist yet** (wishful thinking). Let the compiler drive the interface design.

### Gate — End of RED (STEP-BY-STEP mode only)

> In AUTONOME mode, skip this gate — proceed directly to GREEN.

**⛔ GATE: Stop after writing the test and confirming it compiles and fails.**

Present to the user:
- The test code written
- The compilation status (must compile ✅)
- The test failure message (must fail with a meaningful assertion ❌)
- Which test this is in the list (e.g., "Test 3/15")

Ask:
> *"Voici le test [nom]. Il compile et échoue comme attendu : [message d'erreur]. Le code du test vous convient-il ? Puis-je passer au GREEN ?"*

Wait for explicit user confirmation before proceeding to GREEN.

---

## Phase 2 — GREEN (user gate)

1. Write the **minimum production code** to make the failing test pass.
2. Apply the TPP — use the simplest transformation that works.
3. Do not refactor yet. Do not clean up. Do not generalize. Just make it green.
4. Run all tests. **All tests must pass** before moving on.
5. If a previously passing test breaks → fix it before continuing. Never leave a broken test.

### What "minimum" means

- If returning a constant makes the test pass → return a constant.
- If a single `if` makes the test pass → write a single `if`.
- Resist the urge to write the "real" implementation. The next tests will force it.

### Gate — End of GREEN (STEP-BY-STEP mode only)

> In AUTONOME mode, skip this gate — proceed directly to REFACTOR (autonomous decisions).

**⛔ GATE: Stop after making the test pass.**

Present to the user:
- The production code written or modified
- The test result (all tests green ✅)
- The TPP transformation used
- Progress: tests done / total

Ask:
> *"Le test passe. Voici le code produit : [résumé des changements]. Transformation utilisée : [TPP]. Souhaitez-vous passer au REFACTOR ou avez-vous des remarques sur l'implémentation ?"*

Wait for explicit user confirmation before proceeding to REFACTOR.

---

## Phase 3 — REFACTOR (user gate in STEP-BY-STEP mode)

> In AUTONOME mode, apply conservative refactoring autonomously (rename, extract obvious Value Objects, remove clear duplication). Do not make bold structural changes without user input.

**⛔ GATE (STEP-BY-STEP only): This gate is MANDATORY. Never skip it, even if no refactoring seems necessary. Always present proposals (or explicitly state there is none) and wait for user confirmation before moving to the next test.**

Present the current state:
- All tests passing ✅
- **Proposed refactoring actions** — list each action specifically:
  - What to refactor (e.g., "Extraire un Value Object AdresseEmail depuis le string brut")
  - Why (e.g., "Primitive obsession — le format email est validé en ligne dans le handler")
  - Impact (which files will be modified)
- If no refactoring is needed, say so explicitly.

Ask:
> *"Tests verts. Voici les actions de refactoring que je propose : [liste numérotée]. Lesquelles souhaitez-vous appliquer ? Ou préférez-vous passer au test suivant ?"*

Wait for the user to **select which actions to apply** (all, some, or none) before acting.

### When the user confirms refactoring

1. Apply **only the actions approved by the user**, one at a time.
2. Refactor with **all tests green at all times**. If a test goes red during refactoring → stop, undo, reassess.
3. Improve naming, extract concepts, remove duplication — but **do not change behavior**.
4. Apply DDD patterns where they emerge naturally (Value Objects, domain methods…). Do not force them.
5. After each action, run all tests. All must still pass.
6. Report what was changed and why.

### What to look for

- Primitive obsession → introduce a Value Object
- Duplicated logic → extract a domain method
- Unclear naming → rename to match the ubiquitous language
- Misplaced responsibility → move logic to the right layer

---

## Cycle Summary — STEP-BY-STEP mode

```
┌─────────────────────────────────────────────────────────┐
│  ANALYSE                                                 │
│  Ordered test list (TPP order) — full requirement scope  │
└───────────────────────┬─────────────────────────────────┘
                        │ pick next test
                        ▼
┌─────────────────────────────────────────────────────────┐
│  RED                                                     │
│  Write one failing test (baby step, wishful thinking)    │
│  Create minimum stubs for compilation                    │
└───────────────────────┬─────────────────────────────────┘
                        │ test compiles ✅ + fails ❌
                        ▼
┌─────────────────────────────────────────────────────────┐
│  ⛔ RED GATE — wait for user                             │
│  Show test code + failure message / ask to proceed       │
└───────────────────────┬─────────────────────────────────┘
                        │ user confirms test
                        ▼
┌─────────────────────────────────────────────────────────┐
│  GREEN                                                   │
│  Minimum code to pass — TPP transformation               │
└───────────────────────┬─────────────────────────────────┘
                        │ all tests pass ✅
                        ▼
┌─────────────────────────────────────────────────────────┐
│  ⛔ GREEN GATE — wait for user                           │
│  Show production code + transformation / ask to proceed  │
└───────────────────────┬─────────────────────────────────┘
                        │ user confirms implementation
                        ▼
┌─────────────────────────────────────────────────────────┐
│  ⛔ REFACTOR GATE — wait for user                        │
│  Propose specific actions / user selects which to apply  │
└───────────────────────┬─────────────────────────────────┘
                        │ user selects actions (or skips)
                        ▼
┌─────────────────────────────────────────────────────────┐
│  REFACTOR                                                │
│  Apply selected actions — all tests green throughout     │
└───────────────────────┬─────────────────────────────────┘
                        │ more tests in list?
                        ├── yes → back to RED
                        └── no  → TDD cycle complete ✅
```

## Cycle Summary — AUTONOME mode

```
┌─────────────────────────────────────────────────────────┐
│  ANALYSE                                                 │
│  Ordered test list (TPP order) — full requirement scope  │
└───────────────────────┬─────────────────────────────────┘
                        │ for each test in list
                        ▼
┌─────────────────────────────────────────────────────────┐
│  RED → GREEN → REFACTOR (autonomous)                     │
│  No user gates — agent runs full cycle per test          │
│  Conservative refactoring only                           │
│  ↺ repeat for all tests                                  │
└───────────────────────┬─────────────────────────────────┘
                        │ all tests done
                        ▼
┌─────────────────────────────────────────────────────────┐
│  ⛔ FINAL GATE — wait for user                           │
│  Present complete summary:                               │
│  - All tests written + results                           │
│  - All production code created/modified                  │
│  - All refactoring actions taken                         │
│  - Domain concepts introduced                            │
│  - Files created/modified list                           │
│  Ask: review, adjust, or approve                         │
└─────────────────────────────────────────────────────────┘
```

### Autonomous mode — Final gate content

At the end of the autonomous cycle, present:

1. **Test summary**: list of all tests with their name and status (all green ✅)
2. **Production code summary**: for each file created or modified, a brief description of what it contains
3. **Domain concepts introduced**: Value Objects, Entities, Aggregates, Ports created
4. **Refactoring actions taken**: list of each refactoring decision made and why
5. **Files created/modified**: complete list with paths

Ask:
> *"Implémentation terminée en mode autonome. Voici le bilan complet : [summary]. Tous les tests passent. Souhaitez-vous revoir certains points, ajuster quelque chose, ou valider ?"*

---

## Violations — What Must Never Happen

| Violation | Description |
|---|---|
| **V1 — Production code first** | Writing production code before a failing test |
| **V2 — Test passes immediately** | New test passes without any production code → wrong test |
| **V3 — Over-implementation** | Writing more than the minimum to pass the current test |
| **V4 — Red refactoring** | Refactoring while any test is red |
| **V5 — TPP skip** | Using a complex transformation when a simpler one would work |
| **V6 — Gate bypass** | (STEP-BY-STEP only) Proceeding to GREEN without user confirmation of the test, or to REFACTOR without user confirmation of the implementation, or refactoring without user-selected actions |
| **V7 — Skipped analysis** | Starting RED without an ordered test list |

When a violation is detected, stop, name it, and explain the corrective action before continuing.


---

