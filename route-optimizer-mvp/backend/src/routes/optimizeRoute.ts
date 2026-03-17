import { Router, Request, Response } from 'express';
import driver from '../neo4j';

const router = Router();

router.post('/', async (req: Request, res: Response) => {
  const { scenario_id, from_code, to_code } = req.body;

  if (!scenario_id || !from_code || !to_code) {
    res.status(400).json({ error: 'BAD_REQUEST', message: 'scenario_id, from_code, and to_code are required.' });
    return;
  }

  const session = driver.session();
  try {
    const result = await session.run(
      `MATCH (src:Location {code: $from_code}), (dst:Location {code: $to_code})
       MATCH p = (src)-[:EFFECTIVE_MOVE*1..10]->(dst)
       WHERE all(r IN relationships(p) WHERE r.scenario_id = $scenario_id)
       WITH p,
            reduce(total = 0.0, r IN relationships(p) | total + coalesce(r.cost_per_ton, 0.0)) AS path_cost
       RETURN
         [n IN nodes(p) | { code: n.code, name: n.name, type: n.location_type }] AS route_nodes,
         [r IN relationships(p) | {
           leg_id: r.leg_id,
           cost_per_ton: r.cost_per_ton,
           origin_cost_per_ton: r.origin_cost_per_ton,
           leg_cost_per_ton: r.leg_cost_per_ton,
           destination_cost_per_ton: r.destination_cost_per_ton
         }] AS route_legs,
         path_cost
       ORDER BY path_cost ASC
       LIMIT 3`,
      { scenario_id, from_code, to_code }
    );

    if (result.records.length === 0) {
      res.status(404).json({ error: 'NO_ROUTE', message: 'No valid route found for this origin, destination, and scenario.' });
      return;
    }

    const routes = result.records.map((r, i) => ({
      rank: i + 1,
      path_cost: r.get('path_cost'),
      nodes: r.get('route_nodes'),
      legs: r.get('route_legs'),
    }));

    res.json({ scenario_id, from_code, to_code, routes });
  } catch (e) {
    res.status(500).json({ error: 'DB_ERROR', message: String(e) });
  } finally {
    await session.close();
  }
});

export default router;
