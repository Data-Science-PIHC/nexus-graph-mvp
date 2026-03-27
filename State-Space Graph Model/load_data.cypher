// 0. Bersihkan Graf (Hati-hati - hapus semua data!)
MATCH (n) DETACH DELETE n;

// 1. Load CargoState Nodes
LOAD CSV WITH HEADERS FROM 'file:///1_CargoStates.csv' AS row
CREATE (:CargoState {
    state_id:      row.state_id,
    location_code: row.location_code,
    location_name: row.location_name,
    packaging:     row.packaging
});

// 2. Load Operation Nodes dan sambungkan ke CargoState
LOAD CSV WITH HEADERS FROM 'file:///2_Operations.csv' AS row
MATCH  (from:CargoState {state_id: row.from_state_id})
MATCH  (to:CargoState   {state_id: row.to_state_id})
CREATE (from)-[:REQUIRES_OPERATION]->(op:Operation {
    operation_id:   row.operation_id,
    operation_type: row.operation_type
})-[:PRODUCES_STATE]->(to);

// 3a. Load TariffMaster yang menempel ke OPERATION (anchor_type = TRANSPORT_LEG)
LOAD CSV WITH HEADERS FROM 'file:///3_TariffMasters.csv' AS row
WITH row WHERE row.anchor_type = 'TRANSPORT_LEG' AND row.anchor_op_id IS NOT NULL AND row.anchor_op_id <> ''
MATCH (op:Operation {operation_id: trim(row.anchor_op_id)})
CREATE (t:TariffMaster {
    tariff_id:       row.tariff_id,
    anchor_type:     row.anchor_type,
    anchor_op_id:    trim(row.anchor_op_id),
    cost_category:   row.cost_category,
    contract_scope:  row.contract_scope,
    valid_from:      date(row.valid_from),
    valid_to:        date(row.valid_to),
    is_active:       toBoolean(row.is_active)
})
CREATE (t)-[:APPLIES_TO_OPERATION]->(op);

// 3b. Load TariffMaster yang menempel ke CARGOSTATE (anchor_type = LOCATION)
LOAD CSV WITH HEADERS FROM 'file:///3_TariffMasters.csv' AS row
WITH row WHERE row.anchor_type = 'LOCATION' AND row.anchor_state_id IS NOT NULL AND row.anchor_state_id <> ''
MATCH (s:CargoState {state_id: trim(row.anchor_state_id)})
CREATE (t:TariffMaster {
    tariff_id:       row.tariff_id,
    anchor_type:     row.anchor_type,
    anchor_state_id: trim(row.anchor_state_id),
    cost_category:   row.cost_category,
    contract_scope:  row.contract_scope,
    valid_from:      date(row.valid_from),
    valid_to:        date(row.valid_to),
    is_active:       toBoolean(row.is_active)
})
CREATE (t)-[:APPLIES_AT_STATE]->(s);

// 4. Load Conditions (Dynamic Rules Engine)
LOAD CSV WITH HEADERS FROM 'file:///4_Conditions.csv' AS row
MATCH (t:TariffMaster {tariff_id: row.tariff_id})
CREATE (c:Condition {
    condition_id:   row.condition_id,
    property_key:   row.property_key,
    operator:       row.operator,
    property_value: row.property_value
})
CREATE (t)-[:HAS_CONDITION]->(c);

// 5. Load RateTiers
LOAD CSV WITH HEADERS FROM 'file:///5_RateTiers.csv' AS row
MATCH (t:TariffMaster {tariff_id: row.tariff_id})
CREATE (r:RateTier {
    tier_id:  row.tier_id,
    min_qty:  toFloat(row.min_qty),
    max_qty:  toFloat(row.max_qty),
    rate:     toFloat(row.rate),
    unit:     row.unit
})
CREATE (t)-[:HAS_TIER]->(r);

// 6. Create Default Shipment Scenarios (Sample)
MERGE (s:ShipmentScenario {scenario_id: 'SCN-UREA-8000-2026-03-12'})
SET 
    s.fert_type = 'Urea',
    s.subsidy_type = 'Subsidi',
    s.quantity_mt = 8000.0,
    s.product_count = 1,
    s.is_sealed = false,
    s.pricing_date = date('2026-03-12');

// ── VERIFIKASI: Cek apakah tarif Freight kapal sudah terhubung ke operasi ──
// MATCH (op:Operation {operation_id: 'OP_MOVE_CU_D101-D718-PTPS'})
// OPTIONAL MATCH (op)<-[:APPLIES_TO_OPERATION]-(t:TariffMaster)-[:HAS_TIER]->(r:RateTier)
// RETURN op.operation_id, t.tariff_id, t.cost_category, r.rate
