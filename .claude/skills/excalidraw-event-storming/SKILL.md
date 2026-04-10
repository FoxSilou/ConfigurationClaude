
---
name: excalidraw-event-storming
description: >
  Use when generating Excalidraw diagrams for Event Storming workshops.
  Supports all views: chaotic, timeline, process, aggregate, and flow.
  Loaded by the event-storming agent as a rendering skill.
user-invocable: false
---

# Excalidraw Event Storming Diagram Skill

## Purpose

Generate **Excalidraw files** from an Event Storming session, one per step:

1. **Chaotic view** (`-raw.excalidraw`) -- Scattered event post-its, no order, no arrows (Step 1)
2. **Timeline view** (`-timeline.excalidraw`) -- Events on a horizontal timeline with pivotal events and phases (Step 2)
3. **Process view** (`-process-model.excalidraw`) -- Process Modeling chains with arrows (Step 3)
4. **Aggregate view** (`-aggregates.excalidraw`) -- Visual catalog: one block per aggregate showing its commands and events, policies below, bounded contexts as enclosing regions, **no arrows** (Step 4)
5. **Flow view** (`-flows.excalidraw`) -- Use-case flows derived from policy chains, reading left-to-right chronologically, with curved arrows between elements and fork visuals for branching (Step 4)

## Diagram Specification Format

The event-storming agent returns a structured specification. The `view` field determines which layout to use:

```
DIAGRAM_SPEC:
  view: chaotic | timeline | process | aggregate | flow
  data:
    events:
      - name: SeatsReserved
        actor: Spectateur
        confidence: high        # chaotic view only
        hotspot: false
      ...
    hotspots:                   # chaotic + timeline views
      - name: "Duree blocage\ntemporaire ?"
        area: Reservation
      ...
    phases:                     # timeline view only
      - name: Programmation
        events: [FilmAjouteAuCatalogue, SeanceProgrammee]
      ...
    pivotal_events:             # timeline view only
      - name: ReservationCreee
        reason: "transition Programmation -> Reservation"
      ...
    candidate_contexts:         # timeline view only (optional)
      - name: Reservation
        color: "#e7f5ff"
        stroke: "#1971c2"
        phases: [Reservation, Paiement]
      ...
    chains:                     # process view only
      - context: Reservation
        path: happy
        elements:
          - { name: SeanceAffichee, type: event }
          - { name: "QuandSpectateur\nChoisitSieges", type: policy }
          - { name: Spectateur, type: actor }
          - { name: PlanDeSalle, type: read_model }
          - { name: ReserverSieges, type: command }
          - { name: SystReservation, type: system }
          - { name: SiegesReserves, type: event }
      ...
    alternative_chains:         # process view only
      - context: Reservation
        branches_from: PaiementRefuse
        path: alternative
        name: "Paiement refuse"
        elements:
          - { name: PaiementRefuse, type: event }
          - { name: "QuandRefus\nAlorsLiberer", type: policy }
          - { name: LibererSieges, type: command }
          - { name: SystReservation, type: system }
          - { name: SiegesLiberes, type: event }
      ...
    bounded-contexts:           # aggregate + flow views
      - name: Reservation
        color: "#e7f5ff"
        stroke: "#1971c2"
        aggregates: [Booking, Seat]
      ...
    aggregates:                 # aggregate + flow views
      - name: Booking
        context: Reservation
        commands: [ReserveSeats, CancelReservation]
        events: [SeatsReserved, ReservationCancelled]
      ...
    policies:                   # aggregate + flow views
      - name: "QuandReservationPayee\nAlorsEmettreBillets"
        source_event: ReservationPaid
        target_command: IssuTickets
        source_context: Reservation
        target_context: Ticketing
      ...
    flows:                      # flow view only
      - name: "Reservation et paiement"
        chain: [ReserveSeats, Booking, SeatsReserved, PolicyName, ProcessPayment, Payment, PaymentProcessed]
        branches:  # optional fork
          - from_event: PaymentProcessed
            continuations:
              - [PolicyA, CmdX, AggX, EvtX]
              - [PolicyB, CmdY, AggY, EvtY]
      ...
  output: docs/event-storming/my-diagram
```

