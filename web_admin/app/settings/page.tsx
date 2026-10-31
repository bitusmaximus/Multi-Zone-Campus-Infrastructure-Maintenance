'use client';

import { useState } from 'react';
import { Check, Globe2, ShieldCheck } from 'lucide-react';
import { AdminSidebar } from '@/app/components/admin-sidebar';
import { AppTopbar } from '@/app/components/app-topbar';

export default function SettingsPage() {
  const [campusName, setCampusName] = useState('Bahir Dar University');
  const [emailAlerts, setEmailAlerts] = useState(true);
  const [saved, setSaved] = useState(false);

  return (
    <main className="app-shell">
      <AdminSidebar />
      <section className="main-area">
        <AppTopbar title="Workspace settings" />
        <div className="page-content">
          <div className="page-heading"><div><div className="eyebrow">CONFIGURATION <span className="eyebrow-rule" /></div><h1>Workspace settings</h1><p>Manage the basic identity and notification preferences for this dispatch workspace.</p></div></div>
          <section className="settings-layout">
            <div className="settings-panel"><div className="section-title"><h2>Institution profile</h2><span>Shown to dispatchers and campus reporters</span></div><label className="settings-field"><span>Institution name</span><input value={campusName} onChange={(event) => { setCampusName(event.target.value); setSaved(false); }} /></label><div className="settings-readonly"><Globe2 size={17} /><div><strong>Time zone</strong><span>Africa / Addis Ababa</span></div><span className="read-only-tag">System</span></div><div className="settings-readonly"><ShieldCheck size={17} /><div><strong>Access control</strong><span>Role-based permissions enabled</span></div><span className="read-only-tag">Active</span></div></div>
            <div className="settings-panel"><div className="section-title"><h2>Notifications</h2><span>Choose what the workspace should surface</span></div><label className="toggle-row"><span><strong>Email alerts</strong><small>Notify dispatchers when an emergency report is submitted</small></span><input type="checkbox" checked={emailAlerts} onChange={(event) => { setEmailAlerts(event.target.checked); setSaved(false); }} /></label><div className="settings-note">Settings on this demo page are held in browser memory and reset when the page reloads.</div></div>
            <div className="settings-actions"><button className={`assign-button ${saved ? 'saved' : ''}`} onClick={() => { setSaved(true); window.setTimeout(() => setSaved(false), 2200); }}>{saved ? <Check size={15} /> : null}{saved ? 'Preferences saved' : 'Save preferences'}</button></div>
          </section>
        </div>
      </section>
    </main>
  );
}