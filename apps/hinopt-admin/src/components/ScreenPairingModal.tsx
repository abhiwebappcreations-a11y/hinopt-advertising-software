import React, { useState } from 'react';
import { X, Tv, CheckCircle2, AlertCircle } from 'lucide-react';
import { Tenant, preAuthorizeScreen } from '../services/api';

interface ScreenPairingModalProps {
  isOpen: boolean;
  onClose: () => void;
  tenants: Tenant[];
  onSuccess: () => void;
}

export const ScreenPairingModal: React.FC<ScreenPairingModalProps> = ({
  isOpen,
  onClose,
  tenants,
  onSuccess
}) => {
  const [activationCode, setActivationCode] = useState('');
  const [tenantId, setTenantId] = useState(tenants[0]?.id || '');
  const [screenName, setScreenName] = useState('');
  const [licenseTier, setLicenseTier] = useState('PRO');
  const [durationDays, setDurationDays] = useState(730); // 2 years default
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!activationCode || !tenantId || !screenName) {
      setError('Please fill in all required fields.');
      return;
    }

    setLoading(true);
    setError(null);

    const success = await preAuthorizeScreen({
      activation_code: activationCode.trim().toUpperCase(),
      tenant_id: tenantId,
      screen_name: screenName.trim(),
      license_tier: licenseTier,
      duration_days: durationDays
    });

    setLoading(false);

    if (success) {
      onSuccess();
      onClose();
    } else {
      setError('Failed to pre-authorize screen. Verify code and tenant quota.');
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm">
      <div className="bg-slate-900 border border-slate-800 rounded-2xl w-full max-w-md overflow-hidden shadow-2xl">
        <div className="flex items-center justify-between p-6 border-b border-slate-800">
          <div className="flex items-center space-x-3">
            <div className="p-2 bg-amber-500/10 rounded-lg text-amber-400">
              <Tv className="w-5 h-5" />
            </div>
            <h3 className="font-semibold text-lg text-white">Enroll New Display Screen</h3>
          </div>
          <button onClick={onClose} className="text-slate-400 hover:text-white transition">
            <X className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          {error && (
            <div className="p-3 bg-rose-500/10 border border-rose-500/30 rounded-lg flex items-center space-x-2 text-rose-400 text-xs">
              <AlertCircle className="w-4 h-4 flex-shrink-0" />
              <span>{error}</span>
            </div>
          )}

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              6-Digit Activation Code (From Screen Display)
            </label>
            <input
              type="text"
              maxLength={6}
              value={activationCode}
              onChange={(e) => setActivationCode(e.target.value.toUpperCase())}
              placeholder="e.g. A9X4B2"
              className="w-full bg-slate-800 border border-slate-700 rounded-xl px-4 py-2.5 text-center text-xl font-mono tracking-widest text-amber-400 focus:outline-none focus:border-amber-500"
              required
            />
          </div>

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">Assign to Tenant</label>
            <select
              value={tenantId}
              onChange={(e) => setTenantId(e.target.value)}
              className="w-full bg-slate-800 border border-slate-700 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-amber-500"
              required
            >
              {tenants.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name} (Max: {t.max_screens} screens)
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">Screen Designation / Vehicle ID</label>
            <input
              type="text"
              value={screenName}
              onChange={(e) => setScreenName(e.target.value)}
              placeholder="e.g. Auto-Rickshaw #04 (HITEC City)"
              className="w-full bg-slate-800 border border-slate-700 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-amber-500"
              required
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-slate-300 mb-1.5">License Tier</label>
              <select
                value={licenseTier}
                onChange={(e) => setLicenseTier(e.target.value)}
                className="w-full bg-slate-800 border border-slate-700 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-amber-500"
              >
                <option value="CORE">CORE (Standard)</option>
                <option value="PRO">PRO (Automotive Kiosk)</option>
                <option value="ENTERPRISE">ENTERPRISE</option>
              </select>
            </div>
            <div>
              <label className="block text-xs font-medium text-slate-300 mb-1.5">Validity Duration</label>
              <select
                value={durationDays}
                onChange={(e) => setDurationDays(Number(e.target.value))}
                className="w-full bg-slate-800 border border-slate-700 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-amber-500"
              >
                <option value={730}>2 Years (₹0 Free Pilot)</option>
                <option value={365}>1 Year</option>
                <option value={90}>90 Days</option>
              </select>
            </div>
          </div>

          <div className="pt-4 flex items-center justify-end space-x-3">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-sm text-slate-400 hover:text-white transition"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={loading}
              className="px-5 py-2 rounded-xl bg-amber-500 hover:bg-amber-600 text-slate-950 font-semibold text-sm transition shadow-lg shadow-amber-500/20 disabled:opacity-50"
            >
              {loading ? 'Authorizing...' : 'Authorize & Issue License'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