---

## Shared Rules

### Sticky Note Color Convention

| Element Type | Background Color | Stroke | Label Below | Shape |
|---|---|---|---|---|
| Domain Event | `#ffb347` (orange) | `#1e1e1e` | `DOMAIN EVENT` | rectangle, no roundness |
| Command | `#a5d8ff` (blue) | `#1e1e1e` | `COMMAND` | rectangle, no roundness |
| Actor | `#fff3bf` (small yellow) | `#1e1e1e` | `ACTOR` | rectangle, no roundness |
| Aggregate | `#ffec99` (large yellow) | `#1e1e1e` | `AGGREGATE` | rectangle, no roundness |
| Policy | `#d0bfff` (lilac) | `#1e1e1e` | `POLICY` | rectangle, no roundness |
| Read Model | `#b2f2bb` (green) | `#1e1e1e` | `READ MODEL` | rectangle, no roundness |
| External System | `#ffc9c9` (pink) | `#1e1e1e` | `EXTERNAL SYSTEM` | rectangle, no roundness |
| Bounded Context | per-context color | per-context stroke | context name as title | rectangle, roundness type 3, opacity 30 |
| Pivotal Event | `#ffb347` (orange) | `#c92a2a` (red) | `DOMAIN EVENT` | rectangle, strokeWidth 3 |
| Hotspot | `#ffc9c9` (pink/magenta) | `#c92a2a` (red) | `HOTSPOT` | rectangle, no roundness |
| Phase Separator | transparent | `#868e96` (gray) | phase name | dashed line, strokeWidth 1 |
| Timeline Arrow | transparent | `#495057` (dark gray) | `TIME -->` | arrow, strokeWidth 2 |

### General

- Canvas background: `#ffffff`
- Font family: `1` (hand-drawn)
- All stickies: `fillStyle: "solid"`, `strokeWidth: 1`, `roundness: null`
- Sticky text: `fontSize: 16` for main label, `fontSize: 11` for type sublabel
- Sublabel color: `#868e96`

### Dynamic Sizing

Sticky dimensions are computed from text content to prevent overflow. Character width is estimated at **9.5px per character** at `fontSize: 16`.

#### Standard stickies (Command, Domain Event, Read Model, External System, Actor)

```
text_width    = charCount * 9.5
sticky_width  = max(140, text_width + 30)
sticky_height = 65
text_el_width = sticky_width - 20
```

#### Aggregate stickies

```
text_width    = charCount * 9.5
sticky_width  = max(180, text_width + 30)
sticky_height = 100
text_el_width = sticky_width - 20
```

#### Policy stickies (multiline)

Policy text uses `\n` to split into 2 lines. Compute width from the **longest line**:

```
longest_line  = max(len(line1), len(line2))
text_width    = longest_line * 9.5
sticky_width  = max(200, text_width + 30)
line_count    = number of \n-separated lines
sticky_height = max(65, 25 + line_count * 20 + 20)
text_el_width = sticky_width - 20
```

#### Hotspot stickies

```
text_width    = charCount * 9.5
sticky_width  = max(160, text_width + 30)
sticky_height = 65
text_el_width = sticky_width - 20
```

#### Text element height

For single-line text: `height = 25`
For multiline text (policies): `height = line_count * 20` (e.g. 2 lines -> `height = 40`)
Sublabel text: `height = 14`

#### Text positioning inside a sticky

```
main_text_x   = sticky_x + 10
main_text_y   = sticky_y + 8
sublabel_x    = sticky_x + 10
sublabel_y    = sticky_y + sticky_height - 22
```

### Context Badge (flow view only)

