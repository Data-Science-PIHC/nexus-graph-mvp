import { useEffect, useState } from 'react';
import RouteResults from './components/RouteResults';

interface Scenario {
  id: string; label: string;
  cargo_type: string; fert_type: string; subsidy_type: string; pricing_date: string;
}
interface Location { code: string; name: string; type: string; }
interface RouteLeg {
  leg_id: string; cost_per_ton: number;
  origin_cost_per_ton: number; leg_cost_per_ton: number; destination_cost_per_ton: number;
}
interface Route { rank: number; path_cost: number; nodes: Location[]; legs: RouteLeg[]; }

export default function App() {
  const [scenarios, setScenarios] = useState<Scenario[]>([]);
  const [locations, setLocations] = useState<Location[]>([]);
  const [scenarioId, setScenarioId] = useState('');
  const [fromCode, setFromCode] = useState('');
  const [toCode, setToCode] = useState('');
  const [status, setStatus] = useState<'idle' | 'computing' | 'loading' | 'done' | 'no_route' | 'error'>('idle');
  const [routes, setRoutes] = useState<Route[]>([]);
  const [errorMsg, setErrorMsg] = useState('');

  useEffect(() => {
    fetch('/api/scenarios').then(r => r.json()).then((data: Scenario[]) => {
      setScenarios(data);
      if (data.length) setScenarioId(data[0].id);
    });
    fetch('/api/locations').then(r => r.json()).then(setLocations);
  }, []);

  const swap = () => { setFromCode(toCode); setToCode(fromCode); };

  const handleSubmit = async () => {
    const scenario = scenarios.find(s => s.id === scenarioId);
    if (!scenario || !fromCode || !toCode) return;

    try {
      // Step 1: compute EFFECTIVE_MOVE
      setStatus('computing');
      const compRes = await fetch('/api/compute-effective-move', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          scenario_id: scenario.id,
          cargo_type: scenario.cargo_type,
          fert_type: scenario.fert_type,
          subsidy_type: scenario.subsidy_type,
          pricing_date: scenario.pricing_date,
        }),
      });
      if (!compRes.ok) throw new Error('Failed to compute effective move');

      // Step 2: find top 3 routes
      setStatus('loading');
      const routeRes = await fetch('/api/optimize-route', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ scenario_id: scenarioId, from_code: fromCode, to_code: toCode }),
      });

      if (routeRes.status === 404) { setStatus('no_route'); return; }
      if (!routeRes.ok) throw new Error('Route optimization failed');

      const data = await routeRes.json();
      setRoutes(data.routes);
      setStatus('done');
    } catch (e) {
      setErrorMsg(String(e));
      setStatus('error');
    }
  };

  const fromName = locations.find(l => l.code === fromCode)?.name ?? fromCode;
  const toName   = locations.find(l => l.code === toCode)?.name ?? toCode;
  const isLoading = status === 'computing' || status === 'loading';

  return (
    <div className="min-h-screen bg-gray-950 text-gray-100 p-6">
      <h1 className="text-2xl font-bold mb-6">Route Optimizer</h1>

      {/* Inputs */}
      <div className="bg-gray-900 rounded-xl p-6 mb-6 flex flex-wrap gap-4 items-end">
        <div className="flex flex-col gap-1">
          <label className="text-sm text-gray-400">Scenario</label>
          <select
            className="bg-gray-800 rounded px-3 py-2 text-sm"
            value={scenarioId}
            onChange={e => setScenarioId(e.target.value)}
          >
            {scenarios.map(s => <option key={s.id} value={s.id}>{s.label}</option>)}
          </select>
        </div>

        <div className="flex flex-col gap-1">
          <label className="text-sm text-gray-400">Origin</label>
          <select
            className="bg-gray-800 rounded px-3 py-2 text-sm"
            value={fromCode}
            onChange={e => setFromCode(e.target.value)}
          >
            <option value="">Select origin</option>
            {locations.map(l => <option key={l.code} value={l.code}>{l.name} ({l.code})</option>)}
          </select>
        </div>

        <button onClick={swap} className="text-gray-400 hover:text-white text-xl pb-1" title="Swap">⇄</button>

        <div className="flex flex-col gap-1">
          <label className="text-sm text-gray-400">Destination</label>
          <select
            className="bg-gray-800 rounded px-3 py-2 text-sm"
            value={toCode}
            onChange={e => setToCode(e.target.value)}
          >
            <option value="">Select destination</option>
            {locations.map(l => <option key={l.code} value={l.code}>{l.name} ({l.code})</option>)}
          </select>
        </div>

        <button
          onClick={handleSubmit}
          disabled={isLoading || !fromCode || !toCode}
          className="bg-blue-600 hover:bg-blue-500 disabled:opacity-40 rounded px-5 py-2 text-sm font-semibold"
        >
          {isLoading ? 'Optimizing…' : 'Find cheapest routes'}
        </button>
      </div>

      {/* Results */}
      <RouteResults
        status={status}
        routes={routes}
        fromName={fromName}
        toName={toName}
        errorMsg={errorMsg}
      />
    </div>
  );
}
