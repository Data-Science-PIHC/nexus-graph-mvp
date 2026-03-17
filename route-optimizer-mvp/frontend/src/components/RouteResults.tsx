interface RouteLeg {
  leg_id: string; cost_per_ton: number;
  origin_cost_per_ton: number; leg_cost_per_ton: number; destination_cost_per_ton: number;
}
interface RouteNode { code: string; name: string; type: string; }
interface Route { rank: number; path_cost: number; nodes: RouteNode[]; legs: RouteLeg[]; }

interface Props {
  status: 'idle' | 'computing' | 'loading' | 'done' | 'no_route' | 'error';
  routes: Route[];
  fromName: string;
  toName: string;
  errorMsg: string;
}

const fmt = (n: number) => n?.toLocaleString('id-ID') ?? '-';

export default function RouteResults({ status, routes, fromName, toName, errorMsg }: Props) {
  if (status === 'idle') return (
    <p className="text-gray-500 text-sm">Select a scenario and origin–destination pair, then click "Find cheapest routes".</p>
  );

  if (status === 'computing') return (
    <div className="text-gray-400 text-sm flex items-center gap-2">
      <span className="animate-spin">⟳</span> Computing pricing…
    </div>
  );

  if (status === 'loading') return (
    <div className="text-gray-400 text-sm flex items-center gap-2">
      <span className="animate-spin">⟳</span> Optimizing route…
    </div>
  );

  if (status === 'no_route') return (
    <p className="text-yellow-400 text-sm">No valid route found for this origin, destination, and scenario.</p>
  );

  if (status === 'error') return (
    <p className="text-red-400 text-sm">Something went wrong: {errorMsg}</p>
  );

  return (
    <div>
      <p className="text-sm text-gray-400 mb-4">
        Showing top {routes.length} cheapest routes from <span className="text-white">{fromName}</span> to <span className="text-white">{toName}</span>
      </p>
      <div className="flex flex-col gap-4">
        {routes.map(route => (
          <div key={route.rank} className="bg-gray-900 rounded-xl p-5">
            <div className="flex justify-between items-center mb-3">
              <span className="font-semibold">Route {route.rank}</span>
              <span className="text-blue-400 font-mono text-sm">IDR {fmt(route.path_cost)} / ton</span>
            </div>

            {/* Node path pills */}
            <div className="flex flex-wrap items-center gap-1 mb-4">
              {route.nodes.map((n, i) => (
                <span key={i} className="flex items-center gap-1">
                  <span className="bg-gray-700 rounded px-2 py-0.5 text-xs">{n.code}</span>
                  {i < route.nodes.length - 1 && <span className="text-gray-500">→</span>}
                </span>
              ))}
            </div>

            {/* Leg breakdown */}
            <table className="w-full text-xs text-gray-300">
              <thead>
                <tr className="text-gray-500 border-b border-gray-800">
                  <th className="text-left py-1">Leg ID</th>
                  <th className="text-right py-1">Origin</th>
                  <th className="text-right py-1">Leg</th>
                  <th className="text-right py-1">Destination</th>
                  <th className="text-right py-1">Total / ton</th>
                </tr>
              </thead>
              <tbody>
                {route.legs.map((leg, i) => (
                  <tr key={i} className="border-b border-gray-800">
                    <td className="py-1 font-mono">{leg.leg_id}</td>
                    <td className="text-right py-1">{fmt(leg.origin_cost_per_ton)}</td>
                    <td className="text-right py-1">{fmt(leg.leg_cost_per_ton)}</td>
                    <td className="text-right py-1">{fmt(leg.destination_cost_per_ton)}</td>
                    <td className="text-right py-1 text-white">{fmt(leg.cost_per_ton)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ))}
      </div>
    </div>
  );
}