In the flow view, bounded contexts are not drawn as enclosing rectangles. Instead, each aggregate has a small **context badge** -- a colored text label placed above the aggregate sticky:

```
badge_text    = context name
badge_x       = aggregate_x
badge_y       = aggregate_y - 18
fontSize      = 11
strokeColor   = context stroke color
```

---

## Excalidraw JSON Element Templates

Each sticky note is composed of **3 elements**: rectangle + main text + sublabel text.

Rectangle (dimensions are **dynamic** -- see "Dynamic Sizing"):
```json
{
  "id": "{unique-id}",
  "type": "rectangle",
  "x": 0, "y": 0,
  "width": "{computed_sticky_width}",
  "height": "{computed_sticky_height}",
  "strokeColor": "#1e1e1e",
  "backgroundColor": "{color-from-table}",
  "fillStyle": "solid",
  "strokeWidth": 1,
  "roundness": null,
  "opacity": 100,
  "angle": 0,
  "groupIds": ["{group-id}"],
  "boundElements": [],
  "seed": "{random-int}",
  "version": 1,
  "isDeleted": false,
  "locked": false
}
```

Main text:
```json
{
  "id": "{unique-id}_text",
  "type": "text",
  "x": "{sticky_x + 10}", "y": "{sticky_y + 8}",
  "width": "{sticky_width - 20}",
  "height": 25,
  "text": "{element name}",
  "fontSize": 16,
  "fontFamily": 1,
  "textAlign": "center",
  "verticalAlign": "top",
  "strokeColor": "#1e1e1e",
  "backgroundColor": "transparent",
  "fillStyle": "solid",
  "strokeWidth": 1,
  "opacity": 100,
  "angle": 0,
  "groupIds": ["{group-id}"],
  "boundElements": [],
  "seed": "{random-int}",
  "version": 1,
  "isDeleted": false,
  "locked": false
}
```

Sublabel:
```json
{
  "id": "{unique-id}_sub",
  "type": "text",
  "x": "{sticky_x + 10}", "y": "{sticky_y + sticky_height - 22}",
  "width": "{sticky_width - 20}",
  "height": 14,
  "text": "{TYPE LABEL}",
  "fontSize": 11,
  "fontFamily": 1,
  "textAlign": "center",
  "verticalAlign": "top",
  "strokeColor": "#868e96",
  "backgroundColor": "transparent",
  "fillStyle": "solid",
  "strokeWidth": 1,
  "opacity": 100,
  "angle": 0,
  "groupIds": ["{group-id}"],
  "boundElements": [],
  "seed": "{random-int}",
  "version": 1,
  "isDeleted": false,
  "locked": false
}
```

Arrow (curved, with bindings -- **flow and process views**):
```json
{
  "id": "{arrow-id}",
  "type": "arrow",
  "x": "{start_x}", "y": "{start_y}",
  "width": "{dx}", "height": "{dy}",
  "strokeColor": "#1e1e1e",
  "backgroundColor": "transparent",
  "fillStyle": "solid",
  "strokeWidth": 1.5,
  "roundness": { "type": 2 },
  "opacity": 100,
  "angle": 0,
  "groupIds": [],
  "boundElements": [],
  "points": [[0, 0], ["{dx*0.4}", "{dy*0.15}"], ["{dx}", "{dy}"]],
  "startArrowhead": null,
  "endArrowhead": "arrow",
  "startBinding": { "elementId": "{source-rect-id}", "focus": 0, "gap": 4 },
  "endBinding": { "elementId": "{target-rect-id}", "focus": 0, "gap": 4 },
  "seed": "{random-int}",
  "version": 1,
  "isDeleted": false,
  "locked": false
}
```

### Arrow waypoints

Horizontal arrows (same row): `[[0, 0], [dx*0.4, dy*0.15], [dx, dy]]`
Vertical arrows (fork branches): `[[0, 0], [dx*0.15, dy*0.4], [dx, dy]]`
Cross-flow long-distance: `[[0, 0], [dx*0.2, 0], [dx*0.5, dy*0.5], [dx*0.8, dy], [dx, dy]]`

