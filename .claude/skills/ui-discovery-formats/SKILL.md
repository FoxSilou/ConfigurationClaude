---
name: ui-discovery-formats
description: >
  Output templates for each UI Discovery phase (Screen Inventory, User Flows, Presenter Specs).
  Preloaded by the ui-discovery agent as reference for output generation.
user-invocable: false
---

# UI Discovery -- Output Templates

Reference templates for the artifacts produced at each phase.

---

## Phase 1 -- Inventaire des Ecrans

```markdown
## Inventaire des Ecrans

### Acteur : <actor name>

| # | Ecran | Route | Read Models affiches | Commandes declenchees | BC source | Complexite |
|---|-------|-------|---------------------|----------------------|-----------|------------|
| 1 | <screen name> | /<route> | <ReadModel1>, <ReadModel2> | <Command1> | <BoundedContext> | Page fine / Presenter |
| 2 | <screen name> | /<route> | <ReadModel1> | <Command1>, <Command2> | <BoundedContext> | Page fine / Presenter |
| 3 | <screen name> | /<route> | <ReadModel1> | (consultation) | <BoundedContext> | Page fine |

### Acteur : <actor name>

| # | Ecran | Route | Read Models affiches | Commandes declenchees | BC source | Complexite |
|---|-------|-------|---------------------|----------------------|-----------|------------|
| 1 | ... | ... | ... | ... | ... | ... |
```

### Rules for Phase 1

- One table per Actor
- Screen names in French, descriptive (e.g., "Parties en attente", "Ordres du tour")
- Routes follow REST-like conventions (e.g., `/parties`, `/parties/{id}/rejoindre`)
- "Complexite" column helps decide which screens need a Presenter spec in Phase 3:
  - **Page fine** : pure display, no state management, no Presenter needed
  - **Presenter** : has loading states, form interactions, error handling, or combinatorial visibility
- Mark consultation-only screens with "(consultation)" in the Commandes column

---

## Phase 2 -- Flux Utilisateur

```markdown
## Flux Utilisateur

### Flux : <flow name>

**Acteur :** <actor name>

```
[<Start screen>] --<action>--> [<Target screen>]
  |-- Succes --> [<Screen>] (notification "<message>")
  |-- Echec <reason> --> [<Screen>] (erreur "<message>")
  |-- Echec <reason> --> [<Screen>] (erreur "<message>")
```

### Flux : <flow name>

**Acteur :** <actor name>

```
[<Start screen>] --<action>--> [<Intermediate screen>]
  |-- <action> --> [<Next screen>]
       |-- Succes --> [<Final screen>]
       |-- Echec --> (meme ecran, erreur affichee)
```
```

### Rules for Phase 2

- Flow names in French, matching the event-storming flow names when possible
- Use `[Screen Name]` brackets for screen references (must match Phase 1 names)
- Use `--<action>-->` for navigation triggers
- Branch with `|-- <condition> -->` for success/error paths
- Include notification text in parentheses after redirections
- Only trace flows involving human navigation (skip policy-only automation flows)
- Keep one diagram per use case (not per micro-interaction)

---

## Phase 3 -- Specifications Presenter

```markdown
## Specifications Presenter

### Presenter : <ScreenName>Presenter

**Ecran :** <screen name> (`<route>`)
**BC source :** <BoundedContext>

#### Gateway : I<ScreenName>Gateway

| Methode | Retour | Endpoint backend |
|---------|--------|-----------------|
| Recuperer<Entity>Async(<params>) | <ReturnType> | GET /api/<path> |
| Envoyer<Action>Async(<params>) | Result<Unit> | POST /api/<path> |

#### Etat du Presenter

| Propriete | Type | Description |
|-----------|------|-------------|
| Etat | EtatChargement | Inactif, EnCours, Charge, EnErreur |
| <Data> | IReadOnlyList<<Dto>> | <description of data> |
| <Selection> | <type>? | <description of selection> |
| MessageErreur | string? | Message d'erreur eventuel |
| <ActionEnCours> | bool | True pendant un appel async d'action |

#### Proprietes derivees (visibilite)

| Propriete | Regle |
|-----------|-------|
| ChargementVisible | Etat == EnCours |
| ContenuVisible | Etat == Charge |
| ErreurVisible | MessageErreur is not null |
| <BoutonActif> | <condition combining state properties> |

#### Actions

| Methode | Declencheur UI | Comportement |
|---------|---------------|-------------|
| ChargerAsync() | OnInitialized | Charge les donnees initiales via gateway |
| <SelectionAction>(<type>) | <UI event> | Met a jour <Selection> |
| <SubmitAction>Async() | Clic bouton "<label>" | Appel gateway, gestion succes/erreur |

#### Tests Presenter (liste ordonnee TDD)

1. Charger_doit_passer_en_etat_charge_quand_gateway_retourne_des_donnees
2. Charger_doit_passer_en_erreur_quand_gateway_echoue
3. <Selection>_doit_mettre_a_jour_<property>
4. <BoutonActif>_doit_etre_faux_quand_<missing_condition>
5. <BoutonActif>_doit_etre_vrai_quand_<all_conditions_met>
6. <Action>_doit_passer_<actionEnCours>_en_true_pendant_appel
7. <Action>_doit_notifier_succes_quand_gateway_reussit
8. <Action>_doit_afficher_erreur_quand_<error_case>
```

### Rules for Phase 3

**Gateway:**
- Method names in French: `RecupererXxxAsync`, `EnvoyerXxxAsync`, `SoumettreXxxAsync`
- Return types are DTOs: `IReadOnlyList<XxxDto>`, `XxxDetailDto`, `Result<Unit>`
- Backend endpoints derived from event-storming commands/queries
- No HTTP details in the interface (no `HttpClient`, `HttpResponseMessage`)

**State:**
- Always include `Etat` (EtatChargement) for screens with async loading
- Always include `MessageErreur` for screens with error handling
- Use French names for all properties
- Use immutable collections (`IReadOnlyList<T>`)

**Derived Properties:**
- Each derived property is a pure boolean computed from state
- Naming pattern: `<What>Visible`, `<What>Actif`, `<What>Desactive`
- Must be derivable -- no async, no side effects

**Actions:**
- Map 1:1 to user interactions (click, change, submit)
- Describe state transitions, not implementation details
- Async actions that call the gateway should set a `<Action>EnCours` flag

**Test List:**
- Follow Transformation Priority Premise: constant -> computed -> conditional
- Start with happy path (loading succeeds)
- Then error path (loading fails)
- Then selection/interaction (state updates)
- Then derived properties (visibility rules)
- Then submission (async action with success/error)
- Naming: `Action_doit_resultat_quand_contexte`
- Each test name must be usable verbatim as a C# method name

**Simplicity Gate:**
Before writing a Presenter spec for a screen, verify:
- Does this screen have more than one interesting test? If no -> skip (page fine)
- Is there combinatorial visibility logic? If no -> .razor handles it
- Are there state transitions (loading -> loaded -> error)? If no -> no Presenter
- Mark skipped screens with a note: `> Page fine -- pas de Presenter. Le .razor suffit.`

---

## Final Document Structure

```markdown
# UI Discovery -- <Bounded Context>

> Domain: <domain name>
> Date: <date>
> Source: <path to event-storming document>

## Inventaire des Ecrans

<Phase 1 content>

## Flux Utilisateur

<Phase 2 content>

## Specifications Presenter

<Phase 3 content -- one subsection per Presenter>
```
