// 1. Location nodes
LOAD CSV WITH HEADERS FROM 'file:///1_Nodes_Location_revised.csv' AS row
MERGE (l:Location {code: row.code})
SET l.name = row.name, l.location_type = row.location_type,
    l.region = row.region, l.province = row.province,
    l.is_active = (row.is_active = 'True');

// 2. TransportLeg nodes
LOAD CSV WITH HEADERS FROM 'file:///2_Nodes_TransportLeg_revised.csv' AS row
MERGE (t:TransportLeg {leg_id: row.leg_id})
SET t.origin_code = row.origin_code, t.destination_code = row.destination_code,
    t.transport_mode = row.transport_mode, t.transport_term = row.transport_term,
    t.is_active = (row.is_active = 'True');

// 3. Contract nodes
LOAD CSV WITH HEADERS FROM 'file:///3_Nodes_Contract_revised.csv' AS row
MERGE (c:Contract {contract_id: row.contract_id})
SET c.contract_scope = row.contract_scope, c.anchor_type = row.anchor_type,
    c.location_code = row.location_code, c.leg_id = row.leg_id,
    c.cost_category = row.cost_category, c.cargo_type = row.cargo_type,
    c.fert_type = row.fert_type, c.subsidy_type = row.subsidy_type,
    c.valid_from = row.valid_from, c.valid_to = row.valid_to,
    c.pricing_model = row.pricing_model, c.is_active = (row.is_active = 'True');

// 4. TariffRule nodes
LOAD CSV WITH HEADERS FROM 'file:///4_Nodes_TariffRule_revised.csv' AS row
MERGE (r:TariffRule {rule_id: row.rule_id})
SET r.contract_id = row.contract_id, r.rule_type = row.rule_type,
    r.evaluation_mode = row.evaluation_mode, r.rate = toFloat(row.rate),
    r.unit = row.unit, r.priority = toInteger(row.priority),
    r.qty_gt = CASE WHEN row.qty_gt <> '' THEN toFloat(row.qty_gt) ELSE null END,
    r.qty_lte = CASE WHEN row.qty_lte <> '' THEN toFloat(row.qty_lte) ELSE null END,
    r.is_active = (row.is_active = 'True');

// 5. ShipmentScenario nodes
LOAD CSV WITH HEADERS FROM 'file:///5_Nodes_ShipmentScenario_sample.csv' AS row
MERGE (s:ShipmentScenario {scenario_id: row.scenario_id})
SET s.cargo_type = row.cargo_type, s.fert_type = row.fert_type,
    s.subsidy_type = row.subsidy_type, s.quantity_mt = toFloat(row.quantity_mt),
    s.vessel_count = toInteger(row.vessel_count), s.pricing_date = row.pricing_date,
    s.is_active = (row.is_active = 'True');

// 6a. ORIGIN_OF: Location -> TransportLeg
LOAD CSV WITH HEADERS FROM 'file:///6_Relationships_Master_revised.csv' AS row
WITH row WHERE row.rel_type = 'ORIGIN_OF'
MATCH (a:Location {code: row.from_node}), (b:TransportLeg {leg_id: row.to_node})
MERGE (a)-[:ORIGIN_OF]->(b);

// 6b. DESTINATION_OF: TransportLeg -> Location
LOAD CSV WITH HEADERS FROM 'file:///6_Relationships_Master_revised.csv' AS row
WITH row WHERE row.rel_type = 'DESTINATION_OF'
MATCH (a:TransportLeg {leg_id: row.from_node}), (b:Location {code: row.to_node})
MERGE (a)-[:DESTINATION_OF]->(b);

// 6c. APPLIES_AT_ORIGIN: Contract -> Location
LOAD CSV WITH HEADERS FROM 'file:///6_Relationships_Master_revised.csv' AS row
WITH row WHERE row.rel_type = 'APPLIES_AT_ORIGIN'
MATCH (a:Contract {contract_id: row.from_node}), (b:Location {code: row.to_node})
MERGE (a)-[:APPLIES_AT_ORIGIN]->(b);

// 6d. APPLIES_ON_LEG: Contract -> TransportLeg
LOAD CSV WITH HEADERS FROM 'file:///6_Relationships_Master_revised.csv' AS row
WITH row WHERE row.rel_type = 'APPLIES_ON_LEG'
MATCH (a:Contract {contract_id: row.from_node}), (b:TransportLeg {leg_id: row.to_node})
MERGE (a)-[:APPLIES_ON_LEG]->(b);

// 6e. APPLIES_AT_DESTINATION: Contract -> Location
LOAD CSV WITH HEADERS FROM 'file:///6_Relationships_Master_revised.csv' AS row
WITH row WHERE row.rel_type = 'APPLIES_AT_DESTINATION'
MATCH (a:Contract {contract_id: row.from_node}), (b:Location {code: row.to_node})
MERGE (a)-[:APPLIES_AT_DESTINATION]->(b);

// 6f. HAS_RULE: Contract -> TariffRule
LOAD CSV WITH HEADERS FROM 'file:///6_Relationships_Master_revised.csv' AS row
WITH row WHERE row.rel_type = 'HAS_RULE'
MATCH (a:Contract {contract_id: row.from_node}), (b:TariffRule {rule_id: row.to_node})
MERGE (a)-[:HAS_RULE]->(b);