### Binding contract

When an arrow connects element A -> element B:
1. The arrow has `startBinding.elementId = A.id` and `endBinding.elementId = B.id`
2. Element A's rectangle MUST include `{ "id": "{arrow-id}", "type": "arrow" }` in its `boundElements`
3. Element B's rectangle MUST include `{ "id": "{arrow-id}", "type": "arrow" }` in its `boundElements`

### File Wrapper

```json
{
  "type": "excalidraw",
  "version": 2,
  "source": "claude",
  "elements": [ ... all elements ... ],
  "appState": { "gridSize": null, "viewBackgroundColor": "#ffffff" },
  "files": {}
}
```

### Legend

Always include a legend box in the bottom-right corner showing only the element types present in the diagram. Use small colored squares (18x18) with text labels.

---

## View: Chaotic

### Visual Reference

```
   [EVT3]        [EVT1]
         [HOTSPOT1]       [EVT7]
   [EVT5]     [EVT2]
      [EVT8]        [HOTSPOT2]
            [EVT4]        [EVT6]
```

- **Only orange event stickies** and **magenta hotspot stickies**
- No arrows, no order, no grouping
- Intentionally scattered to reflect the chaotic exploration phase
- Actor names are shown as small text annotations above events (not separate stickies)

### Layout Algorithm

The goal is a **natural-looking scatter** -- not a grid, not random noise.

#### Step 1 -- Compute sticky sizes

Use standard sizing formulas for events and hotspot sizing for hotspots.

#### Step 2 -- Place stickies in a scattered grid

Use a soft grid with jitter to avoid overlaps while looking organic:

```
columns       = ceil(sqrt(event_count + hotspot_count))
rows          = ceil(total_count / columns)
cell_width    = max_sticky_width + 60
cell_height   = max_sticky_height + 50
jitter_x      = random(-20, +20)   # vary per sticky
jitter_y      = random(-15, +15)   # vary per sticky

sticky_x = col * cell_width + jitter_x + 40
sticky_y = row * cell_height + jitter_y + 40
```

Alternate between events and hotspots to spread hotspots across the canvas.

#### Step 3 -- Actor annotations

For events with a known actor, place a small text element above the sticky:
```
actor_text_x  = sticky_x
actor_text_y  = sticky_y - 16
fontSize      = 11
strokeColor   = "#868e96"
```

#### Step 4 -- Legend

Bottom-right. Show: Domain Event, Hotspot.

---

## View: Timeline

### Visual Reference

```
  TIME ──────────────────────────────────────────────────────────>

  |  Phase 1: Programmation    |  Phase 2: Reservation       |  Phase 3: Paiement    |
  |                            |                              |                       |
  [EVT1]  [EVT2]  [EVT3*]     |  [EVT4]  [EVT5*]  [EVT6]    |  [EVT7]  [EVT8]      |
                               |                              |                       |
                               |     [HOTSPOT1]               |                       |

  * = pivotal event (red border)
```

- Events placed **left to right** along a horizontal timeline
- **Pivotal events** have red border (`strokeColor: #c92a2a`, `strokeWidth: 3`)
- **Phase separators** as vertical dashed lines between groups
- Phase names above the separator lines
- Hotspots placed below the timeline, near their related phase
- Optional: candidate bounded context zones as light background rectangles behind phases

### Layout Algorithm

#### Step 1 -- Compute sticky sizes

Standard sizing for events, hotspot sizing for hotspots.

#### Step 2 -- Draw timeline arrow

```
arrow_y       = 30
arrow_x_start = 40
arrow_x_end   = total_canvas_width - 40
```

A horizontal arrow with label "TIME -->" at the left.

#### Step 3 -- Place phases

