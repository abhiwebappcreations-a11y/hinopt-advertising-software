import React, { useState, useEffect } from 'react';
import { Header } from './components/Header';
import { TenantManager } from './components/TenantManager';
import { ScreenFleetTable } from './components/ScreenFleetTable';
import { ScreenPairingModal } from './components/ScreenPairingModal';
import { Tenant, ScreenDevice, fetchTenants, fetchScreens } from './services/api';

export const App: React.FC = () => {
  const [tenants, setTenants] = useState<Tenant[]>([]);
  const [screens, setScreens] = useState<ScreenDevice[]>([]);
  const [selectedTenantId, setSelectedTenantId] = useState<string | null>(null);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [isPairModalOpen, setIsPairModalOpen] = useState(false);

  const loadData = async () => {
    setIsRefreshing(true);
    const [tList, sList] = await Promise.all([
      fetchTenants(),
      fetchScreens(selectedTenantId || undefined)
    ]);
    setTenants(tList);
    setScreens(sList);
    setIsRefreshing(false);
  };

  useEffect(() => {
    loadData();
  }, [selectedTenantId]);

  return (
    <div className="min-h-screen bg-slate-950 flex flex-col">
      <Header onRefresh={loadData} isRefreshing={isRefreshing} />

      <main className="flex-1 max-w-7xl w-full mx-auto p-6 space-y-6">
        {/* Notice on Zero Demo Data */}
        <div className="p-4 rounded-xl bg-amber-500/5 border border-amber-500/20 flex items-start space-x-3">
          <div className="w-2 h-2 rounded-full bg-amber-400 mt-1.5 flex-shrink-0" />
          <p className="text-xs text-amber-200/90 leading-relaxed">
            <strong>Clean Database Mode:</strong> This HINOPT Sovereign Master Instance operates with zero mock or demo data. Only verified commercial tenants (such as Admobitics) and physical screens registered via 6-digit cryptographic pairing will appear.
          </p>
        </div>

        {/* Tenant Management Block */}
        <TenantManager
          tenants={tenants}
          onTenantCreated={loadData}
          selectedTenantId={selectedTenantId}
          onSelectTenant={setSelectedTenantId}
        />

        {/* Screen Fleet Overview */}
        <ScreenFleetTable
          screens={screens}
          onScreenRevoked={loadData}
          onOpenPairModal={() => setIsPairModalOpen(true)}
        />
      </main>

      {/* Screen Enrollment Modal */}
      <ScreenPairingModal
        isOpen={isPairModalOpen}
        onClose={() => setIsPairModalOpen(false)}
        tenants={tenants}
        onSuccess={loadData}
      />
    </div>
  );
};
