import React, { useState } from 'react';
import { Users, Plus, ShieldCheck } from 'lucide-react';
import { Tenant, createTenant } from '../services/api';

interface TenantManagerProps {
  tenants: Tenant[];
  onTenantCreated: () => void;
  selectedTenantId: string | null;
  onSelectTenant: (id: string | null) => void;
}

export const TenantManager: React.FC<TenantManagerProps> = ({
  tenants,
  onTenantCreated,
  selectedTenantId,
  onSelectTenant
}) => {
  const [isAdding, setIsAdding] = useState(false);
  const [name, setName] = useState('');
  const [contactEmail, setContactEmail] = useState('');
  const [maxScreens, setMaxScreens] = useState(10);
  const [loading, setLoading] = useState(false);

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name || !contactEmail) return;

    setLoading(true);
    const created = await createTenant({
      name,
      contact_email: contactEmail,
      max_screens: maxScreens
    });
    setLoading(false);

    if (created) {
      setName('');
      setContactEmail('');
      setIsAdding(false);
      onTenantCreated();
    }
  };

  return (
    <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center space-x-3">
          <div className="p-2 bg-blue-500/10 rounded-lg text-blue-400">
            <Users className="w-5 h-5" />
          </div>
          <div>
            <h2 className="font-semibold text-white">Commercial Tenants</h2>
            <p className="text-xs text-slate-400">Registered advertising agencies &amp; client networks</p>
          </div>
        </div>

        <button
          onClick={() => setIsAdding(!isAdding)}
          className="flex items-center space-x-1.5 text-xs font-medium px-3 py-1.5 rounded-lg bg-blue-600 hover:bg-blue-500 text-white transition"
        >
          <Plus className="w-3.5 h-3.5" />
          <span>New Tenant</span>
        </button>
      </div>

      {isAdding && (
        <form onSubmit={handleCreate} className="mb-4 p-4 bg-slate-800/60 rounded-xl border border-slate-700/50 space-y-3">
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <input
              type="text"
              placeholder="Company Name (e.g. Admobitics)"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="bg-slate-800 border border-slate-700 rounded-lg px-3 py-1.5 text-xs text-white"
              required
            />
            <input
              type="email"
              placeholder="Contact Email"
              value={contactEmail}
              onChange={(e) => setContactEmail(e.target.value)}
              className="bg-slate-800 border border-slate-700 rounded-lg px-3 py-1.5 text-xs text-white"
              required
            />
            <input
              type="number"
              placeholder="Screen Quota"
              value={maxScreens}
              onChange={(e) => setMaxScreens(Number(e.target.value))}
              className="bg-slate-800 border border-slate-700 rounded-lg px-3 py-1.5 text-xs text-white"
              min={1}
              required
            />
          </div>
          <div className="flex justify-end space-x-2">
            <button
              type="button"
              onClick={() => setIsAdding(false)}
              className="px-3 py-1 text-xs text-slate-400 hover:text-white"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={loading}
              className="px-4 py-1 text-xs bg-blue-600 hover:bg-blue-500 text-white rounded-lg font-medium"
            >
              {loading ? 'Creating...' : 'Register Tenant'}
            </button>
          </div>
        </form>
      )}

      {tenants.length === 0 ? (
        <div className="text-center py-6 border border-dashed border-slate-800 rounded-xl text-slate-500 text-xs">
          Zero commercial tenants registered. (Enforcing clean database start)
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3">
          <div
            onClick={() => onSelectTenant(null)}
            className={`p-3.5 rounded-xl border cursor-pointer transition ${
              selectedTenantId === null
                ? 'bg-amber-500/10 border-amber-500/40 text-amber-300'
                : 'bg-slate-800/40 border-slate-800 text-slate-400 hover:border-slate-700'
            }`}
          >
            <div className="text-xs font-semibold text-white">All Fleets Combined</div>
            <div className="text-[11px] text-slate-400 mt-0.5">Aggregate view across all tenants</div>
          </div>

          {tenants.map((t) => (
            <div
              key={t.id}
              onClick={() => onSelectTenant(t.id)}
              className={`p-3.5 rounded-xl border cursor-pointer transition ${
                selectedTenantId === t.id
                  ? 'bg-amber-500/10 border-amber-500/40 text-amber-300'
                  : 'bg-slate-800/40 border-slate-800 text-slate-300 hover:border-slate-700'
              }`}
            >
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold text-white">{t.name}</span>
                <span className="text-[10px] px-1.5 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                  {t.status}
                </span>
              </div>
              <div className="text-[11px] text-slate-400 mt-1">{t.contact_email}</div>
              <div className="text-[10px] text-slate-500 mt-1">Quota: {t.max_screens} screens authorized</div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};