```
phase_start_x = 40
events_y      = arrow_y + 60          # events row
hotspots_y    = events_y + 90         # hotspots row (below events)
phase_gap     = 40                    # gap between phases
event_gap     = 20                    # gap between events within a phase
```

For each phase:
1. Place phase separator (vertical dashed line) at `phase_start_x`
2. Place phase title text at `(phase_start_x + 10, arrow_y + 20)`, `fontSize: 14`, bold
3. Place events left-to-right with `event_gap`
4. Place hotspots related to this phase below the events row
5. Compute phase width = total events width + padding
6. Next phase starts at `phase_start_x + phase_width + phase_gap`

#### Step 4 -- Highlight pivotal events

Pivotal events use:
- `strokeColor: "#c92a2a"` (red)
- `strokeWidth: 3`
- A small star or marker: text element `"*"` at top-right corner

#### Step 5 -- Optional context zones

If candidate bounded contexts are provided:
- Draw light background rectangles behind the phases they cover
- Use the context color at `opacity: 15`
- Context name as small text label at the top of the zone

#### Step 6 -- Legend

Bottom-right. Show: Domain Event, Pivotal Event, Hotspot, Phase Separator.

---

## View: Process

### Visual Reference

```
Context: Reservation

Happy Path:
  [EVT] -> [POLICY] -> [ACTOR] -> [CMD] -> [SYSTEM] -> [EVT] -> [POLICY] -> [CMD] -> [SYSTEM] -> [EVT]
                          |
                       [READ MODEL]

Alternative: Paiement refuse
  Branches from [PaiementRefuse]:
  [EVT] -> [POLICY] -> [CMD] -> [SYSTEM] -> [EVT]
```

- Follows the **Process Modeling grammar**: Event -> Policy -> [Human] -> [Read Model] -> Command -> System -> Event
- Each chain is a **horizontal row** of connected stickies with curved arrows
- **Read Models** (green) are placed below the Actor they inform
- **Actors** (small yellow) are placed in the chain between Policy and Command
- Happy path chains are at the top, alternatives below with a visual branch marker
- Chains are grouped by candidate bounded context with a context title

### Layout Algorithm

#### Step 1 -- Compute sticky sizes

Standard sizing for all element types. Systems use External System sizing.

#### Step 2 -- Layout chains

```
chain_start_x  = 80                   # indent for context title
chain_y        = 60                    # first chain row
element_gap    = 20                    # horizontal gap between elements
chain_gap      = 40                    # vertical gap between chain rows
read_model_offset_y = 70              # read model placed below actor
```

For each chain:
1. Place elements left-to-right with `element_gap`
2. All elements vertically centered on `chain_y` (use tallest element height)
3. When an Actor appears, place its Read Model directly below:
   - `read_model_x = actor_x`
   - `read_model_y = actor_y + actor_height + 10`
   - Draw a small vertical arrow from Actor to Read Model
4. Draw curved arrows between **every consecutive pair** of elements in the chain

#### Step 3 -- Context grouping

```
context_title_x = 40
context_title_y = first_chain_y - 30
```

Draw context name as text element (`fontSize: 18`, bold). Group all chains for that context visually. Add `60px` gap between context groups.

#### Step 4 -- Alternative chains

Alternative chains are indented slightly more and preceded by a branch marker:
```
branch_marker = text "Branches from [EventName]:"
branch_x      = chain_start_x + 20
branch_y      = previous_chain_bottom + chain_gap
```

Alternative chains use the same layout as happy path chains but start with the branching event.

#### Step 5 -- Arrows

- Curved arrows between every consecutive pair: same arrow template as defined in the shared section
- Vertical arrows from Actor to Read Model: short, straight, no curve
- `strokeWidth: 1.5` for chain arrows, `strokeWidth: 1` for Actor-ReadModel arrows

#### Step 6 -- Legend

Bottom-right. Show: Domain Event, Command, Policy, Actor, Read Model, External System, Hotspot (if any remain).

