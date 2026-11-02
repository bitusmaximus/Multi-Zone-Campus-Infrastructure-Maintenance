'use client';

import { FormEvent, useEffect, useMemo, useRef, useState } from 'react';
import { supabase } from '@/lib/supabase';
import {
  Activity,
  AlertTriangle,
  ArrowDownUp,
  Building2,
  Check,
  ChevronDown,
  Clock3,
  Filter,
  Mail,
  MapPin,
  Pencil,
  Search,
  Send,
  ShieldCheck,
  Wrench,
  X,
} from 'lucide-react';
import { AdminSidebar } from '@/app/components/admin-sidebar';
import { AppTopbar } from '@/app/components/app-topbar';

type TicketStatus = 'Pending' | 'Assigned' | 'In Progress' | 'Resolved';
type Priority = 'Emergency' | 'High' | 'Medium' | 'Low';
type Technician = { id: string; name: string; email: string; phone: string };

type Ticket = {
  id: string;
  ticket_number: number;
  title: string;
  description: string;
  priority: Priority;
  status: TicketStatus;
  category: string;
  campus: string;
  block: string;
  room: string;
  created_at: string;
  technician: string;
  latitude?: number | null;
  longitude?: number | null;
};

const initialTickets: Ticket[] = [
  { id: 't-1208', ticket_number: 1208, title: 'Water leaking under sink', description: 'Water is pooling beneath the shared washroom sink and the floor is becoming slippery.', priority: 'Emergency', status: 'Pending', category: 'Dorms', campus: 'Poly / BIT Campus', block: 'Block C', room: 'Ground floor', created_at: '2026-10-31T08:18:00', technician: '' },
  { id: 't-1207', ticket_number: 1207, title: 'Projector will not power on', description: 'The lecture room projector does not start. Power cable is connected and the indicator stays off.', priority: 'High', status: 'Assigned', category: 'Labs', campus: 'Pedagogy Main Campus', block: 'Engineering Lab 2', room: 'Room 204', created_at: '2026-10-31T07:46:00', technician: 'Mekdes Tadesse' },
  { id: 't-1206', ticket_number: 1206, title: 'Classroom door latch is loose', description: 'The latch does not catch consistently and the door can swing open.', priority: 'Medium', status: 'In Progress', category: 'Classrooms', campus: 'Poly / BIT Campus', block: 'Building 4', room: 'Room 18', created_at: '2026-10-30T16:22:00', technician: 'Abel Bekele' },
  { id: 't-1205', ticket_number: 1205, title: 'Pathway light is out', description: 'The light between the library and the east dorm entrance has been out since last night.', priority: 'Low', status: 'Pending', category: 'Grounds', campus: 'Pedagogy Main Campus', block: 'East walkway', room: 'Outdoor', created_at: '2026-10-30T15:09:00', technician: '' },
  { id: 't-1204', ticket_number: 1204, title: 'Ceiling fan making noise', description: 'Fan in the reading room has a rattling sound at medium and high speed.', priority: 'Low', status: 'Resolved', category: 'Classrooms', campus: 'Kebele 09 Health Science', block: 'Library Annex', room: 'Reading room', created_at: '2026-10-30T12:31:00', technician: 'Sara Alemu' },
];

const demoTechnicians: Technician[] = [
  { id: 'mekdes', name: 'Mekdes Tadesse', email: 'mekdes.tadesse@example.edu', phone: '' },
  { id: 'abel', name: 'Abel Bekele', email: 'abel.bekele@example.edu', phone: '' },
  { id: 'sara', name: 'Sara Alemu', email: 'sara.alemu@example.edu', phone: '' },
  { id: 'dawit', name: 'Dawit Fikru', email: 'dawit.fikru@example.edu', phone: '' },
];
const statusOptions: TicketStatus[] = ['Pending', 'Assigned', 'In Progress', 'Resolved'];
const priorityOptions: Priority[] = ['Emergency', 'High', 'Medium', 'Low'];

function formatTime(value: string) {
  return new Intl.DateTimeFormat('en', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }).format(new Date(value));
}

