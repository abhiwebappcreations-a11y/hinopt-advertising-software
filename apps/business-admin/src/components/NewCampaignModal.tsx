import React, { useState } from 'react';
import { X, Megaphone, Upload, Film, AlertCircle } from 'lucide-react';
import { Advertiser, createCampaign, createAdvertiser, MediaAsset } from '../services/api';

interface NewCampaignModalProps {
  isOpen: boolean;
  onClose: () => void;
  advertisers: Advertiser[];
  onSuccess: () => void;
}

export const NewCampaignModal: React.FC<NewCampaignModalProps> = ({
  isOpen,
  onClose,
  advertisers,
  onSuccess
}) => {
  const [name, setName] = useState('');
  const [advertiserId, setAdvertiserId] = useState(advertisers[0]?.id || '');
  const [newAdvName, setNewAdvName] = useState('');
  const [newAdvEmail, setNewAdvEmail] = useState('');
  const [isNewAdv, setIsNewAdv] = useState(advertisers.length === 0);
  const [flightStart, setFlightStart] = useState('2026-11-20');
  const [flightEnd, setFlightEnd] = useState('2026-12-20');
  const [sov, setSov] = useState(25);
  const [creativeName, setCreativeName] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    let targetAdvId = advertiserId;

    if (isNewAdv) {
      if (!newAdvName || !newAdvEmail) {
        setError('Please enter advertiser business name and email.');
        setLoading(false);
        return;
      }
      const adv = await createAdvertiser({ name: newAdvName, contact_email: newAdvEmail });
      if (!adv) {
        setError('Failed to create advertiser.');
        setLoading(false);
        return;
      }
      targetAdvId = adv.id;
    }

    const assets: MediaAsset[] = [];
    if (creativeName.trim()) {
      assets.push({
        id: crypto.randomUUID(),
        campaign_id: 'pending',
        name: creativeName.trim(),
        media_type: 'VIDEO_MP4',
        file_size_bytes: 18500000,
        duration_seconds: 15,
        sha256_checksum: 'a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e',
        storage_url: `https://cdn.hinopt.com/media/${creativeName.trim()}`
      });
    }

    const camp = await createCampaign({
      advertiser_id: targetAdvId,
      name,
      flight_start_date: new Date(flightStart).toISOString(),
      flight_end_date: new Date(flightEnd).toISOString(),
      share_of_voice_percent: sov,
      assets
    });

    setLoading(false);
    if (camp) {
      onSuccess();
      onClose();
    } else {
      setError('Failed to create campaign. Verify dates and connection.');
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm">
      <div className="bg-slate-900 border border-slate-800 rounded-2xl w-full max-w-lg overflow-hidden shadow-2xl">
        <div className="flex items-center justify-between p-6 border-b border-slate-800">
          <div className="flex items-center space-x-3">
            <div className="p-2 bg-blue-500/10 rounded-lg text-blue-400">
              <Megaphone className="w-5 h-5" />
            </div>
            <h3 className="font-semibold text-lg text-white">Book In-Auto Advertising Campaign</h3>
          </div>
          <button onClick={onClose} className="text-slate-400 hover:text-white transition">
            <X className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-4 max-h-[80vh] overflow-y-auto">
          {error && (
            <div className="p-3 bg-rose-500/10 border border-rose-500/30 rounded-lg flex items-center space-x-2 text-rose-400 text-xs">
              <AlertCircle className="w-4 h-4 flex-shrink-0" />
              <span>{error}</span>
            </div>
          )}

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">Campaign Name</label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. Hyderabad Mega Tech Fest 2026"
              className="w-full bg-slate-800 border border-slate-700 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-blue-500"
              required
            />
          </div>

          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label className="text-xs font-medium text-slate-300">Advertiser Client</label>
              {advertisers.length > 0 && (
                <button
                  type="button"
                  onClick={() => setIsNewAdv(!isNewAdv)}
                  className="text-[11px] text-blue-400 hover:underline"
                >
                  {isNewAdv ? 'Select Existing' : '+ New Advertiser'}
                </button>
              )}
            </div>

            {isNewAdv ? (
              <div className="grid grid-cols-2 gap-2">
                <input
                  type="text"
                  placeholder="Business Name"
                  value={newAdvName}
                  onChange={(e) => setNewAdvName(e.target.value)}
                  className="bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-xs text-white"
                  required
                />
                <input
                  type="email"
                  placeholder="Billing Email"
                  value={newAdvEmail}
                  onChange={(e) => setNewAdvEmail(e.target.value)}
                  className="bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-xs text-white"
                  required
                />
              </div>
            ) : (
              <select
                value={advertiserId}
                onChange={(e) => setAdvertiserId(e.target.value)}
                className="w-full bg-slate-800 border border-slate-700 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-blue-500"
              >
                {advertisers.map((a) => (
                  <option key={a.id} value={a.id}>
                    {a.name} ({a.contact_email})
                  </option>
                ))}
              </select>
            )}
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-slate-300 mb-1.5">Flight Start Date</label>
              <input
                type="date"
                value={flightStart}
                onChange={(e) => setFlightStart(e.target.value)}
                className="w-full bg-slate-800 border border-slate-700 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-blue-500"
                required
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-slate-300 mb-1.5">Flight End Date</label>
              <input
                type="date"
                value={flightEnd}
                onChange={(e) => setFlightEnd(e.target.value)}
                className="w-full bg-slate-800 border border-slate-700 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-blue-500"
                required
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5">
              Target Share of Voice (SOV): <strong className="text-blue-400">{sov}%</strong> of 2-minute loop
            </label>
            <input
              type="range"
              min={10}
              max={100}
              step={5}
              value={sov}
              onChange={(e) => setSov(Number(e.target.value))}
              className="w-full accent-blue-500"
            />
          </div>

          <div className="p-4 bg-slate-800/40 border border-slate-800 rounded-xl">
            <div className="flex items-center space-x-2 text-xs font-medium text-slate-300 mb-2">
              <Film className="w-4 h-4 text-blue-400" />
              <span>Attach Commercial Video Creative (1080p MP4)</span>
            </div>
            <input
              type="text"
              placeholder="e.g. Hyderabad_Promo_1080p_15s.mp4"
              value={creativeName}
              onChange={(e) => setCreativeName(e.target.value)}
              className="w-full bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-xs text-white"
            />
            <p className="text-[10px] text-slate-500 mt-1">
              Automatically pre-signed to Cloudflare R2 and assigned a 3-day retention policy after campaign end date.
            </p>
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
              className="px-5 py-2 rounded-xl bg-blue-600 hover:bg-blue-500 text-white font-semibold text-sm transition shadow-lg shadow-blue-600/20 disabled:opacity-50"
            >
              {loading ? 'Compiling Campaign...' : 'Publish to Auto Fleet'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
