'use client';

import { useMemo, useState } from 'react';
import { Building2, MapPin, Search } from 'lucide-react';
import { AdminSidebar } from '@/app/components/admin-sidebar';
import { AppTopbar } from '@/app/components/app-topbar';

const zones = [
  { campus: 'Poly / BIT Campus', category: 'Dorms', building: 'Block C', rooms: 42, open: 4 },
  { campus: 'Poly / BIT Campus', category: 'Classrooms', building: 'Building 4', rooms: 28, open: 3 },
  { campus: 'Pedagogy Main Campus', category: 'Labs', building: 'Engineering Lab 2', rooms: 12, open: 2 },
  { campus: 'Pedagogy Main Campus', category: 'Grounds', building: 'East walkway', rooms: 8, open: 1 },
  { campus: 'Kebele 09 Health Science', category: 'Classrooms', building: 'Library Annex', rooms: 19, open: 0 },
];
const categories = ['All zones', 'Dorms', 'Classrooms', 'Labs', 'Grounds'];

export default function ZonesPage() {
  const [query, setQuery] = useState('');
  const [category, setCategory] = useState('All zones');
  const visibleZones = useMemo(() => zones.filter((zone) => {
    const matchesCategory = category === 'All zones' || zone.category === category;
    const matchesQuery = !query || `${zone.campus} ${zone.category} ${zone.building}`.toLowerCase().includes(query.toLowerCase());
    return matchesCategory && matchesQuery;
  }), [query, category]);
  const campusCount = new Set(zones.map((zone) => zone.campus)).size;
  const openCount = zones.reduce((total, zone) => total + zone.open, 0);

  return (
    <main className="app-shell">
      <AdminSidebar />
      <section className="main-area">
        <AppTopbar title="Campus zones" />
        <div className="page-content">
          <div className="page-heading"><div><div className="eyebrow">LOCATION DIRECTORY <span className="eyebrow-rule" /></div><h1>Campus zones</h1><p>Browse registered buildings and see where repair work is concentrated.</p></div><span className="directory-count"><MapPin size={15} /> {zones.length} registered zones</span></div>
          <section className="metrics zone-metrics" aria-label="Zone summary">
            <div className="metric"><div className="metric-top"><span>Campuses covered</span><span className="metric-icon olive"><Building2 size={16} /></span></div><strong>{String(campusCount).padStart(2, '0')}</strong><span className="metric-note">Across the institution</span></div>
            <div className="metric"><div className="metric-top"><span>Registered locations</span><span className="metric-icon blue"><MapPin size={16} /></span></div><strong>{String(zones.length).padStart(2, '0')}</strong><span className="metric-note">Buildings and grounds areas</span></div>
            <div className="metric"><div className="metric-top"><span>Open requests</span><span className="metric-icon red"><Building2 size={16} /></span></div><strong>{String(openCount).padStart(2, '0')}</strong><span className="metric-note">Across listed zones</span></div>
          </section>
          <section className="directory-panel">
            <div className="directory-toolbar"><div className="section-title"><h2>Location directory</h2><span>{visibleZones.length} locations shown</span></div><label className="search-box"><Search size={16} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search buildings" aria-label="Search buildings" /></label></div>
            <div className="category-tabs" role="tablist" aria-label="Filter by zone category">{categories.map((item) => <button key={item} role="tab" aria-selected={category === item} className={category === item ? 'filter-tab selected' : 'filter-tab'} onClick={() => setCategory(item)}>{item}</button>)}</div>
            <div className="zone-grid">{visibleZones.length === 0 ? <div className="empty-state">No zones match this search.</div> : visibleZones.map((zone) => <article className="zone-card" key={`${zone.campus}-${zone.building}`}>
              <div className="zone-card-top"><span className="zone-icon"><Building2 size={17} /></span><span className={`category-tag category-${zone.category.toLowerCase()}`}>{zone.category}</span></div>
              <span className="zone-campus">{zone.campus}</span><h3>{zone.building}</h3>
              <div className="zone-card-footer"><span>{zone.rooms} rooms / areas</span><span className={zone.open ? 'zone-open' : 'zone-clear'}>{zone.open ? `${zone.open} open requests` : 'No open requests'}</span></div>
            </article>)}</div>
          </section>
        </div>
      </section>
    </main>
  );
}