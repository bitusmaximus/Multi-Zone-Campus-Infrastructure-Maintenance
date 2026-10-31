'use client';

import { FormEvent, useEffect, useState } from 'react';
import { Check, Mail, ShieldCheck, UserRound } from 'lucide-react';
import { AppTopbar } from '@/app/components/app-topbar';
import { AdminSidebar } from '@/app/components/admin-sidebar';
import { supabase } from '@/lib/supabase';

export default function ProfilePage() {
  const [fullName, setFullName] = useState('Campus Dispatcher');
  const [email, setEmail] = useState('dispatcher@bdu.edu.et');
  const [phone, setPhone] = useState('');
  const [department, setDepartment] = useState('Facilities Operations');
  const [role, setRole] = useState('dispatcher');
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [saved, setSaved] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    if (!supabase) return;
    const client = supabase;
    let active = true;
    const loadProfile = async () => {
      const { data: sessionData } = await client.auth.getSession();
      const user = sessionData.session?.user;
      if (!active) return;
      setIsAuthenticated(Boolean(user));
      if (!user) return;
      setEmail(user.email ?? '');
      const { data, error } = await client.from('profiles').select('full_name,phone_number,department,role').eq('id', user.id).maybeSingle();
      if (!active) return;
      if (error) {
        setMessage(error.message);
        return;
      }
      if (data) {
        setFullName(data.full_name ?? '');
        setPhone(data.phone_number ?? '');
        setDepartment(data.department ?? '');
        setRole(data.role ?? 'dispatcher');
      }
    };
    void loadProfile();
    return () => { active = false; };
  }, []);

  const saveProfile = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setMessage('');
    if (supabase && isAuthenticated) {
      const { data } = await supabase.auth.getUser();
      if (!data.user) {
        setMessage('Your session expired. Sign in again to update your profile.');
        return;
      }
      const { error } = await supabase.from('profiles').update({ full_name: fullName.trim(), phone_number: phone.trim() || null, department: department.trim() || null }).eq('id', data.user.id);
      if (error) {
        setMessage(error.message);
        return;
      }
    }
    setSaved(true);
    window.setTimeout(() => setSaved(false), 2200);
  };

  return (
    <main className="app-shell">
      <AdminSidebar isAuthenticated={isAuthenticated} />
      <section className="main-area">
        <AppTopbar title="My profile" />
        <div className="page-content">
          <div className="page-heading"><div><div className="eyebrow">ACCOUNT <span className="eyebrow-rule" /></div><h1>My profile</h1><p>Keep your dispatcher contact details current.</p></div></div>
          <form className="profile-layout" onSubmit={saveProfile}>
            <section className="profile-identity"><div className="profile-large-avatar">{fullName.split(/\s+/).slice(0, 2).map((part) => part[0]).join('').toUpperCase()}</div><h2>{fullName}</h2><span>{role}</span><div className="profile-identity-divider" /><div className="profile-info-line"><Mail size={15} />{email}</div><div className="profile-info-line"><ShieldCheck size={15} />Role-based account</div></section>
            <section className="profile-form-panel">
              <div className="section-title"><h2>Personal details</h2><span>Profile updates are tied to your campus login</span></div>
              <label className="settings-field"><span>Full name</span><input value={fullName} onChange={(event) => { setFullName(event.target.value); setSaved(false); }} required /></label>
              <label className="settings-field"><span>Email address</span><div className="profile-email-field"><UserRound size={15} /><input value={email} readOnly /></div></label>
              <div className="profile-form-grid"><label className="settings-field"><span>Phone number</span><input type="tel" value={phone} onChange={(event) => { setPhone(event.target.value); setSaved(false); }} placeholder="Add a contact number" /></label><label className="settings-field"><span>Department</span><input value={department} onChange={(event) => { setDepartment(event.target.value); setSaved(false); }} placeholder="Department or unit" /></label></div>
              {message && <div className="profile-message" role="alert">{message}</div>}
              {!isAuthenticated && supabase && <div className="profile-message">Sign in to save changes to your campus account.</div>}
              <div className="settings-actions"><button className={`assign-button ${saved ? 'saved' : ''}`} type="submit" disabled={Boolean(supabase) && !isAuthenticated}>{saved ? <Check size={15} /> : null}{saved ? 'Profile saved' : 'Save profile'}</button></div>
            </section>
          </form>
        </div>
      </section>
    </main>
  );
}