'use client';

import { useMemo, useState } from 'react';
import { Activity, Check, Clock3, Filter, Search, UserRound, Wrench } from 'lucide-react';
import { AdminSidebar } from '@/app/components/admin-sidebar';
import { AppTopbar } from '@/app/components/app-topbar';

const events = [
  { time: '08:18', date: 'Today', ticket: '#1208', title: 'Water leaking under sink', action: 'New report submitted', person: 'Hana Mulugeta', status: 'Pending', kind: 'new' },
  { time: '07:52', date: 'Today', ticket: '#1207', title: 'Projector will not power on', action: 'Assigned to Mekdes Tadesse', person: 'Tsige Assefa', status: 'Assigned', kind: 'assigned' },
  { time: '07:46', date: 'Today', ticket: '#1207', title: 'Projector will not power on', action: 'Priority raised to High', person: 'Tsige Assefa', status: 'Assigned', kind: 'priority' },
  { time: '16:41', date: 'Yesterday', ticket: '#1206', title: 'Classroom door latch is loose', action: 'Work started', person: 'Abel Bekele', status: 'In Progress', kind: 'progress' },
  { time: '15:09', date: 'Yesterday', ticket: '#1205', title: 'Pathway light is out', action: 'New report submitted', person: 'Yonas Alemu', status: 'Pending', kind: 'new' },
  { time: '14:55', date: 'Yesterday', ticket: '#1204', title: 'Ceiling fan making noise', action: 'Marked resolved', person: 'Sara Alemu', status: 'Resolved', kind: 'resolved' },
];

export default function ActivityPage() {
  const [query, setQuery] = useState('');
  const [dateFilter, setDateFilter] = useState('All activity');
  const visibleEvents = useMemo(() => events.filter((event) => {
    const matchesQuery = !query || `${event.ticket} ${event.title} ${event.person} ${event.action}`.toLowerCase().includes(query.toLowerCase());
    const matchesDate = dateFilter === 'All activity' || event.date === dateFilter;
    return matchesQuery && matchesDate;
  }), [query, dateFilter]);

  return (
    <main className="app-shell">
      <AdminSidebar />
      <section className="main-area">
        <AppTopbar title="Activity log" />
        <div className="page-content">
          <div className="page-heading"><div><div className="eyebrow">AUDIT TRAIL <span className="eyebrow-rule" /></div><h1>Activity log</h1><p>A running record of reports, assignments, and repair progress.</p></div><div className="activity-total"><Activity size={15} /> {events.length} recent events</div></div>
          <section className="activity-board">
            <div className="directory-toolbar"><div className="section-title"><h2>Recent activity</h2><span>Latest updates across campus operations</span></div><label className="search-box"><Search size={16} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search activity" aria-label="Search activity" /></label></div>
            <div className="activity-filters"><Filter size={14} /><span>Show</span>{['All activity', 'Today', 'Yesterday'].map((filter) => <button key={filter} className={dateFilter === filter ? 'filter-chip active' : 'filter-chip'} onClick={() => setDateFilter(filter)}>{filter}</button>)}</div>
            <div className="activity-list">
              {visibleEvents.length === 0 ? <div className="empty-state">No activity matches this search.</div> : visibleEvents.map((event, index) => <article className="activity-event" key={`${event.ticket}-${event.time}`}>
                <div className={`event-icon event-${event.kind}`}>{event.kind === 'resolved' ? <Check size={15} /> : event.kind === 'progress' ? <Wrench size={15} /> : event.kind === 'assigned' ? <UserRound size={15} /> : <Activity size={15} />}</div>
                <div className="event-copy"><div className="event-title-line"><strong>{event.action}</strong><span className={`status-pill status-${event.status.toLowerCase().replaceAll(' ', '-')}`}>{event.status}</span></div><p><a href={`/?ticket=${encodeURIComponent(event.ticket.slice(1))}`}>{event.ticket}</a> {event.title}</p><span className="event-person"><UserRound size={12} /> {event.person}</span></div>
                <div className="event-time"><Clock3 size={12} /> <span>{event.date} · {event.time}</span></div>
                {index < visibleEvents.length - 1 && <div className="event-connector" />}
              </article>)}
            </div>
          </section>
        </div>
      </section>
    </main>
  );
}