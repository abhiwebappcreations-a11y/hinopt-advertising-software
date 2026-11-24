import React, { useState, useEffect } from 'react';
import { Navbar } from './components/Navbar';
import { CampaignList } from './components/CampaignList';
import { ProofOfPlayAnalytics } from './components/ProofOfPlayAnalytics';
import { NewCampaignModal } from './components/NewCampaignModal';
import {
  Campaign,
  Advertiser,
  ProofOfPlaySummary,
  fetchCampaigns,
  fetchAdvertisers,
  fetchAnalytics
} from './services/api';

export const App: React.FC = () => {
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [advertisers, setAdvertisers] = useState<Advertiser[]>([]);
  const [analytics, setAnalytics] = useState<ProofOfPlaySummary>({
    total_impressions: 0,
    total_seconds_played: 0,
    interrupted_impressions: 0,
    record_count: 0
  });
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [isNewModalOpen, setIsNewModalOpen] = useState(false);

  const loadData = async () => {
    setIsRefreshing(true);
    const [cList, aList, stats] = await Promise.all([
      fetchCampaigns(),
      fetchAdvertisers(),
      fetchAnalytics()
    ]);
    setCampaigns(cList);
    setAdvertisers(aList);
    setAnalytics(stats);
    setIsRefreshing(false);
  };

  useEffect(() => {
    loadData();
  }, []);

  return (
    <div className="min-h-screen bg-slate-950 flex flex-col">
      <Navbar onRefresh={loadData} isRefreshing={isRefreshing} />

      <main className="flex-1 max-w-7xl w-full mx-auto p-6 space-y-6">
        {/* Clean Data Notice */}
        <div className="p-4 rounded-xl bg-blue-500/5 border border-blue-500/20 flex items-start space-x-3">
          <div className="w-2 h-2 rounded-full bg-blue-400 mt-1.5 flex-shrink-0" />
          <p className="text-xs text-blue-200/90 leading-relaxed">
            <strong>Commercial Fleet Operations:</strong> Direct integration with HINOPT edge displays. Zero commission deducted — client agency retains 100% of all commercial advertiser revenue.
          </p>
        </div>

        {/* Proof of Play Audit Telemetry */}
        <ProofOfPlayAnalytics analytics={analytics} />

        {/* Active Advertising Campaigns */}
        <CampaignList
          campaigns={campaigns}
          onOpenNewModal={() => setIsNewModalOpen(true)}
        />
      </main>

      {/* New Campaign Booking Modal */}
      <NewCampaignModal
        isOpen={isNewModalOpen}
        onClose={() => setIsNewModalOpen(false)}
        advertisers={advertisers}
        onSuccess={loadData}
      />
    </div>
  );
};
