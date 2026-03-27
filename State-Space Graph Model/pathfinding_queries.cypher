/* 
   =============================================================================
   NEXUS GRAPH LOGISTICS - PATHFINDING & AUDIT SUITE
   =============================================================================
   Author: Nexus Graph Dev Team
   Objective: Dynamic route cost calculation, commercial validation, 
              and granular audit for fertilizer distribution (Sistem NTB).
   =============================================================================
*/

// --- PANDUAN PENGGUNAAN ---
// 1. Jalankan STEP 1 untuk me-refresh jalur efektif berdasarkan skenario.
// 2. Jalankan STEP 2 untuk melihat ringkasan rute termurah.
// 3. Jalankan STEP 3 (dengan mengatur Rank) untuk melakukan audit biaya.


/* 
   STEP 1: SMART EFFECTIVE_MOVE GENERATOR
   -----------------------------------------------------------------------------
   Menghitung biaya tiap langkah dengan multiplier n-1 (penggandaan) 
   dan filter komersial (Freight/Bagging check).
*/

MATCH (a:CargoState)-[em:EFFECTIVE_MOVE]->(b:CargoState) DELETE em;

MATCH (scenario:ShipmentScenario {scenario_id: 'SCN-UREA-8000-2026-03-12'})
MATCH (origin:CargoState)-[:REQUIRES_OPERATION]->(op:Operation)-[:PRODUCES_STATE]->(destination:CargoState)

CALL {
    WITH origin, destination, op, scenario
    MATCH (tariff:TariffMaster)
    WHERE ( (tariff)-[:APPLIES_AT_STATE]->(origin)      AND tariff.contract_scope IN ['Origin', 'Both']      AND op.operation_type STARTS WITH 'MOVE' )
       OR ( (tariff)-[:APPLIES_AT_STATE]->(destination) AND tariff.contract_scope IN ['Destination', 'Both'] AND op.operation_type STARTS WITH 'MOVE' )
       OR ( (tariff)-[:APPLIES_TO_OPERATION]->(op) )

    OPTIONAL MATCH (tariff)-[:HAS_CONDITION]->(cond:Condition)
    WITH tariff, scenario, origin, collect(cond) AS conditions
    WHERE size(conditions) = 0 OR all(c IN conditions WHERE 
        (c.property_key = 'cargo_type'  AND toLower(origin.packaging) = toLower(c.property_value)) OR
        (c.operator     = 'EQUALS'      AND toLower(toString(scenario[c.property_key])) = toLower(c.property_value)) OR
        (c.operator     = 'GREATER_THAN' AND toInteger(scenario[c.property_key]) > toInteger(c.property_value))
    )

    MATCH (tariff)-[:HAS_TIER]->(tier:RateTier)
    WHERE tier.min_qty <= scenario.quantity_mt <= tier.max_qty
    
    WITH tariff.cost_category AS category,
         CASE 
            WHEN tariff.tariff_id STARTS WITH 'SVG-' THEN (toInteger(scenario.product_count) - 1) * tier.rate 
            WHEN tariff.tariff_id STARTS WITH 'SVP-D101' AND NOT coalesce(scenario.is_sealed, false) THEN 0
            ELSE tier.rate 
         END AS final_rate
    RETURN collect(category) AS categories, sum(final_rate) AS total_step_cost
}

WITH origin, destination, op, scenario, categories, total_step_cost
WHERE (size(categories) > 0 AND ANY(cat IN categories WHERE cat =~ '.*(Freight|Angkutan|Bagging).*'))
   OR (size(categories) = 0 AND op.operation_type STARTS WITH 'MOVE')

MERGE (origin)-[em:EFFECTIVE_MOVE { scenario_id: scenario.scenario_id, op_id: op.operation_id }]->(destination)
SET 
    em.cost_per_ton = total_step_cost,
    em.from_loc     = origin.location_code,
    em.to_loc       = destination.location_code,
    em.op_type      = op.operation_type,
    em.is_active    = true;


/* 
   STEP 2: ROUTE SUMMARY (TOP 3 CHEAPEST)
   -----------------------------------------------------------------------------
   Melihat 3 rute termurah dari Pabrik ke lokasi tujuan.
*/

