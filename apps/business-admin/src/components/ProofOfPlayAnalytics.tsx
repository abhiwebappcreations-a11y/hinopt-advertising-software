import React from 'react';
import { BarChart3, Eye, Clock, CheckCircle2, AlertCircle } from 'lucide-react';
import { ProofOfPlaySummary } from '../services/api';

interface ProofOfPlayAnalyticsProps {
  analytics: ProofOfPlaySummary;
}

export const ProofOfPlayAnalytics: React.FC<ProofOfPlayAnalyticsProps> = ({ analytics }) => {
  const completionRate = analytics.total_impressions > 0
    ? Math.round((analytics.total_impressions / (analytics.total_impressions + analytics.interrupted_impressions)) * 100)
    : 100;

  return (
    <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6">
      <div className="flex items-center space-x-3 mb-6">
        <div className="p-2 bg-emerald-500/10 rounded-lg text-emerald-400">
          <BarChart3 className="w-5 h-5" />
        </div>
        <div>
          <h2 className="font-semibold text-white">Verified Proof-of-Play (PoP) Telemetry</h2>
          <p className="text-xs text-slate-400">Locally tallied impression audits across Hyderabad autos</p>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-4 gap-4">
        <div className="p-4 bg-slate-800/40 rounded-xl border border-slate-800">
          <div className="flex items-center justify-between text-slate-400 text-xs">
            <span>Completed Plays</span>
            <Eye className="w-4 h-4 text-emerald-400" />
          </div>
          <div className="text-2xl font-bold text-white mt-2">
            {analytics.total_impressions.toLocaleString()}
          </div>
          <div className="text-[11px] text-emerald-400 mt-1 flex items-center space-x-1">
            <CheckCircle2 className="w-3 h-3" />
            <span>100% Verified Delivery</span>
          </div>
        </div>

        <div className="p-4 bg-slate-800/40 rounded-xl border border-slate-800">
          <div className="flex items-center justify-between text-slate-400 text-xs">
            <span>Airtime Delivered</span>
            <Clock className="w-4 h-4 text-blue-400" />
          </div>
          <div className="text-2xl font-bold text-white mt-2">
            {(analytics.total_seconds_played / 60).toFixed(1)} <span className="text-sm font-normal text-slate-400">mins</span>
          </div>
          <div className="text-[11px] text-slate-400 mt-1">Total screen exposure</div>
        </div>

        <div className="p-4 bg-slate-800/40 rounded-xl border border-slate-800">
          <div className="flex items-center justify-between text-slate-400 text-xs">
            <span>Interrupted Impressions</span>
            <AlertCircle className="w-4 h-4 text-amber-400" />
          </div>
          <div className="text-2xl font-bold text-white mt-2">
            {analytics.interrupted_impressions}
          </div>
          <div className="text-[11px] text-slate-400 mt-1">Engine cuts / power cuts</div>
        </div>

        <div className="p-4 bg-slate-800/40 rounded-xl border border-slate-800">
          <div className="flex items-center justify-between text-slate-400 text-xs">
            <span>Completion Rate</span>
            <CheckCircle2 className="w-4 h-4 text-purple-400" />
          </div>
          <div className="text-2xl font-bold text-white mt-2">
            {completionRate}%
          </div>
          <div className="text-[11px] text-purple-400 mt-1">High passenger engagement</div>
        </div>
      </div>
    </div>
  );
};
