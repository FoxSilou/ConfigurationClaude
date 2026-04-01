---
name: excalidraw-event-storming-steps
description: >
  Generates Excalidraw diagrams for intermediate Event Storming steps:
  - view: chaotic -- scattered event post-its (Big Picture exploration)
  - view: timeline -- events on a horizontal timeline with pivotal events and phases
  - view: process -- Process Modeling chains (Event -> Policy -> Command -> System -> Event)
  Complements the excalidraw-event-storming skill which handles the final
  Software Design views (aggregate + flow).
---

# Excalidraw Event Storming Steps -- Intermediate Diagrams

## Purpose

Generate Excalidraw diagrams for the intermediate steps of an Event Storming workshop. These diagrams reflect the **current level of understanding** -- they are not anticipations of the final model.

This skill produces **one `.excalidraw` file per step** (Steps 1-3). Step 4 uses the existing `excalidraw-event-storming` skill for aggregate + flow views.

## Shared Rules

This skill uses the **same shared rules** as `excalidraw-event-storming`:
- Same sticky note color convention (see parent skill)
- Same dynamic sizing formulas
- Same Excalidraw JSON element templates (rectangle + main text + sublabel)
- Same file wrapper format
- Same legend placement (bottom-right)

**Additional color (this skill only):**

| Element Type | Background Color | Stroke | Label Below | Shape |
|---|---|---|---|---|
| Hotspot | `#ffc9c9` (pink/magenta) | `#c92a2a` (red) | `HOTSPOT` | rectangle, no roundness |
| Phase Separator | transparent | `#868e96` (gray) | phase name | dashed line, strokeWidth 1 |
| Timeline Arrow | transparent | `#495057` (dark gray) | `TIME -->` | arrow, strokeWidth 2 |

**Hotspot sticky sizing:**
```
text_width    = charCount * 9.5
sticky_width  = max(160, text_width + 30)
sticky_height = 65
text_el_width = sticky_width - 20
```

---

## Diagram Specification Format

```
DIAGRAM_SPEC:
  view: chaotic | timeline | process
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
  output: docs/event-storming/cinema/01-big-picture-raw
```

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

- Curved arrows between every consecutive pair: same arrow template as `excalidraw-event-storming`
- Vertical arrows from Actor to Read Model: short, straight, no curve
- `strokeWidth: 1.5` for chain arrows, `strokeWidth: 1` for Actor-ReadModel arrows

#### Step 6 -- Legend

Bottom-right. Show: Domain Event, Command, Policy, Actor, Read Model, External System, Hotspot (if any remain).

---

## File Wrapper

Same as `excalidraw-event-storming`:

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
