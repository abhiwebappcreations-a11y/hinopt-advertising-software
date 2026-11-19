import React from 'react';
import { Tv, Battery, Cpu, HardDrive, Wifi, AlertTriangle, Trash2 } from 'lucide-react';
import { ScreenDevice, revokeScreen } from '../services/api';

interface ScreenFleetTableProps {
  screens: ScreenDevice[];
  onScreenRevoked: () => void;
  onOpenPairModal: () => void;
}

export const ScreenFleetTable: React.FC<ScreenFleetTableProps> = ({
  screens,
  onScreenRevoked,
  onOpenPairModal
}) => {
  const handleRevoke = async (id: string, name: string) => {
    if (confirm(`Are you sure you want to revoke the license for "${name}"? Playback will immediately halt.`)) {
      const ok = await revokeScreen(id);
      if (ok) onScreenRevoked();
    }
  };

  return (
    <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center space-x-3">
          <div className="p-2 bg-amber-500/10 rounded-lg text-amber-400">
            <Tv className="w-5 h-5" />
          </div>
          <div>
            <h2 className="font-semibold text-white">Edge Display Fleet</h2>
            <p className="text-xs text-slate-400">TPC 151TCT digital signage panels &amp; live telemetry</p>
          </div>
        </div>

        <button
          onClick={onOpenPairModal}
          className="flex items-center space-x-1.5 text-xs font-semibold px-4 py-2 rounded-xl bg-amber-500 hover:bg-amber-600 text-slate-950 transition shadow-lg shadow-amber-500/20"
        >
          <span>+ Enroll Screen</span>
        </button>
      </div>

      {screens.length === 0 ? (
        <div className="text-center py-12 border border-dashed border-slate-800 rounded-xl text-slate-500 space-y-2">
          <Tv className="w-8 h-8 mx-auto text-slate-600 mb-2" />
          <p className="text-sm font-medium text-slate-400">Zero Display Screens Enrolled</p>
          <p className="text-xs text-slate-500 max-w-sm mx-auto">
            The system starts 100% clean with no demo screens. Turn on a physical screen, get its 6-digit code, and click "Enroll Screen".
          </p>
        </div>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-slate-800 text-slate-400 font-medium">
                <th className="pb-3 pl-2">Screen Name &amp; ID</th>
                <th className="pb-3">Status</th>
                <th className="pb-3">Hardware</th>
                <th className="pb-3">Telemetry</th>
                <th className="pb-3">License Tier</th>
                <th className="pb-3">Expiry</th>
                <th className="pb-3 text-right pr-2">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60">
              {screens.map((s) => {
                const isOnline = s.last_heartbeat_at && (Date.now() - new Date(s.last_heartbeat_at).getTime()) < 600000;
                return (
                  <tr key={s.id} className="hover:bg-slate-800/30 transition">
                    <td className="py-3.5 pl-2">
                      <div className="font-semibold text-white">{s.screen_name}</div>
                      <div className="text-[10px] font-mono text-slate-500 mt-0.5">{s.id.substring(0, 18)}...</div>
                    </td>
                    <td className="py-3.5">
                      {s.enrollment_status === 'ACTIVE' ? (
                        <span className={`inline-flex items-center space-x-1.5 px-2 py-0.5 rounded-full text-[11px] font-medium ${
                          isOnline ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'bg-slate-800 text-slate-400 border border-slate-700'
                        }`}>
                          <span className={`w-1.5 h-1.5 rounded-full ${isOnline ? 'bg-emerald-400 animate-pulse' : 'bg-slate-500'}`} />
                          <span>{isOnline ? 'ONLINE' : 'OFFLINE'}</span>
                        </span>
                      ) : s.enrollment_status === 'PRE_AUTHORIZED' ? (
                        <span className="px-2 py-0.5 rounded-full text-[11px] font-medium bg-amber-500/10 text-amber-400 border border-amber-500/20">
                          AWAITING ACTIVATION ({s.activation_code})
                        </span>
                      ) : (
                        <span className="px-2 py-0.5 rounded-full text-[11px] font-medium bg-rose-500/10 text-rose-400 border border-rose-500/20">
                          REVOKED
                        </span>
                      )}
                    </td>
                    <td className="py-3.5">
                      <div className="text-slate-300 font-medium">{s.hardware_model}</div>
                      <div className="text-[10px] text-slate-500">SN: {s.serial_number}</div>
                    </td>
                    <td className="py-3.5">
                      <div className="flex items-center space-x-3 text-[11px] text-slate-400">
                        {s.battery_level_percent !== undefined && (
                          <span className="flex items-center space-x-1">
                            <Battery className="w-3.5 h-3.5 text-slate-400" />
                            <span>{s.battery_level_percent}%</span>
                          </span>
                        )}
                        {s.soc_temperature_celsius !== undefined && (
                          <span className="flex items-center space-x-1">
                            <Cpu className="w-3.5 h-3.5 text-slate-400" />
                            <span>{s.soc_temperature_celsius}°C</span>
                          </span>
                        )}
                      </div>
                    </td>
                    <td className="py-3.5">
                      <span className="px-2 py-0.5 rounded bg-slate-800 text-slate-300 font-mono text-[11px] border border-slate-700">
                        {s.license_tier}
                      </span>
                    </td>
                    <td className="py-3.5 text-slate-400 text-[11px]">
                      {new Date(s.license_expires_at).toLocaleDateString()}
                    </td>
                    <td className="py-3.5 text-right pr-2">
                      {s.enrollment_status !== 'REVOKED' && (
                        <button
                          onClick={() => handleRevoke(s.id, s.screen_name)}
                          className="p-1.5 rounded-lg text-slate-500 hover:text-rose-400 hover:bg-rose-500/10 transition"
                          title="Revoke License"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};
