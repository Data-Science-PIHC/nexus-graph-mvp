<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# nice, make it into one md file so then I can just drop it into kiro

```markdown
# MVP Spec – Route Optimizer (Least-Cost Graph Routing)

## 1. Purpose

Build a small web-based MVP that demonstrates the capability of a graph-based
optimizer to find the **top 3 least-cost routes** between any origin–destination
pair, for a selected pricing scenario.

Costs are precomputed in Neo4j as `EFFECTIVE_MOVE` relationships between
`Location` nodes, derived from contract and tariff data.

Primary objective: business users can select a scenario, origin, and
destination, then see the cheapest routes with leg-level cost breakdown.

---

## 2. Tech stack

**Backend**
- Node.js + TypeScript
- HTTP framework: Express
- Database driver: `neo4j-driver`
- Config via environment variables:
  - `NEO4J_URI`
  - `NEO4J_USER`
  - `NEO4J_PASSWORD`

**Frontend**
- React SPA
- Styling: Tailwind CSS
- Build tooling: Vite

**Database**
- Neo4j Aura instance, already populated with:
  - `Location`, `TransportLeg`, `Contract*`, `TariffRule`
  - `EFFECTIVE_MOVE` relationships per scenario

---

## 3. Data assumptions

**Location node properties:**
- `code` – unique identifier (e.g. `D101`)
- `name` – display name (e.g. `GD Lini 1 Bontang`)
- `location_type` – e.g. `L1_Warehouse`, `Port`, `L2_Warehouse`, `L3_Warehouse`
- `region`, `province`
- `is_active` – boolean

**EFFECTIVE_MOVE relationship properties:**
- Pattern: `(:Location)-[r:EFFECTIVE_MOVE]->(:Location)`
- `scenario_id` – string
- `leg_id` – string
- `origin_cost_per_ton` – number
- `leg_cost_per_ton` – number
- `destination_cost_per_ton` – number
- `cost_per_ton` – number (sum of all three)
- `currency` – `IDR`
- `pricing_date` – string
- `is_active` – boolean

The MVP **does not** run pricing. It only reads `EFFECTIVE_MOVE` edges that
have already been built for the selected scenario.

---

## 4. API design

All APIs are JSON over HTTP.

---

### 4.1. GET /api/locations

Return all active locations for dropdowns.

**Response 200:**
```json
[
  { "code": "D101", "name": "GD Lini 1 Bontang", "type": "L1_Warehouse" },
  { "code": "D718", "name": "Pelabuhan Lembar",   "type": "Port" }
]
```

**Neo4j query:**

```cypher
MATCH (l:Location)
WHERE l.is_active = true
RETURN l.code AS code, l.name AS name, l.location_type AS type
ORDER BY name;
```


---

### 4.2. GET /api/scenarios

Return available pricing scenarios. Hardcode for MVP.

**Response 200:**

```json
[
  {
    "id":    "SCN-UREA-8000-2026-03-12",
    "label": "Urea Curah 8.000 – 12 Mar 2026"
  }
]
```


---

### 4.3. POST /api/optimize-route

Given a scenario and origin/destination codes, return up to 3 cheapest routes.

**Request:**

```json
{
  "scenario_id": "SCN-UREA-8000-2026-03-12",
  "from_code":   "D101",
  "to_code":     "D211"
}
```

**Response 200 (routes found):**

```json
{
  "scenario_id": "SCN-UREA-8000-2026-03-12",
  "from_code":   "D101",
  "to_code":     "D211",
  "routes": [
    {
      "rank": 1,
      "path_cost": 530400.0,
      "nodes": [
        { "code": "D101", "name": "GD Lini 1 Bontang",    "type": "L1_Warehouse" },
        { "code": "D718", "name": "Pelabuhan Lembar",      "type": "Port"         },
        { "code": "D216", "name": "GD Carisma Lembar",    "type": "L2_Warehouse" },
        { "code": "D211", "name": "GD PKT Lombok Barat",  "type": "L3_Warehouse" }
      ],
      "legs": [
        {
          "leg_id":                    "D101-D718-PTPS",
          "cost_per_ton":              530400,
          "origin_cost_per_ton":       400,
          "leg_cost_per_ton":          530000,
          "destination_cost_per_ton":  0
        }
      ]
    }
  ]
}
```

**Response 404 (no path found):**

```json
{
  "error":   "NO_ROUTE",
  "message": "No valid route found for this origin, destination, and scenario."
}
```

**Neo4j query used by this endpoint:**

```cypher
MATCH (src:Location {code: $from_code}),
      (dst:Location {code: $to_code})