MATCH (origin:CargoState {location_code: 'D101', packaging: 'Curah'})
MATCH (destination:CargoState {location_code: 'D211', packaging: 'Inbag'})
MATCH path = (origin)-[:EFFECTIVE_MOVE*1..10 {scenario_id: 'SCN-UREA-8000-2026-03-12', is_active: true}]->(destination)

WITH path, reduce(total = 0.0, rel IN relationships(path) | total + rel.cost_per_ton) AS total_route_cost
ORDER BY total_route_cost ASC LIMIT 3

RETURN 
    [node IN nodes(path) | node.location_code + "(" + node.packaging + ")"] AS Full_Path,
    round(total_route_cost) AS Total_Cost_Per_Ton,
    size(relationships(path)) AS Total_Hops,
    [rel IN relationships(path) | rel.op_type] AS Operation_Sequence
ORDER BY total_route_cost ASC;


/* 
   STEP 3: GRANULAR COST BREAKDOWN (AUDIT)
   -----------------------------------------------------------------------------
   Ganti variabel rank_pilihan (1, 2, atau 3) untuk melihat rincian biaya rute tersebut.
*/

WITH 1 AS rank_pilihan 

MATCH (origin:CargoState {location_code: 'D101', packaging: 'Curah'})
MATCH (destination:CargoState {location_code: 'D211', packaging: 'Inbag'})
MATCH path = (origin)-[:EFFECTIVE_MOVE*1..10 {scenario_id: 'SCN-UREA-8000-2026-03-12', is_active: true}]->(destination)

WITH rank_pilihan, path, reduce(t = 0.0, r IN relationships(path) | t + r.cost_per_ton) AS total_cost
ORDER BY total_cost ASC 

WITH rank_pilihan, collect({p: path, c: total_cost}) AS results
WITH results[rank_pilihan - 1] AS selected
WHERE selected IS NOT NULL

WITH selected.p AS path, selected.c AS total_cost
MATCH (scenario:ShipmentScenario {scenario_id: 'SCN-UREA-8000-2026-03-12'})
UNWIND relationships(path) AS rel
MATCH (op:Operation {operation_id: rel.op_id})
MATCH (from:CargoState)-[:REQUIRES_OPERATION]->(op)-[:PRODUCES_STATE]->(to:CargoState)

MATCH (tariff:TariffMaster)
WHERE ( (tariff)-[:APPLIES_AT_STATE]->(from) AND tariff.contract_scope IN ['Origin', 'Both']      AND op.operation_type STARTS WITH 'MOVE' )
   OR ( (tariff)-[:APPLIES_AT_STATE]->(to)   AND tariff.contract_scope IN ['Destination', 'Both'] AND op.operation_type STARTS WITH 'MOVE' )
   OR ( (tariff)-[:APPLIES_TO_OPERATION]->(op) )

OPTIONAL MATCH (tariff)-[:HAS_CONDITION]->(cond:Condition)
WITH rel, tariff, scenario, from, total_cost, collect(cond) AS conditions
WHERE size(conditions) = 0 OR all(c IN conditions WHERE 
    (c.property_key = 'cargo_type'  AND toLower(from.packaging) = toLower(c.property_value)) OR
    (c.operator     = 'EQUALS'      AND toLower(toString(scenario[c.property_key])) = toLower(c.property_value)) OR
    (c.operator     = 'GREATER_THAN' AND toInteger(scenario[c.property_key]) > toInteger(c.property_value))
)

MATCH (tariff)-[:HAS_TIER]->(tier:RateTier)
WHERE tier.min_qty <= scenario.quantity_mt <= tier.max_qty

RETURN 
    rel.from_loc + " → " + rel.to_loc AS Leg,
    from.packaging AS Cargo_Type,
    rel.op_type AS Operation,
    tariff.cost_category AS Component,
    CASE 
        WHEN tariff.tariff_id STARTS WITH 'SVG-' THEN (toInteger(scenario.product_count) - 1) * tier.rate 
        WHEN tariff.tariff_id STARTS WITH 'SVP-D101' AND NOT coalesce(scenario.is_sealed, false) THEN 0
        ELSE tier.rate 
    END AS Cost,
    round(total_cost) AS Running_Total
ORDER BY Leg, Component;
