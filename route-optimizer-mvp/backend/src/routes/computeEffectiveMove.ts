import { Router, Request, Response } from 'express';
import driver from '../neo4j';

const router = Router();

router.post('/', async (req: Request, res: Response) => {
  const { scenario_id, cargo_type, fert_type, subsidy_type, pricing_date } = req.body;

  if (!scenario_id || !cargo_type || !fert_type || !subsidy_type || !pricing_date) {
    res.status(400).json({ error: 'BAD_REQUEST', message: 'All scenario fields are required.' });
    return;
  }

  const session = driver.session();
  try {
    // Step 1: delete old EFFECTIVE_MOVE for this scenario
    await session.run(
      `MATCH ()-[r:EFFECTIVE_MOVE {scenario_id: $scenario_id}]->() DELETE r`,
      { scenario_id }
    );

    // Step 2: compute and create new EFFECTIVE_MOVE edges
    const result = await session.run(
      `MATCH (a:Location)-[:ORIGIN_OF]->(leg:TransportLeg)-[:DESTINATION_OF]->(b:Location)

       CALL {
         WITH a
         OPTIONAL MATCH (a)<-[:APPLIES_AT_ORIGIN]-(c:Contract)-[:HAS_RULE]->(tr:TariffRule)
        //  WHERE c.is_active = true AND tr.is_active = true AND tr.unit = 'ton'
        //    AND (c.cargo_type   IN [$cargo_type, 'All'] OR c.cargo_type IS NULL)
        //    AND (c.fert_type    IN [$fert_type, 'All']  OR c.fert_type IS NULL)
        //    AND (c.subsidy_type IN [$subsidy_type, 'All'] OR c.subsidy_type IS NULL)
        //    AND date(c.valid_from) <= date($pricing_date)
        //    AND date(c.valid_to)   >= date($pricing_date)
         RETURN coalesce(sum(DISTINCT toFloat(tr.rate)), 0.0) AS origin_cost
       }

       CALL {
         WITH leg
         OPTIONAL MATCH (leg)<-[:APPLIES_ON_LEG]-(c:Contract)-[:HAS_RULE]->(tr:TariffRule)
        //  WHERE c.is_active = true AND tr.is_active = true AND tr.unit = 'ton'
        //    AND (c.cargo_type   IN [$cargo_type, 'All'] OR c.cargo_type IS NULL)
        //    AND (c.fert_type    IN [$fert_type, 'All']  OR c.fert_type IS NULL)
        //    AND (c.subsidy_type IN [$subsidy_type, 'All'] OR c.subsidy_type IS NULL)
        //    AND date(c.valid_from) <= date($pricing_date)
        //    AND date(c.valid_to)   >= date($pricing_date)
         RETURN coalesce(sum(DISTINCT toFloat(tr.rate)), 0.0) AS leg_cost
       }

       CALL {
         WITH b
         OPTIONAL MATCH (b)<-[:APPLIES_AT_DESTINATION]-(c:Contract)-[:HAS_RULE]->(tr:TariffRule)
        //  WHERE c.is_active = true AND tr.is_active = true AND tr.unit = 'ton'
        //    AND (c.cargo_type   IN [$cargo_type, 'All'] OR c.cargo_type IS NULL)
        //    AND (c.fert_type    IN [$fert_type, 'All']  OR c.fert_type IS NULL)
        //    AND (c.subsidy_type IN [$subsidy_type, 'All'] OR c.subsidy_type IS NULL)
        //    AND date(c.valid_from) <= date($pricing_date)
        //    AND date(c.valid_to)   >= date($pricing_date)
         RETURN coalesce(sum(DISTINCT toFloat(tr.rate)), 0.0) AS destination_cost
       }

       WITH a, b, leg, origin_cost, leg_cost, destination_cost,
            origin_cost + leg_cost + destination_cost AS total_cost
       WHERE total_cost > 0

       MERGE (a)-[em:EFFECTIVE_MOVE {scenario_id: $scenario_id, leg_id: leg.leg_id}]->(b)
       SET em.origin_cost_per_ton      = origin_cost,
           em.leg_cost_per_ton         = leg_cost,
           em.destination_cost_per_ton = destination_cost,
           em.cost_per_ton             = total_cost,
           em.currency                 = 'IDR',
           em.pricing_date             = $pricing_date,
           em.is_active                = true

       RETURN count(em) AS edges_created`,
      { scenario_id, cargo_type, fert_type, subsidy_type, pricing_date }
    );

    const count = result.records[0]?.get('edges_created');
    res.json({ success: true, edges_created: count });
  } catch (e) {
    res.status(500).json({ error: 'DB_ERROR', message: String(e) });
  } finally {
    await session.close();
  }
});

export default router;
