'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useState } from 'react';
import { Activity, Building2, LayoutDashboard, MapPin, Settings2, ShieldCheck, Wrench } from 'lucide-react';
import { supabase } from '@/lib/supabase';

const navigation = [
  { href: '/', label: 'Dispatch queue', icon: LayoutDashboard },
  { href: '/activity', label: 'Activity log', icon: Activity },
  { href: '/zones', label: 'Campus zones', icon: MapPin },
  { href: '/team', label: 'Maintenance team', icon: Building2 },
];

export function AdminSidebar({ isAuthenticated: authenticatedProp }: { isAuthenticated?: boolean }) {
  const pathname = usePathname();
  const [profileName, setProfileName] = useState('Demo workspace');
  const [profileInitials, setProfileInitials] = useState('DM');
  const [hasSession, setHasSession] = useState(false);
  const isAuthenticated = authenticatedProp ?? hasSession;

  useEffect(() => {
    if (!supabase) return;
    const client = supabase;
    let active = true;
    const loadProfile = async () => {
      const { data: sessionData } = await client.auth.getSession();
      const user = sessionData.session?.user;
      if (active) setHasSession(Boolean(user));
      if (!user || !active) return;
      const { data } = await client.from('profiles').select('full_name').eq('id', user.id).maybeSingle();
      if (!active) return;
      const name = data?.full_name ?? user.email ?? 'Dispatcher';
      setProfileName(name);
      setProfileInitials(name.split(/\s+/).slice(0, 2).map((part) => part[0]).join('').toUpperCase());
    };
    void loadProfile();
    const { data: listener } = client.auth.onAuthStateChange(() => void loadProfile());
    return () => {
      active = false;
      listener.subscription.unsubscribe();
    };
  }, []);

  return (
    <aside className="sidebar">
      <Link className="brand-lockup" href="/">
        <div className="brand-mark"><Building2 className="brand-building" size={19} strokeWidth={2} /><span className="brand-wrench"><Wrench size={10} strokeWidth={2.5} /></span></div>
        <div><strong>BDU Facilities</strong><span>Maintenance dispatch</span></div>
      </Link>
      <div className="workspace-label">WORKSPACE</div>
      <nav className="primary-nav" aria-label="Main navigation">
        {navigation.map(({ href, label, icon: Icon }) => (
          <Link key={href} className={`nav-item ${pathname === href ? 'active' : ''}`} href={href} aria-current={pathname === href ? 'page' : undefined}>
            <Icon size={17} /> {label}
          </Link>
        ))}
      </nav>
      <div className="sidebar-bottom">
        <div className="coverage-card">
          <div className="coverage-heading"><ShieldCheck size={16} /><span>Service coverage</span></div>
          <strong>3 campuses</strong>
          <span>Dispatch active today</span>
          <div className="coverage-dots"><i /><i /><i /></div>
        </div>
        <Link className={`nav-item settings-button ${pathname === '/settings' ? 'active' : ''}`} href="/settings" aria-current={pathname === '/settings' ? 'page' : undefined}>
          <Settings2 size={17} /> Workspace settings
        </Link>
        <Link className="user-profile profile-sidebar-link" href="/profile" aria-current={pathname === '/profile' ? 'page' : undefined}>
          <div className="avatar dispatcher-avatar">{isAuthenticated ? profileInitials : 'DM'}</div>
          <div className="user-meta"><strong>{isAuthenticated ? profileName : 'Demo workspace'}</strong><span>{isAuthenticated ? 'View profile' : 'Sample data'}</span></div>
        </Link>
      </div>
    </aside>
  );
}