---

## View: Aggregate

### Visual Reference

```
     [CMD1]              [EVT1]
     [CMD2]  [AGGREGATE]  [EVT2]
     [CMD3]              [EVT3]

       [POLICY1]  [POLICY2]
```

- One block per **unique aggregate** (no duplication)
- Commands stacked vertically to the LEFT of the aggregate
- Events stacked vertically to the RIGHT of the aggregate
- Policies related to this aggregate (as source or target) placed BELOW the block
- **No arrows** -- spatial grouping is sufficient
- Bounded contexts as enclosing rounded rectangles

### Aggregate Block Layout

1. **Commands** (blue stickies) stacked vertically to the left:
   - Column width = `max(cmd_w for all commands in this block)`
   - Height = `command_count * 65 + (command_count - 1) * 10`
   - Vertically centered on the aggregate

2. **Aggregate** (yellow sticky) in the center:
   - Width = `max(180, charCount * 9.5 + 30)`, Height = `100`
   - X offset = `command_column_width + 20`

3. **Events** (orange stickies) stacked vertically to the right:
   - Column width = `max(evt_w for all events in this block)`
   - Height = `event_count * 65 + (event_count - 1) * 10`
   - X offset = `aggregate_x + aggregate_width + 20`
   - Vertically centered on the aggregate

4. **Policies** (lilac stickies) placed below the block:
   - Arranged in a horizontal row, centered under the block
   - Y offset = `block_bottom + 20`
   - Horizontal gap between policies: `15px`

5. **Block bounding box**:
   - Width = `cmd_col_width + 20 + agg_width + 20 + evt_col_width`
   - Height = `max(cmd_col_height, agg_height, evt_col_height) + 20 + policy_row_height` (if policies exist)

### Bounded Contexts (Aggregate View)

- Draw each context as a large rounded rectangle (`roundness: { "type": 3 }`)
- `opacity: 30`, `strokeWidth: 2`, `strokeStyle: "solid"`
- Context title: `fontSize: 24`, same color as stroke, at `(context_x + 50, context_y + 12)`
- All aggregate blocks belonging to that context are placed **inside** its rectangle
- `50px` padding on all sides, `40px` top for title
- Arrange blocks within a context in a **grid** (2 blocks per row for large contexts)
- Horizontal gap between blocks: `80px`
- Vertical gap between block rows: `60px`
- Gap between context boxes: `120px`
- Use **2-column layout** for contexts when there are 4+ contexts

### Positioning Algorithm (Aggregate View)

#### Step 1 -- Build Aggregate Blocks
For each unique aggregate, compute its block with commands left, aggregate center, events right, policies below.

#### Step 2 -- Arrange Blocks Within Contexts
Group blocks by context. Grid layout within each context (2 per row). Context box = content + padding.

#### Step 3 -- Arrange Contexts on Canvas
If <= 3 contexts: stack vertically with `120px` gap.
If 4+ contexts: 2-column layout with `120px` gaps.
Start at `(40, 40)`.

#### Step 4 -- Place Legend
Bottom-right. Element types: Command, Aggregate, Domain Event, Policy, Pivotal Event.

---

## View: Flow

### Visual Reference

```
Composed flow (with policy continuation):

  [CMD] -> [AGG] -> [EVT] -> [POLICY] -> [CMD] -> [AGG] -> [EVT]
   blue    yellow   orange   lilac      blue    yellow   orange

Fork (one event triggers multiple policies):

  [CMD] -> [AGG] -> [EVT] ──-> [POLICY A] -> [CMD] -> [AGG] -> [EVT]
                        |
                        |──-> [POLICY B] -> [CMD] -> [AGG] -> [EVT]
                        |
                        └──-> [POLICY C] -> (Personnage)
```

