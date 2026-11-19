import React from 'react';
import { Megaphone, Calendar, Film, Plus } from 'lucide-react';
import { Campaign } from '../services/api';

interface CampaignListProps {
  campaigns: Campaign[];
  onOpenNewModal: () => void;
}

export const CampaignList: React.FC<CampaignListProps> = ({ campaigns, onOpenNewModal }) => {
  return (
    <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center space-x-3">
          <div className="p-2 bg-blue-500/10 rounded-lg text-blue-400">
            <Megaphone className="w-5 h-5" />
          </div>
          <div>
            <h2 className="font-semibold text-white">Commercial Advertising Campaigns</h2>
            <p className="text-xs text-slate-400">Scheduled video ads and companion loops across auto screens</p>
          </div>
        </div>

        <button
          onClick={onOpenNewModal}
          className="flex items-center space-x-1.5 text-xs font-semibold px-4 py-2 rounded-xl bg-blue-600 hover:bg-blue-500 text-white transition shadow-lg shadow-blue-600/20"
        >
          <Plus className="w-4 h-4" />
          <span>+ Book Campaign</span>
        </button>
      </div>

      {campaigns.length === 0 ? (
        <div className="text-center py-12 border border-dashed border-slate-800 rounded-xl text-slate-500 space-y-2">
          <Megaphone className="w-8 h-8 mx-auto text-slate-600 mb-2" />
          <p className="text-sm font-medium text-slate-400">Zero Active Commercial Campaigns</p>
          <p className="text-xs text-slate-500 max-w-sm mx-auto">
            Clean database mode. Click "+ Book Campaign" to schedule local Hyderabad advertisers or companion brand creatives.
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          {campaigns.map((c) => (
            <div
              key={c.id}
              className="p-4 bg-slate-800/40 rounded-xl border border-slate-800 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4"
            >
              <div>
                <div className="flex items-center space-x-2">
                  <h3 className="text-sm font-semibold text-white">{c.name}</h3>
                  <span className="text-[10px] px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-medium">
                    {c.status}
                  </span>
                  {c.share_of_voice_percent && (
                    <span className="text-[10px] px-2 py-0.5 rounded bg-slate-800 text-slate-400 border border-slate-700">
                      SOV: {c.share_of_voice_percent}%
                    </span>
                  )}
                </div>
                <div className="flex items-center space-x-4 mt-2 text-xs text-slate-400">
                  <span className="flex items-center space-x-1">
                    <Calendar className="w-3.5 h-3.5 text-slate-500" />
                    <span>Flight: {new Date(c.flight_start_date).toLocaleDateString()} – {new Date(c.flight_end_date).toLocaleDateString()}</span>
                  </span>
                  <span className="flex items-center space-x-1">
                    <Film className="w-3.5 h-3.5 text-slate-500" />
                    <span>{c.assets?.length || 0} Creative Asset(s) attached</span>
                  </span>
                </div>
              </div>

              <div className="text-right">
                <span className="text-xs text-blue-400 font-medium bg-blue-500/10 px-3 py-1.5 rounded-lg border border-blue-500/20">
                  Direct Revenue: 100% Retained
                </span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};