export default function DashboardPage() {
  const [tickets, setTickets] = useState(initialTickets);
  const [technicians, setTechnicians] = useState(demoTechnicians);
  const [selectedId, setSelectedId] = useState(initialTickets[0].id);
  const [activeFilter, setActiveFilter] = useState('All open');
  const [search, setSearch] = useState('');
  const [filterOpen, setFilterOpen] = useState(false);
  const [saved, setSaved] = useState(false);
  const [isEditingDescription, setIsEditingDescription] = useState(false);
  const [descriptionDraft, setDescriptionDraft] = useState('');
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [showLogin, setShowLogin] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [isResettingPassword, setIsResettingPassword] = useState(false);
  const [isUpdatingPassword, setIsUpdatingPassword] = useState(false);
  const [authNotice, setAuthNotice] = useState('');
  const [authError, setAuthError] = useState('');
  const [isSaving, setIsSaving] = useState(false);
  const [syncError, setSyncError] = useState('');
  const isSupabaseConfigured = supabase !== null;
  const ticketParamHandled = useRef(false);

  const refreshBackend = async (authenticated = isAuthenticated) => {
    const client = supabase;
    if (!client || !authenticated) return;
    const [{ data: rows, error }, { data: technicianRows, error: technicianError }, { data: assignmentRows, error: assignmentError }] = await Promise.all([
      client.from('tickets').select('id,ticket_number,title,description,priority,status,room_number,latitude,longitude,created_at,zones(campus_name,category,block_name)').order('created_at', { ascending: false }),
      client.from('profiles').select('id,full_name,email,phone_number,department').eq('role', 'technician').order('full_name'),
      client.from('assignments').select('ticket_id,technician_id,assigned_at').order('assigned_at', { ascending: false }),
    ]);
    if (error || technicianError || assignmentError) {
      throw error ?? technicianError ?? assignmentError;
    }

    const technicianNames = new Map((technicianRows ?? []).map((row) => [row.id, row.full_name]));
    const assignmentNames = new Map<string, string>();
    for (const assignment of assignmentRows ?? []) {
      if (!assignmentNames.has(assignment.ticket_id)) {
        assignmentNames.set(assignment.ticket_id, technicianNames.get(assignment.technician_id) ?? '');
      }
    }
    const nextTickets: Ticket[] = (rows ?? []).map((row) => {
      const zone = row.zones as unknown as { campus_name?: string; category?: string; block_name?: string } | null;
      return {
        id: row.id,
        ticket_number: row.ticket_number,
        title: row.title,
        description: row.description,
        priority: row.priority,
        status: row.status,
        category: zone?.category ?? 'Other',
        campus: zone?.campus_name ?? 'Campus',
        block: zone?.block_name ?? '',
        room: row.room_number ?? '',
        created_at: row.created_at,
        technician: assignmentNames.get(row.id) ?? '',
        latitude: row.latitude === null ? null : Number(row.latitude),
        longitude: row.longitude === null ? null : Number(row.longitude),
      };
    });
    setTickets(nextTickets);
    setTechnicians((technicianRows ?? []).map((row) => ({ id: row.id, name: row.full_name, email: row.email, phone: row.phone_number ?? '' })));
    setSelectedId((current) => nextTickets.some((ticket) => ticket.id === current) ? current : nextTickets[0]?.id ?? '');
    setSyncError('');
  };

  useEffect(() => {
    const client = supabase;
    if (!client) return;
    let active = true;
    const loadSession = async () => {
      const { data } = await client.auth.getSession();
      if (!active) return;
      setIsAuthenticated(Boolean(data.session));
      if (data.session) {
        try {
          await refreshBackend(true);
        } catch (error) {
          setSyncError(error instanceof Error ? error.message : 'Could not load dispatch data.');
        }
      } else {
        setTickets([]);
      }
    };
    void loadSession();
    const { data: authListener } = client.auth.onAuthStateChange((event, session) => {
      setIsAuthenticated(Boolean(session));
      if (event === 'PASSWORD_RECOVERY') {
        setIsResettingPassword(true);
        setIsUpdatingPassword(true);
        setShowLogin(true);
      }
      if (session) {
        window.setTimeout(() => {
          void refreshBackend(true).catch((error: unknown) => setSyncError(error instanceof Error ? error.message : 'Could not load dispatch data.'));
        }, 0);
      } else {
        setTickets([]);
        setTechnicians([]);
      }
    });
    return () => {
      active = false;
      authListener.subscription.unsubscribe();
    };
  }, []);

  const filteredTickets = useMemo(() => {
    const query = search.trim().toLowerCase();
    return tickets.filter((ticket) => {
      const matchesSearch = !query || [ticket.title, ticket.category, ticket.campus, ticket.block, String(ticket.ticket_number)].some((value) => value.toLowerCase().includes(query));
      const matchesFilter = activeFilter === 'All open'
        ? ticket.status !== 'Resolved'
        : activeFilter === 'Emergency'
          ? ticket.priority === 'Emergency'
          : ticket.status === activeFilter;
      return matchesSearch && matchesFilter;
    }).sort((left, right) => priorityOptions.indexOf(left.priority) - priorityOptions.indexOf(right.priority) || new Date(left.created_at).getTime() - new Date(right.created_at).getTime());
  }, [tickets, activeFilter, search]);

  const selected = filteredTickets.find((ticket) => ticket.id === selectedId) ?? null;

  useEffect(() => {
    setDescriptionDraft(selected?.description ?? '');
    setIsEditingDescription(false);
  }, [selected?.id]);

  useEffect(() => {
    if (selectedId && filteredTickets.length > 0 && !filteredTickets.some((ticket) => ticket.id === selectedId)) {
      setSelectedId(filteredTickets[0].id);
    }
  }, [filteredTickets, selectedId]);

  useEffect(() => {
    if (ticketParamHandled.current) return;
    const ticketNumber = new URLSearchParams(window.location.search).get('ticket');
    if (!ticketNumber) {
      ticketParamHandled.current = true;
      return;
    }
    const ticket = tickets.find((item) => String(item.ticket_number) === ticketNumber);
    if (ticket) {
      setSelectedId(ticket.id);
      ticketParamHandled.current = true;
    }
  }, [tickets]);

  const updateSelected = (changes: Partial<Ticket>) => {
    setTickets((current) => current.map((ticket) => ticket.id === selectedId ? { ...ticket, ...changes } : ticket));
    setSaved(false);
  };

  const signIn = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const client = supabase;
    if (!client) return;
    setAuthError('');
    const { error } = await client.auth.signInWithPassword({ email, password });
    if (error) {
      setAuthError(error.message);
      return;
    }
    setPassword('');
    setShowLogin(false);
  };

  const sendPasswordReset = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const client = supabase;
    if (!client) return;
    setAuthError('');
    setAuthNotice('');
    const { error } = await client.auth.resetPasswordForEmail(email, {
      redirectTo: window.location.origin,
    });
    if (error) {
      setAuthError(error.message);
      return;
    }
    setAuthNotice('If this account exists, a password recovery email has been sent.');
  };

  const updatePassword = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const client = supabase;
    if (!client) return;
    setAuthError('');
    const { error } = await client.auth.updateUser({ password: newPassword });
    if (error) {
      setAuthError(error.message);
      return;
    }
    setNewPassword('');
    setIsResettingPassword(false);
    setIsUpdatingPassword(false);
    setShowLogin(false);
    setAuthNotice('Password updated.');
  };

  const saveChanges = async () => {
    if (!selected) return;
    const updatedDescription = isEditingDescription ? descriptionDraft.trim() : selected.description;
    if (isEditingDescription && updatedDescription.length < 10) {
      setSyncError('Description must include at least 10 characters.');
      return;
    }
    const client = supabase;
    setIsSaving(true);
    try {
      if (client && isAuthenticated) {
        const { data: userData, error: userError } = await client.auth.getUser();
        if (userError || !userData.user) throw userError ?? new Error('Dispatcher session has expired.');
        const { error: updateError } = await client.from('tickets').update({ priority: selected.priority, status: selected.status, description: updatedDescription }).eq('id', selected.id);
        if (updateError) throw updateError;
        if (selected.technician) {
          const technician = technicians.find((item) => item.name === selected.technician);
          if (!technician) throw new Error('Select an active technician before saving.');
          const { data: latestAssignment, error: assignmentReadError } = await client
            .from('assignments')
            .select('technician_id')
            .eq('ticket_id', selected.id)
            .order('assigned_at', { ascending: false })
            .limit(1)
            .maybeSingle();
          if (assignmentReadError) throw assignmentReadError;
          if (latestAssignment?.technician_id !== technician.id) {
            const { error: assignmentError } = await client.from('assignments').insert({
              ticket_id: selected.id,
              dispatcher_id: userData.user.id,
              technician_id: technician.id,
            });
            if (assignmentError) throw assignmentError;
          }
        }
        await refreshBackend();
      } else {
        setTickets((current) => current.map((ticket) => ticket.id === selected.id ? { ...ticket, description: updatedDescription } : ticket));
      }
      setDescriptionDraft(updatedDescription);
      setIsEditingDescription(false);
      setSyncError('');
      setSaved(true);
      window.setTimeout(() => setSaved(false), 2400);
    } catch (error) {
      setSyncError(error instanceof Error ? error.message : 'Could not save dispatch changes.');
    } finally {
      setIsSaving(false);
    }
  };

  const openCount = tickets.filter((ticket) => ticket.status !== 'Resolved').length;
  const emergencyCount = tickets.filter((ticket) => ticket.priority === 'Emergency' && ticket.status !== 'Resolved').length;
  const inProgressCount = tickets.filter((ticket) => ticket.status === 'In Progress').length;
  const resolvedCount = tickets.filter((ticket) => ticket.status === 'Resolved').length;
  const selectedTechnician = selected ? technicians.find((technician) => technician.name === selected.technician) : undefined;

  return (
    <main className="app-shell">
      <AdminSidebar isAuthenticated={isAuthenticated} />
      <section className="main-area" id="queue">
        <AppTopbar title="Dispatch queue" onSignIn={() => setShowLogin(true)} />
        <div className="page-content">
          <div className="page-heading"><div><div className="eyebrow">CAMPUS OPERATIONS <span className="eyebrow-rule" /></div><h1>Dispatch queue</h1><p>Review reports, set priorities, and get campus repairs moving.</p></div><button className="secondary-action" onClick={() => { setActiveFilter('All open'); setSearch(''); if (isSupabaseConfigured && isAuthenticated) void refreshBackend(); }}><ArrowDownUp size={15} /> Refresh queue</button></div>
          {syncError && <div className="sync-error" role="alert">{syncError}</div>}

          <section className="metrics" aria-label="Ticket summary">
            <div className="metric"><div className="metric-top"><span>Open requests</span><span className="metric-icon olive"><Wrench size={16} /></span></div><strong>{String(openCount).padStart(2, '0')}</strong><span className="metric-note">Awaiting completion</span></div>
            <div className="metric"><div className="metric-top"><span>Emergency</span><span className="metric-icon red"><AlertTriangle size={16} /></span></div><strong>{String(emergencyCount).padStart(2, '0')}</strong><span className="metric-note">Needs immediate triage</span></div>
            <div className="metric"><div className="metric-top"><span>In progress</span><span className="metric-icon blue"><Activity size={16} /></span></div><strong>{String(inProgressCount).padStart(2, '0')}</strong><span className="metric-note">Currently with a technician</span></div>
            <div className="metric"><div className="metric-top"><span>Resolved today</span><span className="metric-icon green"><Check size={16} /></span></div><strong>{String(resolvedCount).padStart(2, '0')}</strong><span className="metric-note">Closed requests</span></div>
          </section>

          <section className="queue-section">
            <div className="queue-heading"><div><h2>Maintenance requests</h2><span>{filteredTickets.length} requests <span className="subtle-separator">·</span> priority sorted</span></div><div className="filter-menu-wrap"><button className="filter-button" type="button" title="Filter requests by status or urgency" aria-label="Filter requests by status or urgency" aria-expanded={filterOpen} onClick={() => setFilterOpen((open) => !open)}><Filter size={15} /> Filter <ChevronDown size={14} /></button>{filterOpen && <div className="filter-popover" role="group" aria-label="Filter requests by status or urgency"><span className="filter-popover-heading">Show requests</span>{['All open', 'Pending', 'Assigned', 'In Progress', 'Resolved', 'Emergency'].map((filter) => <button key={filter} type="button" className="filter-option" aria-pressed={activeFilter === filter} onClick={() => { setActiveFilter(filter); setFilterOpen(false); }}>{filter}{activeFilter === filter && <Check size={14} />}</button>)}</div>}</div></div>
            <div className="queue-toolbar"><div className="filter-tabs" role="tablist" aria-label="Filter tickets">{['All open', 'Emergency', 'In Progress', 'Resolved'].map((filter) => <button key={filter} role="tab" aria-selected={activeFilter === filter} className={activeFilter === filter ? 'filter-tab selected' : 'filter-tab'} onClick={() => setActiveFilter(filter)}>{filter}{filter === 'Emergency' && emergencyCount > 0 && <span className="tab-count">{emergencyCount}</span>}</button>)}</div><label className="search-box"><Search size={16} /><input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search requests" aria-label="Search requests" /><kbd>/</kbd></label></div>

            <div className="dispatch-layout">
              <div className="ticket-list" role="list" aria-label="Maintenance requests">
                {filteredTickets.length === 0 ? <div className="empty-state">{isSupabaseConfigured && !isAuthenticated ? 'Sign in with a dispatcher account to load campus requests.' : 'No requests match this view.'}</div> : filteredTickets.map((ticket) => <button key={ticket.id} role="listitem" className={`ticket-row ${selectedId === ticket.id ? 'ticket-selected' : ''}`} onClick={() => { setSelectedId(ticket.id); setSaved(false); }}>
                  <span className={`priority-mark priority-${ticket.priority.toLowerCase()}`} />
                  <span className="ticket-main"><span className="ticket-row-top"><strong>#{ticket.ticket_number}</strong><span className={`status-pill status-${ticket.status.toLowerCase().replaceAll(' ', '-')}`}>{ticket.status}</span></span><strong className="ticket-title">{ticket.title}</strong><span className="ticket-location"><MapPin size={12} /> {ticket.campus} <span>·</span> {ticket.block}</span></span>
                  <span className="ticket-trailing"><span className={`priority-label priority-text-${ticket.priority.toLowerCase()}`}>{ticket.priority}</span><span><Clock3 size={12} /> {formatTime(ticket.created_at)}</span></span>
                </button>)}
              </div>

              {selected && <aside className="detail-panel" aria-label="Selected request details">
                <div className="detail-header"><span className="detail-kicker">REQUEST #{selected.ticket_number}</span><button className="close-detail" aria-label="Close details" onClick={() => setSelectedId('')}><X size={16} /></button></div>
                <h3>{selected.title}</h3><div className="detail-meta"><span className={`status-pill status-${selected.status.toLowerCase().replaceAll(' ', '-')}`}>{selected.status}</span><span className="detail-date">Reported {formatTime(selected.created_at)}</span></div>
                <div className="detail-divider" />
                <div className="detail-group"><label>LOCATION</label><div className="location-detail"><MapPin size={15} /><div><strong>{selected.campus}</strong><span>{selected.category} <span>·</span> {selected.block}{selected.room ? `, ${selected.room}` : ''}</span></div></div>{selected.latitude != null && selected.longitude != null && <a className="map-link" href={`https://www.google.com/maps/search/?api=1&query=${selected.latitude},${selected.longitude}`} target="_blank" rel="noreferrer"><MapPin size={13} /> Open in Google Maps</a>}</div>
                <div className="detail-group description-group"><div className="detail-label-row"><label htmlFor="ticket-description">DESCRIPTION</label><button className="description-edit-button" type="button" title={isEditingDescription ? 'Cancel description edit' : 'Edit report description'} onClick={() => { if (isEditingDescription) setDescriptionDraft(selected.description); else setDescriptionDraft(selected.description); setIsEditingDescription((editing) => !editing); setSaved(false); }}>{isEditingDescription ? <X size={13} /> : <Pencil size={13} />}{isEditingDescription ? 'Cancel' : 'Edit'}</button></div>{isEditingDescription ? <textarea id="ticket-description" className="description-editor" value={descriptionDraft} minLength={10} maxLength={1000} rows={4} onChange={(event) => { setDescriptionDraft(event.target.value); setSaved(false); }} aria-label="Edit report description" /> : <p className="description-text">{selected.description}</p>}{isEditingDescription && <span className="description-hint">Edits update the ticket description when you save dispatch changes.</span>}</div>
                <div className="detail-fields"><label className="detail-group"><span>PRIORITY</span><select value={selected.priority} onChange={(event) => updateSelected({ priority: event.target.value as Priority })}>{priorityOptions.map((priority) => <option key={priority}>{priority}</option>)}</select></label><label className="detail-group"><span>STATUS</span><select value={selected.status} onChange={(event) => updateSelected({ status: event.target.value as TicketStatus })}>{statusOptions.map((status) => <option key={status}>{status}</option>)}</select></label></div>
                <div className="detail-group"><label htmlFor="technician">ASSIGN TECHNICIAN</label><div className="select-wrap"><select id="technician" value={selected.technician} onChange={(event) => updateSelected({ technician: event.target.value, status: event.target.value && selected.status === 'Pending' ? 'Assigned' : selected.status })}><option value="">Select a technician</option>{technicians.map((technician) => <option key={technician.id} value={technician.name}>{technician.name}</option>)}</select><ChevronDown size={15} /></div></div>
                {selectedTechnician?.email && <a className="contact-link" href={`mailto:${selectedTechnician.email}?subject=${encodeURIComponent(`Campus dispatch request #${selected.ticket_number}`)}&body=${encodeURIComponent(`${selected.title}\n${selected.campus} · ${selected.block}${selected.room ? ` · ${selected.room}` : ''}\nPriority: ${selected.priority}\nStatus: ${selected.status}`)}`}><Mail size={14} /> Email {selectedTechnician.name}</a>}
                <div className="detail-footer"><button className={`assign-button ${saved ? 'saved' : ''}`} onClick={() => void saveChanges()} disabled={isSaving || (isSupabaseConfigured && !isAuthenticated) || (isEditingDescription && descriptionDraft.trim().length < 10)}>{isSaving ? <Activity size={15} /> : saved ? <Check size={15} /> : <Send size={15} />}{isSaving ? 'Saving...' : saved ? 'Changes saved' : 'Save dispatch changes'}</button><span>{isSupabaseConfigured && isAuthenticated ? 'Changes are saved to Supabase.' : isSupabaseConfigured ? 'Sign in to save changes.' : 'Changes are stored in this demo session.'}</span></div>
              </aside>}
            </div>
          </section>
          <footer className="page-footer"><span><ShieldCheck size={14} /> BDU Facilities Operations</span><span>Internal dispatch workspace <i /> Demo data</span></footer>
        </div>
      </section>
      {showLogin && <div className="auth-overlay" role="presentation" onClick={() => setShowLogin(false)}><form className="auth-modal" onSubmit={isResettingPassword ? (isUpdatingPassword ? updatePassword : sendPasswordReset) : signIn} onClick={(event) => event.stopPropagation()}><button className="auth-close" type="button" aria-label="Close sign in" onClick={() => setShowLogin(false)}><X size={17} /></button><span className="detail-kicker">DISPATCHER ACCESS</span><h2>{isResettingPassword ? 'Reset password' : 'Sign in'}</h2><p>{isUpdatingPassword ? 'Choose a new password for your dispatcher account.' : isResettingPassword ? 'We will email a secure password recovery link.' : 'Use your campus dispatcher account to load and assign requests.'}</p>{(!isResettingPassword || !isUpdatingPassword) && <label>Email<input type="email" autoComplete="username" value={email} onChange={(event) => setEmail(event.target.value)} required /></label>}{isUpdatingPassword && <label>New password<input type="password" autoComplete="new-password" minLength={6} value={newPassword} onChange={(event) => setNewPassword(event.target.value)} required /></label>}{!isResettingPassword && <label>Password<input type="password" autoComplete="current-password" value={password} onChange={(event) => setPassword(event.target.value)} required /></label>}{authError && <span className="auth-error" role="alert">{authError}</span>}{authNotice && <span role="status">{authNotice}</span>}<button className="assign-button" type="submit">{isUpdatingPassword ? 'Update password' : isResettingPassword ? 'Send recovery email' : 'Sign in to dispatch'}</button>{!isResettingPassword && <button className="profile-signout" type="button" onClick={() => { setIsResettingPassword(true); setIsUpdatingPassword(false); setAuthError(''); setAuthNotice(''); }}>Forgot password?</button>}{isResettingPassword && <button className="profile-signout" type="button" onClick={() => { setIsResettingPassword(false); setIsUpdatingPassword(false); setNewPassword(''); setAuthError(''); }}>Back to sign in</button>}</form></div>}
    </main>
  );
}