- Each use-case flow is a **horizontal chain** of elements reading left-to-right
- Flows are **derived from policy chains**: follow Event -> Policy -> Command recursively
- The aggregate sticky is **duplicated** at each appearance in a flow
- **No bounded context boxes** -- instead, each aggregate has a small **context badge** (colored label above it, see "Context Badge" section)
- **All transitions have curved arrows** between consecutive elements in the flow
- Composed flows (with policies) are grouped at the top, simple flows at the bottom
- Flows are separated by `30px` vertical gap

### Flow Derivation

**COMPLETENESS RULE: Every command, aggregate, and event from the aggregate view MUST appear in at least one flow. No element may be dropped. The flow view is a rearrangement of the same elements, not a summary.**

To derive flows from the event storming data:

1. Identify **root commands** -- commands not triggered by any policy (player or system initiated)
2. For each root command, follow the chain: `Command -> Aggregate -> Event`
3. If the event triggers one or more policies, continue each branch: `-> Policy -> Command -> Aggregate -> Event -> ...`
4. If an event triggers **multiple policies**, create a **fork**: the main flow continues to the first branch, additional branches start on new rows below, vertically aligned with the fork point
5. **After deriving all flows, verify completeness**: cross-check that every command, aggregate, and event from the aggregate view appears in at least one flow. If any element is missing, create a simple flow for it or attach it to an existing flow.

### Flow Layout

1. Each element in the flow is placed `20px` to the right of the previous one
2. All elements in a flow row are **vertically centered** on the aggregate height (100px):
   - `cmd_y = row_y + (100 - 65) / 2` = `row_y + 17.5`
   - `evt_y = row_y + 17.5`
   - `policy_y = row_y + (100 - 85) / 2` = `row_y + 7.5`
3. Arrows between **every consecutive pair** of elements in the flow (CMD->AGG, AGG->EVT, EVT->POLICY, POLICY->CMD...)
4. Row height = `100px` (aggregate height)

### Fork Layout

When an event triggers multiple policies (branching):

1. The main flow continues horizontally to the **first branch**
2. Additional branches start on **new rows below**, offset by `30px` vertically per branch
3. A **vertical fork arrow** goes from the source event down to each additional branch's first element (the policy)
4. Fork arrows use vertical waypoints: `[[0, 0], [dx*0.15, dy*0.4], [dx, dy]]`
5. Each branch row starts at the same X position (aligned with the fork event's right edge + 20px)

### Flow Grouping

1. **Composed flows** (with at least one policy) are placed first, at the top of the canvas
2. **Simple flows** (CMD -> AGG -> EVT only, no policy) are placed below, after a `60px` separator gap
3. Within each group, flows are stacked vertically with `30px` gap
4. A **flow title** (text element, `fontSize: 14`, `strokeColor: "#495057"`) is placed to the left of each composed flow, rotated or above the first element

### Arrows (Flow View)

Every transition between consecutive elements in a flow gets a curved arrow:

- Between elements on the same row: 3-point horizontal curve
- Fork arrows (vertical): 3-point vertical curve
- `strokeWidth: 1.5`, `strokeColor: "#1e1e1e"`, `roundness: { "type": 2 }`
- `startArrowhead: null`, `endArrowhead: "arrow"`
- MUST have `startBinding` and `endBinding`
- Connected rectangles MUST list the arrow in `boundElements`

### Positioning Algorithm (Flow View)

#### Step 1 -- Derive Flows
Follow policy chains from root commands to build flow chains and identify forks.

#### Step 2 -- Layout Each Flow
For each flow, place elements left-to-right with 20px gap. For forks, add branch rows below.

#### Step 3 -- Stack Flows on Canvas
Composed flows first, then simple flows. 30px gap between flows, 60px separator between groups.
Start at `(40, 40)`.

#### Step 4 -- Draw Arrows
One curved arrow between every consecutive pair of elements. Fork arrows for branches.

#### Step 5 -- Place Legend
Bottom-right. Element types: Command, Aggregate, Domain Event, Policy, Pivotal Event.
