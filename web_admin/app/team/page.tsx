'use client';

import { useMemo, useState } from 'react';
import { Check, Search, Wrench } from 'lucide-react';
import { AdminSidebar } from '@/app/components/admin-sidebar';
import { AppTopbar } from '@/app/components/app-topbar';

const technicians = [
  { name: 'Mekdes Tadesse', trade: 'Electrical', campus: 'Poly / BIT Campus', assigned: 3, status: 'On duty', initials: 'MT' },
  { name: 'Abel Bekele', trade: 'Carpentry', campus: 'Poly / BIT Campus', assigned: 2, status: 'On duty', initials: 'AB' },
  { name: 'Sara Alemu', trade: 'General maintenance', campus: 'Kebele 09 Health Science', assigned: 1, status: 'On duty', initials: 'SA' },
  { name: 'Dawit Fikru', trade: 'Plumbing', campus: 'Pedagogy Main Campus', assigned: 0, status: 'Available', initials: 'DF' },
];

export default function TeamPage() {
  const [query, setQuery] = useState('');
  const visibleTechnicians = useMemo(() => technicians.filter((person) => `${person.name} ${person.trade} ${person.campus}`.toLowerCase().includes(query.toLowerCase())), [query]);
  const activeCount = technicians.filter((person) => person.status === 'On duty').length;
  const assignmentCount = technicians.reduce((total, person) => total + person.assigned, 0);

  return (
    <main className="app-shell">
      <AdminSidebar />
      <section className="main-area">
        <AppTopbar title="Maintenance team" />
        <div className="page-content">
          <div className="page-heading"><div><div className="eyebrow">FIELD OPERATIONS <span className="eyebrow-rule" /></div><h1>Maintenance team</h1><p>Review technician coverage and current dispatch workload.</p></div><span className="directory-count"><Wrench size={15} /> {technicians.length} technicians</span></div>
          <section className="metrics team-metrics" aria-label="Team summary">
            <div className="metric"><div className="metric-top"><span>On duty</span><span className="metric-icon green"><Check size={16} /></span></div><strong>{String(activeCount).padStart(2, '0')}</strong><span className="metric-note">Available for campus dispatch</span></div>
            <div className="metric"><div className="metric-top"><span>Assigned work</span><span className="metric-icon blue"><Wrench size={16} /></span></div><strong>{String(assignmentCount).padStart(2, '0')}</strong><span className="metric-note">Active technician tasks</span></div>
            <div className="metric"><div className="metric-top"><span>Available</span><span className="metric-icon olive"><Check size={16} /></span></div><strong>{String(technicians.length - activeCount).padStart(2, '0')}</strong><span className="metric-note">Ready for a new assignment</span></div>
          </section>
          <section className="directory-panel">
            <div className="directory-toolbar"><div className="section-title"><h2>Technician roster</h2><span>{visibleTechnicians.length} team members</span></div><label className="search-box"><Search size={16} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search team" aria-label="Search technicians" /></label></div>
            <div className="team-table-wrap"><table className="directory-table"><thead><tr><th>Technician</th><th>Trade</th><th>Campus coverage</th><th>Workload</th><th>Availability</th></tr></thead><tbody>{visibleTechnicians.map((person) => <tr key={person.name}>
              <td><div className="person-cell"><span className="avatar person-avatar">{person.initials}</span><strong>{person.name}</strong></div></td><td>{person.trade}</td><td>{person.campus}</td><td><span className="workload-number">{person.assigned}</span><span className="table-muted"> active</span></td><td><span className={`availability ${person.status === 'Available' ? 'available' : ''}`}><i /> {person.status}</span></td>
            </tr>)}</tbody></table>{visibleTechnicians.length === 0 && <div className="empty-state">No team members match this search.</div>}</div>
          </section>
        </div>
      </section>
    </main>
  );
}