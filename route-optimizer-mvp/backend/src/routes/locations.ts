import { Router } from 'express';
import driver from '../neo4j';

const router = Router();

router.get('/', async (_req, res) => {
  const session = driver.session();
  try {
    const result = await session.run(
      `MATCH (l:Location) WHERE l.is_active = true
       RETURN l.code AS code, l.name AS name, l.location_type AS type
       ORDER BY l.name`
    );
    res.json(result.records.map(r => r.toObject()));
  } catch (e) {
    res.status(500).json({ error: 'DB_ERROR', message: String(e) });
  } finally {
    await session.close();
  }
});

export default router;
