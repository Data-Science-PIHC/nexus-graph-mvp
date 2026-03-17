import { Router } from 'express';

const router = Router();

// Hardcoded for MVP — matches the sample ShipmentScenario nodes
const SCENARIOS = [
  {
    id: 'SCN-UREA-8000-2026-03-12',
    label: 'Urea Curah 8.000 MT – 12 Mar 2026',
    cargo_type: 'Curah', fert_type: 'Urea', subsidy_type: 'Subsidi', pricing_date: '2026-03-12',
  },
  {
    id: 'SCN-UREA-20000-2026-06-01',
    label: 'Urea Curah 20.000 MT – 1 Jun 2026',
    cargo_type: 'Curah', fert_type: 'Urea', subsidy_type: 'Subsidi', pricing_date: '2026-06-01',
  },
];

router.get('/', (_req, res) => {
  res.json(SCENARIOS);
});

export default router;
