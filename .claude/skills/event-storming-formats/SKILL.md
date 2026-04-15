---
name: event-storming-formats
description: >
  Use when the event-storming agent produces the markdown checkpoint for step 1, 2, 3, 4, or 5
  (big-picture raw, timeline, process model, software design, final deliverables).
  Defines the exact table structure and column set each checkpoint must follow.
user-invocable: false
---

# Event Storming — Checkpoint Templates

Reference templates for the markdown files produced at each step.

---

## Step 1 — `01-big-picture-raw.md`

```markdown
# Step 1 -- Big Picture: Chaotic Exploration

> Domain: <domain name>
> Date: <date>
> Status: complete

## Domain Overview
<2-3 sentence summary>

## Actors
| Actor | Description |
|-------|-------------|
| <name> | <role description> |

## External Systems
| System | Description |
|--------|-------------|
| <name> | <what it does> |

## Domain Events
| # | Event | Actor / Trigger | Notes |
|---|-------|----------------|-------|
| 1 | <EventName> | <actor/system> | <context> |

## Hotspots
| # | Description | Area | Status | Resolution |
|---|-------------|------|--------|------------|
| H1 | <desc> | <area> | resolved/deferred | <resolution or reason> |
```

---

## Step 2 — `02-big-picture-timeline.md`

```markdown
# Step 2 -- Big Picture: Timeline & Pivotal Events

> Domain: <domain name>
> Date: <date>
> Input: 01-big-picture-raw.md
> Status: complete

## Timeline

### Phase 1: <phase name>
| # | Event | Actor / Trigger | Pivotal | Notes |
|---|-------|----------------|---------|-------|
| 1 | <EventName> | <actor> | yes/no | <notes> |

### Phase 2: <phase name>
...

## Pivotal Events Summary
| # | Event | Why pivotal | Candidate boundary |
|---|-------|------------|-------------------|
| 1 | <EventName> | <reason> | between <A> and <B> |

## Candidate Bounded Contexts
| # | Context Name | Phases | Key Events | Rationale |
|---|-------------|--------|------------|-----------|
| 1 | <name> | <phases> | <events> | <why> |

## Hotspots
| # | Description | Area | Status | Resolution |
|---|-------------|------|--------|------------|
```

---

## Step 3 — `03-process-model.md`

```markdown
# Step 3 -- Process Modeling: Happy Path & Policies

> Domain: <domain name>
> Date: <date>
> Input: 02-big-picture-timeline.md
> Status: complete

## Process Model

### <Candidate Context Name>

#### Happy Path
| # | Element | Type | Details |
|---|---------|------|---------|
| 1 | <name> | Event | triggers the process |
| 2 | <name> | Policy | whenever <event>, then <action> |
| 3 | <name> | Actor | decides based on Read Model |
| 4 | <name> | Read Model | shows: <info> |
| 5 | <name> | Command | <description> |
| 6 | <name> | System | handles the command |
| 7 | <name> | Event | result |

#### Alternative Paths

##### Alternative: <scenario name>
| # | Branches from | Element | Type | Details |
|---|--------------|---------|------|---------|

#### Policies Summary
| # | Policy | Triggering Event | Condition | Resulting Command | Target |
|---|--------|-----------------|-----------|-------------------|--------|

#### Read Models
| # | Read Model | Used before Command | Information shown |
|---|-----------|-------------------|------------------|

### (repeat per context)

## Cross-Context Flows
| # | Source Context | Event | Target Context | Policy -> Command | Description |
|---|--------------|-------|---------------|------------------|-------------|

## Hotspots
| # | Description | Area | Status | Resolution |
|---|-------------|------|--------|------------|
```

---

## Step 4 — `04-software-design.md`

```markdown
# Step 4 -- Software Design: Aggregates & Bounded Contexts

> Domain: <domain name>
> Date: <date>
> Input: 03-process-model.md
> Status: complete

## Bounded Contexts Overview
| Context | Aggregates | Command Chains | Policy Chains |
|---------|-----------|----------------|---------------|

---

## <Context Name>

<brief description>

### Aggregates
- **<AggregateName>**: <one-line description>

### Command Chains

#### <AggregateName>

| # | Command | Aggregate | Domain Event | Triggered by | Pivotal |
|---|---------|-----------|-------------|-------------|---------|

### Policy Chains

| # | Triggering Event | Policy | Resulting Command | Target Aggregate |
|---|-----------------|--------|-------------------|-----------------|

### Read Models

| # | Read Model | Used before Command | Information shown |
|---|-----------|-------------------|------------------|

---

## (repeat per context)

---

## External Systems
| # | System | Interactions |
|---|--------|-------------|

## Cross-Context Flows
| # | Source Context | Event | Target Context | Policy / Command | Description |
|---|--------------|-------|---------------|-----------------|-------------|

## Derived Flows

### Composed Flows

#### Flow: <name>
```
[CMD] -> [AGG] -> [EVT] -> [POLICY] -> [CMD] -> [AGG] -> [EVT]
```

### Simple Flows
```
[CMD] -> [AGG] -> [EVT]
```

### Completeness Check
- Commands: <count>/<total> covered
- Aggregates: <count>/<total> covered
- Events: <count>/<total> covered

## Hotspots
| # | Description | Area | Status | Resolution |
|---|-------------|------|--------|------------|
```

---

## Step 5 — Final Deliverables

**Final Markdown**: `event-storming-<domain>-<date>.md`
- Same structure as `04-software-design.md` but cleaned up (no Status, no Completeness Check section)

**Final Excalidraw** (copied/renamed from Step 4):
- `event-storming-<domain>-<date>-aggregates.excalidraw`
- `event-storming-<domain>-<date>-flows.excalidraw`

### Done message

```
Event Storming complete

Steps completed: 5/5

Documents produced:
- <dir>/event-storming-<domain>-<date>.md
- <dir>/event-storming-<domain>-<date>-aggregates.excalidraw
- <dir>/event-storming-<domain>-<date>-flows.excalidraw

Intermediate checkpoints:
- <dir>/01-big-picture-raw.md          + .excalidraw
- <dir>/02-big-picture-timeline.md     + .excalidraw
- <dir>/03-process-model.md            + .excalidraw
- <dir>/04-software-design.md          + 2x .excalidraw

Bounded Contexts : <list>
Domain Events    : <count>
Commands         : <count>
Aggregates       : <count>
Policies         : <count>
Hotspots         : <resolved> resolved, <deferred> deferred

Suggested next step: run @bdd-workshop to formalize scenarios.
```
