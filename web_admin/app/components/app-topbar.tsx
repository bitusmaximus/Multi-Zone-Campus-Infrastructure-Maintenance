'use client';

import Link from 'next/link';
import { useEffect, useRef, useState } from 'react';
import { Bell, Check, Moon, Sun, UserRound } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import { useTheme } from '@/app/components/theme-provider';

type NotificationItem = { id: string; title: string; detail: string; time: string; ticket: string };

const demoNotifications: NotificationItem[] = [
  { id: 'notice-1208', title: 'Emergency request needs triage', detail: 'Water leaking under sink · Poly / BIT Campus', time: '8 min ago', ticket: '#1208' },
  { id: 'notice-1207', title: 'Technician assignment updated', detail: 'Projector will not power on · Mekdes Tadesse', time: '34 min ago', ticket: '#1207' },
  { id: 'notice-1204', title: 'Repair marked resolved', detail: 'Ceiling fan making noise · Kebele 09', time: 'Yesterday', ticket: '#1204' },
];

export function AppTopbar({ title, onSignIn }: { title: string; onSignIn?: () => void }) {
  const { theme, toggleTheme } = useTheme();
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const notificationsWrapRef = useRef<HTMLDivElement>(null);
  const notificationsButtonRef = useRef<HTMLButtonElement>(null);
  const [notifications, setNotifications] = useState(demoNotifications);
  const [read, setRead] = useState(false);
  const [profileName, setProfileName] = useState('Demo workspace');
  const [initials, setInitials] = useState('DM');
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  useEffect(() => {
    if (!supabase) return;
    const client = supabase;
    let active = true;
    const loadCurrentUser = async () => {
      const { data: sessionData } = await client.auth.getSession();
      const user = sessionData.session?.user;
      if (!active) return;
      setIsAuthenticated(Boolean(user));
      if (!user) {
        setProfileName('Demo workspace');
        setInitials('DM');
        setNotifications(demoNotifications);
        return;
      }
      const [{ data: profile }, { data: logs }] = await Promise.all([
        client.from('profiles').select('full_name').eq('id', user.id).maybeSingle(),
        client.from('ticket_logs').select('id,new_status,created_at,tickets(ticket_number,title)').order('created_at', { ascending: false }).limit(5),
      ]);
      if (!active) return;
      const name = profile?.full_name ?? user.email ?? 'Dispatcher';
      setProfileName(name);
      setInitials(name.split(/\s+/).slice(0, 2).map((part) => part[0]).join('').toUpperCase());
      if (logs?.length) {
        setNotifications(logs.map((log) => {
          const ticket = log.tickets as unknown as { ticket_number: number; title: string } | null;
          return {
            id: log.id,
            title: `Request moved to ${log.new_status}`,
            detail: ticket?.title ?? 'Campus maintenance request',
            time: new Intl.DateTimeFormat('en', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(log.created_at)),
            ticket: `#${ticket?.ticket_number ?? '----'}`,
          };
        }));
      }
    };
    void loadCurrentUser();
    const { data: listener } = client.auth.onAuthStateChange(() => void loadCurrentUser());
    return () => {
      active = false;
      listener.subscription.unsubscribe();
    };
  }, []);

  const unreadCount = read ? 0 : notifications.length;

  useEffect(() => {
    setRead(localStorage.getItem('campus-dispatch-notifications-read') === 'true');
  }, []);

  useEffect(() => {
    if (!notificationsOpen) return;
    const handlePointerDown = (event: PointerEvent) => {
      if (event.target instanceof Node && !notificationsWrapRef.current?.contains(event.target)) {
        setNotificationsOpen(false);
      }
    };
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setNotificationsOpen(false);
        notificationsButtonRef.current?.focus();
      }
    };
    document.addEventListener('pointerdown', handlePointerDown);
    document.addEventListener('keydown', handleKeyDown);
    return () => {
      document.removeEventListener('pointerdown', handlePointerDown);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [notificationsOpen]);

  return (
    <header className="topbar">
      <div className="breadcrumbs">Operations <span>/</span> <strong>{title}</strong></div>
      <div className="topbar-actions">
        <span className="live-indicator"><i /> {supabase ? profileName === 'Demo workspace' ? 'Sign in required' : 'Connected to Supabase' : 'Demo workspace'}</span>
        <div className="topbar-control-wrap">
          <button className="icon-button" aria-label={theme === 'dark' ? 'Switch to light theme' : 'Switch to dark theme'} title={theme === 'dark' ? 'Switch to light theme' : 'Switch to dark theme'} onClick={toggleTheme}>
            {theme === 'dark' ? <Sun size={18} /> : <Moon size={18} />}
          </button>
        </div>
        <div className="topbar-control-wrap" ref={notificationsWrapRef}>
          <button ref={notificationsButtonRef} className="icon-button" aria-label={`Notifications${unreadCount ? `, ${unreadCount} unread` : ''}`} aria-expanded={notificationsOpen} onClick={() => setNotificationsOpen((open) => !open)}>
            <Bell size={18} />{unreadCount > 0 && <span className="notification-dot" />}
          </button>
          {notificationsOpen && <section className="notification-popover" aria-label="Notifications">
                <div className="popover-heading"><div><strong>Notifications</strong><span>{unreadCount ? `${unreadCount} unread` : 'All caught up'}</span></div><button className="mark-read-button" onClick={() => { setRead(true); localStorage.setItem('campus-dispatch-notifications-read', 'true'); }}><Check size={13} /> Mark read</button></div>
            <div className="notification-list">{notifications.map((item) => <Link className={`notification-item ${read ? 'read' : ''}`} href={`/?ticket=${encodeURIComponent(item.ticket.replace('#', ''))}`} key={item.id} onClick={() => setNotificationsOpen(false)}>
              <span className="notification-bullet" /><span className="notification-content"><strong>{item.title}</strong><span>{item.detail}</span><small>{item.ticket} · {item.time}</small></span>
            </Link>)}</div>
            <Link className="all-activity-link" href="/activity" onClick={() => setNotificationsOpen(false)}>View activity log</Link>
          </section>}
        </div>
        {supabase && (isAuthenticated
          ? <button className="profile-signout" onClick={() => void supabase.auth.signOut()}>Sign out</button>
          : onSignIn
            ? <button className="profile-signout" onClick={onSignIn}>Sign in</button>
            : <Link className="profile-signout" href="/">Sign in</Link>)}
        <Link className="top-profile-link" href="/profile" aria-label={`Open profile: ${profileName}`} title={profileName}>
          <span className="avatar top-avatar">{initials}</span><UserRound className="profile-link-indicator" size={13} />
        </Link>
      </div>
    </header>
  );
}