MATCH p = (src)-[:EFFECTIVE_MOVE*1..10]->(dst)
WHERE all(r IN relationships(p) WHERE r.scenario_id = $scenario_id)

WITH p,
     reduce(total = 0.0, r IN relationships(p) |
            total + coalesce(r.cost_per_ton, 0.0)) AS path_cost
RETURN
  [n IN nodes(p) | {
    code: n.code,
    name: n.name,
    type: n.location_type
  }] AS route_nodes,
  [r IN relationships(p) | {
    leg_id:                   r.leg_id,
    cost_per_ton:             r.cost_per_ton,
    origin_cost_per_ton:      r.origin_cost_per_ton,
    leg_cost_per_ton:         r.leg_cost_per_ton,
    destination_cost_per_ton: r.destination_cost_per_ton
  }] AS route_legs,
  path_cost
ORDER BY path_cost ASC
LIMIT 3;
```


---

## 5. Frontend UX requirements

Single-page layout with two sections: **Inputs** and **Results**.

### 5.1. Inputs panel

| Component | Behaviour |
| :-- | :-- |
| Scenario dropdown | Populated from `GET /api/scenarios`. Default: first in list. |
| Origin dropdown | Populated from `GET /api/locations`. Shows `name (code)`. |
| Destination dropdown | Same as Origin. |
| Swap button | Swap selected origin and destination values. |
| "Find cheapest routes" | Primary button. Disabled while loading. POSTs to `/api/optimize-route`. |

### 5.2. Results panel states

**1. Initial / empty**
> "Select a scenario and origin–destination pair, then click 'Find cheapest routes'."

**2. Loading**
> Spinner + "Optimizing route…"

**3. Success**
> "Showing top 3 cheapest routes from {origin} to {destination}"

For each route show a card containing:

- Title: `Route {rank} – IDR {path_cost} / ton`
- Node pills in order: `D101 → D718 → D216 → D211`
- Leg breakdown table:

| Leg ID | Origin cost | Leg cost | Destination cost | Total / ton |
| :-- | :-- | :-- | :-- | :-- |
| D101-D718-PTPS | 400 | 530,000 | 0 | 530,400 |

**4. No route (404)**
> "No valid route found for this origin, destination, and scenario."

**5. Error (other)**
> Toast: "Something went wrong while optimizing the route."

---

## 6. Folder structure (suggested)

```
route-optimizer-mvp/
├── backend/
│   ├── src/
│   │   ├── index.ts          # Express app entry
│   │   ├── neo4j.ts          # Neo4j driver setup
│   │   └── routes/
│   │       ├── locations.ts
│   │       ├── scenarios.ts
│   │       └── optimizeRoute.ts
│   ├── .env.example
│   ├── package.json
│   └── tsconfig.json
├── frontend/
│   ├── src/
│   │   ├── main.tsx
│   │   ├── App.tsx
│   │   └── components/
│   │       ├── ScenarioSelector.tsx
│   │       ├── LocationSelector.tsx
│   │       └── RouteResults.tsx
│   ├── index.html
│   ├── vite.config.ts
│   └── package.json
├── spec/
│   └── mvp-route-optimizer.md   ← this file
└── README.md
```


---

## 7. Environment variables

Create `backend/.env` (never commit):

```
NEO4J_URI=neo4j+s://<your-aura-uri>
NEO4J_USER=neo4j
NEO4J_PASSWORD=<your-password>
```

Template at `backend/.env.example`:

```
NEO4J_URI=
NEO4J_USER=
NEO4J_PASSWORD=
```


---

## 8. Running locally

```bash
# backend
cd backend && npm install && npm run dev

# frontend (separate terminal)
cd frontend && npm install && npm run dev
```

Frontend dev server proxies `/api/*` to `http://localhost:3001`.

---

## 9. Non-functional requirements

- Single `npm run dev` command per service.
- No authentication in MVP.
- Max path length: 10 `EFFECTIVE_MOVE` hops.
- Cost unit: `cost_per_ton` in IDR only.
- Code structured so backend and frontend can later be deployed independently.

---

## 10. Out of scope for this MVP

- Running the EFFECTIVE_MOVE pricing generator from the UI.
- Volume-based cost calculation.
- Multi-scenario comparison in one view.
- Map / geographic visualization.
- User login / access control.

```

Copy the entire block, save it as `spec/mvp-route-optimizer.md` in your repo, then point Kiro at it and let it scaffold from there.```

