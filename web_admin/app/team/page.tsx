'use client';

import { useEffect, useMemo, useState } from 'react';
import { Mail, Phone, Search, Wrench } from 'lucide-react';
import { AdminSidebar } from '@/app/components/admin-sidebar';
import { AppTopbar } from '@/app/components/app-topbar';
import { supabase } from '@/lib/supabase';

type Technician = { id: string; name: string; email: string; phone: string; department: string; openTickets: number };

const demoTechnicians: Technician[] = [
  { id: 'mekdes', name: 'Mekdes Tadesse', email: 'mekdes.tadesse@example.edu', phone: '', department: 'Electrical', openTickets: 3 },
  { id: 'abel', name: 'Abel Bekele', email: 'abel.bekele@example.edu', phone: '', department: 'Carpentry', openTickets: 2 },
  { id: 'sara', name: 'Sara Alemu', email: 'sara.alemu@example.edu', phone: '', department: 'General maintenance', openTickets: 1 },
  { id: 'dawit', name: 'Dawit Fikru', email: 'dawit.fikru@example.edu', phone: '', department: 'Plumbing', openTickets: 0 },
];

export default function TeamPage() {
  const [query, setQuery] = useState('');
  const [technicians, setTechnicians] = useState<Technician[]>(() => supabase ? [] : demoTechnicians);
  const [isLoading, setIsLoading] = useState(Boolean(supabase));
  const [requiresSignIn, setRequiresSignIn] = useState(false);
  const [loadError, setLoadError] = useState('');

  useEffect(() => {
    if (!supabase) return;
    const client = supabase;
    let active = true;
    const loadTechnicians = async () => {
      setIsLoading(true);
      setLoadError('');
      try {
        const { data: sessionData } = await client.auth.getSession();
        if (!active) return;
        if (!sessionData.session) {
          setRequiresSignIn(true);
          setTechnicians([]);
          return;
        }

        const [{ data: profiles, error: profileError }, { data: assignmentRows, error: assignmentError }] = await Promise.all([
          client.from('profiles').select('id,full_name,email,phone_number,department').eq('role', 'technician').order('full_name'),
          client.from('assignments').select('ticket_id,technician_id,assigned_at,tickets!inner(status)').order('assigned_at', { ascending: false }),
        ]);
        if (!active) return;
        if (profileError || assignmentError) {
          setLoadError(profileError?.message ?? assignmentError?.message ?? 'Could not load the technician roster.');
          return;
        }

        const latestTechnicianByTicket = new Set<string>();
        const openCounts = new Map<string, number>();
        for (const assignment of assignmentRows ?? []) {
          if (latestTechnicianByTicket.has(assignment.ticket_id)) continue;
          latestTechnicianByTicket.add(assignment.ticket_id);
          const ticket = assignment.tickets as unknown as { status: string };
          if (ticket.status !== 'Resolved' && ticket.status !== 'Rejected') {
            openCounts.set(assignment.technician_id, (openCounts.get(assignment.technician_id) ?? 0) + 1);
          }
        }

        setTechnicians((profiles ?? []).map((person) => ({
          id: person.id,
          name: person.full_name,
          email: person.email,
          phone: person.phone_number ?? '',
          department: person.department ?? 'Not specified',
          openTickets: openCounts.get(person.id) ?? 0,
        })));
        setRequiresSignIn(false);
      } catch (error) {
        if (active) setLoadError(error instanceof Error ? error.message : 'Could not load the technician roster.');
      } finally {
        if (active) setIsLoading(false);
      }
    };
    void loadTechnicians();
    return () => { active = false; };
  }, []);

  const visibleTechnicians = useMemo(() => technicians.filter((person) => `${person.name} ${person.department} ${person.email} ${person.phone}`.toLowerCase().includes(query.toLowerCase())), [technicians, query]);
  const activeCount = technicians.filter((person) => person.openTickets > 0).length;
  const assignmentCount = technicians.reduce((total, person) => total + person.openTickets, 0);

  return (
    <main className="app-shell">
      <AdminSidebar />
      <section className="main-area">
        <AppTopbar title="Maintenance team" />
        <div className="page-content">
          <div className="page-heading"><div><div className="eyebrow">FIELD OPERATIONS <span className="eyebrow-rule" /></div><h1>Maintenance team</h1><p>Contact technicians and review their current assigned workload.</p></div><span className="directory-count"><Wrench size={15} /> {technicians.length} technicians</span></div>
          {supabase && <div className="team-data-note">{requiresSignIn ? 'Sign in with a dispatcher account to view team contact details.' : 'Contact details are visible to signed-in dispatchers.'}</div>}
          {loadError && <div className="sync-error" role="alert">{loadError}</div>}
          <section className="metrics team-metrics" aria-label="Team summary">
            <div className="metric"><div className="metric-top"><span>Technicians</span><span className="metric-icon olive"><Wrench size={16} /></span></div><strong>{String(technicians.length).padStart(2, '0')}</strong><span className="metric-note">Registered team members</span></div>
            <div className="metric"><div className="metric-top"><span>Open assignments</span><span className="metric-icon blue"><Wrench size={16} /></span></div><strong>{String(assignmentCount).padStart(2, '0')}</strong><span className="metric-note">Current workload across the team</span></div>
            <div className="metric"><div className="metric-top"><span>No open assignments</span><span className="metric-icon green"><Wrench size={16} /></span></div><strong>{String(technicians.length - activeCount).padStart(2, '0')}</strong><span className="metric-note">Based on tickets currently assigned</span></div>
          </section>
          <section className="directory-panel">
            <div className="directory-toolbar"><div className="section-title"><h2>Technician roster</h2><span>{visibleTechnicians.length} team members{!supabase && ' · demo contacts'}</span></div><label className="search-box"><Search size={16} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search team" aria-label="Search technicians" /></label></div>
            <div className="team-table-wrap"><table className="directory-table"><thead><tr><th>Technician</th><th>Trade / department</th><th>Email</th><th>Phone</th><th>Current workload</th></tr></thead><tbody>{visibleTechnicians.map((person) => <tr key={person.id}>
              <td><div className="person-cell"><span className="avatar person-avatar">{person.name.split(/\s+/).slice(0, 2).map((part) => part[0]).join('').toUpperCase()}</span><strong>{person.name}</strong></div></td>
              <td>{person.department}</td>
              <td><a className="team-contact-link" href={`mailto:${person.email}`}><Mail size={13} /> {person.email}</a></td>
              <td>{person.phone ? <a className="team-contact-link" href={`tel:${person.phone}`}><Phone size={13} /> {person.phone}</a> : <span className="table-muted">Not provided</span>}</td>
              <td><span className={`workload-state ${person.openTickets === 0 ? 'clear' : ''}`}>{person.openTickets === 0 ? 'No open tickets' : `${person.openTickets} open ${person.openTickets === 1 ? 'ticket' : 'tickets'}`}</span></td>
            </tr>)}</tbody></table>{isLoading ? <div className="empty-state">Loading team roster…</div> : visibleTechnicians.length === 0 && <div className="empty-state">{requiresSignIn ? 'Sign in with a dispatcher account to view the roster.' : 'No team members match this search.'}</div>}</div>
          </section>
        </div>
      </section>
    </main>
  );
}