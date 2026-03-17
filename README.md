# Route Optimizer MVP

A graph-based web app that finds the **top 3 least-cost routes** between any origin–destination pair using precomputed `EFFECTIVE_MOVE` relationships in Neo4j.

---

## How it works

Costs are precomputed in Neo4j as `EFFECTIVE_MOVE` relationships between `Location` nodes, derived from contract and tariff data. The app does **not** run pricing — it only reads edges already built for the selected scenario.

---

## Tech stack

| Layer | Tech |
| :-- | :-- |
| Backend | Node.js + TypeScript, Express, `neo4j-driver` |
| Frontend | React, Tailwind CSS, Vite |
| Database | Neo4j Aura |

---

## Project structure

```
route-optimizer-mvp/
├── backend/
│   ├── src/
│   │   ├── index.ts              # Express app entry
│   │   ├── neo4j.ts              # Neo4j driver setup
│   │   └── routes/
│   │       ├── locations.ts
│   │       ├── scenarios.ts
│   │       └── optimizeRoute.ts
│   ├── .env.example
│   ├── package.json
│   └── tsconfig.json
└── frontend/
    ├── src/
    │   ├── main.tsx
    │   ├── App.tsx
    │   └── components/
    │       └── RouteResults.tsx
    ├── vite.config.ts
    └── package.json
```

---

## Getting started

### 1. Configure environment

Copy the example env file and fill in your Neo4j Aura credentials:

```bash
cp backend/.env.example backend/.env
```

```env
NEO4J_URI=neo4j+s://<your-aura-uri>
NEO4J_USER=neo4j
NEO4J_PASSWORD=<your-password>
```

### 2. Run the backend

```bash
cd backend
npm install
npm run dev
```

Runs on `http://localhost:3001`.

### 3. Run the frontend

```bash
cd frontend
npm install
npm run dev
```

Runs on `http://localhost:5173`. The dev server proxies `/api/*` to the backend.

---

## API reference

### GET /api/locations

Returns all active locations for dropdowns.

```json
[
  { "code": "D101", "name": "GD Lini 1 Bontang", "type": "L1_Warehouse" },
  { "code": "D718", "name": "Pelabuhan Lembar",   "type": "Port" }
]
```

### GET /api/scenarios

Returns available pricing scenarios.

```json
[
  { "id": "SCN-UREA-8000-2026-03-12", "label": "Urea Curah 8.000 – 12 Mar 2026" }
]
```

### POST /api/optimize-route

Returns up to 3 cheapest routes for a given scenario and origin/destination.

**Request:**
```json
{
  "scenario_id": "SCN-UREA-8000-2026-03-12",
  "from_code": "D101",
  "to_code": "D211"
}
```

**Response (200):**
```json
{
  "scenario_id": "SCN-UREA-8000-2026-03-12",
  "from_code": "D101",
  "to_code": "D211",
  "routes": [
    {
      "rank": 1,
      "path_cost": 530400.0,
      "nodes": [
        { "code": "D101", "name": "GD Lini 1 Bontang",   "type": "L1_Warehouse" },
        { "code": "D718", "name": "Pelabuhan Lembar",     "type": "Port" },
        { "code": "D211", "name": "GD PKT Lombok Barat",  "type": "L3_Warehouse" }
      ],
      "legs": [
        {
          "leg_id": "D101-D718-PTPS",
          "cost_per_ton": 530400,
          "origin_cost_per_ton": 400,
          "leg_cost_per_ton": 530000,
          "destination_cost_per_ton": 0
        }
      ]
    }
  ]
}
```

**Response (404 — no path):**
```json
{ "error": "NO_ROUTE", "message": "No valid route found for this origin, destination, and scenario." }
```

---

## Data model

**Location node properties:** `code`, `name`, `location_type`, `region`, `province`, `is_active`

**EFFECTIVE_MOVE relationship properties:**

| Property | Type | Description |
| :-- | :-- | :-- |
| `scenario_id` | string | Pricing scenario identifier |
| `leg_id` | string | Unique leg identifier |
| `origin_cost_per_ton` | number | Cost at origin |
| `leg_cost_per_ton` | number | Transport cost |
| `destination_cost_per_ton` | number | Cost at destination |
| `cost_per_ton` | number | Sum of all three |
| `currency` | string | Always `IDR` |
| `is_active` | boolean | — |

---

## Out of scope (MVP)

- Running the EFFECTIVE_MOVE pricing generator from the UI
- Volume-based cost calculation
- Multi-scenario comparison in one view
- Map / geographic visualization
- User authentication
