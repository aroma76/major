import { useState, useEffect } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { channelAPI } from '../services/api';

const SUBJ_COLORS = ['#6C63FF','#4ECDC4','#FFD93D','#FF6B6B','#FF63B8','#4ECDC4','#888780','#A9A4FF'];

export default function Sidebar() {
  const { user, logout } = useAuth();
  const [channels, setChannels] = useState([]);
  const [search, setSearch] = useState('');
  const navigate = useNavigate();

  useEffect(() => {
    channelAPI.getAll()
      .then(r => setChannels(r.data.channels || []))
      .catch(() => {});
  }, []);

  const filtered = channels.filter(c =>
    c.subject_name?.toLowerCase().includes(search.toLowerCase())
  );

  const initials = user?.avatar_initials || user?.name?.split(' ').map(w => w[0]).join('').slice(0,2) || '??';
  const roleLabel = user?.role?.replace('_', ' ') || 'Student';

  return (
    <aside style={{ width: 260, background: '#0D0F14', borderRight: '1px solid rgba(255,255,255,0.05)', display: 'flex', flexDirection: 'column', height: '100vh', flexShrink: 0 }}>
      {/* ── TOP SECTION ── */}
      <div style={{ padding: '24px 20px 16px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20 }}>
          <div style={{ width: 32, height: 32, background: 'linear-gradient(135deg, #6C63FF, #4ECDC4)', borderRadius: '8px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <svg viewBox="0 0 18 18" fill="none" style={{ width: 14, height: 14 }}>
              <rect x="2" y="2" width="6" height="6" rx="1.5" fill="white" fillOpacity="0.9"/>
              <rect x="10" y="2" width="6" height="6" rx="1.5" fill="white" fillOpacity="0.6"/>
              <rect x="2" y="10" width="6" height="6" rx="1.5" fill="white" fillOpacity="0.6"/>
              <rect x="10" y="10" width="6" height="6" rx="1.5" fill="white" fillOpacity="0.3"/>
            </svg>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            <div style={{ fontSize: 13, fontWeight: 700, color: '#4ECDC4', letterSpacing: '1.5px', textTransform: 'uppercase' }}>AdtU</div>
            <div style={{ fontSize: 10, color: '#5A6070', letterSpacing: '0.5px' }}>Academic Portal</div>
          </div>
        </div>
        
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, background: '#13161E', border: '1px solid rgba(108,99,255,0.3)', borderRadius: 20, padding: '4px 12px', fontSize: 11, color: '#A9A4FF', fontWeight: 600 }}>
          <div style={{ width: 6, height: 6, borderRadius: '50%', background: '#6C63FF' }} />
          B.Tech CSE · Sem {user?.current_semester || 3} · {user?.batch_year || 2024}
        </div>
      </div>

      {/* ── SEARCH ── */}
      <div style={{ padding: '0 20px 20px' }}>
        <div style={{ position: 'relative' }}>
          <input
            placeholder="Search subjects..."
            value={search}
            onChange={e => setSearch(e.target.value)}
            style={{ width: '100%', background: '#13161E', border: '1px solid rgba(255,255,255,0.05)', borderRadius: 8, padding: '10px 14px', fontSize: 13, fontFamily: 'DM Sans, sans-serif', color: '#F0F0F5', outline: 'none' }}
          />
        </div>
      </div>

      {/* ── CHANNELS LIST ── */}
      <div style={{ flex: 1, overflowY: 'auto', paddingBottom: 20 }}>
        <div style={{ padding: '0 20px 8px', fontSize: 11, fontWeight: 600, color: '#5A6070', letterSpacing: '1px', textTransform: 'uppercase' }}>
          Subjects
        </div>

        {filtered.map((ch, i) => (
          <NavLink
            key={ch.id}
            to={`/channels/${ch.id}`}
            style={({ isActive }) => ({
              display: 'flex', alignItems: 'center', gap: 12,
              padding: '10px 20px', cursor: 'pointer',
              position: 'relative', textDecoration: 'none',
              background: isActive ? 'rgba(108,99,255,0.08)' : 'transparent',
              transition: 'all 0.15s',
            })}
          >
            {({ isActive }) => (
              <>
                {isActive && <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: 3, background: '#6C63FF', borderRadius: '0 4px 4px 0' }} />}
                <div style={{ width: 8, height: 8, borderRadius: '50%', flexShrink: 0, background: SUBJ_COLORS[i % SUBJ_COLORS.length] }} />
                <span style={{ fontSize: 14, color: isActive ? '#fff' : '#9096A8', fontWeight: isActive ? 600 : 400, flex: 1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                  {ch.subject_name.split(' ')[0]} {/* Simplified name to match "Data Structures" */}
                </span>
                {/* Mocking random unread counts visually matching image */}
                {i === 0 && <div style={{ background: '#6C63FF', color: '#fff', fontSize: 10, fontWeight: 700, width: 20, height: 20, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>3</div>}
                {i === 2 && <div style={{ background: '#6C63FF', color: '#fff', fontSize: 10, fontWeight: 700, width: 20, height: 20, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>1</div>}
                {i === 4 && <div style={{ width: 6, height: 6, borderRadius: '50%', background: '#FF6B6B' }} />}
              </>
            )}
          </NavLink>
        ))}

        {/* ── QUICK LINKS ── */}
        <div style={{ padding: '24px 20px 8px', fontSize: 11, fontWeight: 600, color: '#5A6070', letterSpacing: '1px', textTransform: 'uppercase' }}>
          Quick Links
        </div>
        
        {/* Calendar Link */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 20px', cursor: 'pointer', color: '#5A6070', transition: 'color 0.15s' }} onMouseEnter={e => e.currentTarget.style.color = '#F0F0F5'} onMouseLeave={e => e.currentTarget.style.color = '#5A6070'}>
          <svg width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
          <span style={{ fontSize: 14 }}>Calendar</span>
        </div>
        
        {/* All Files Link */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 20px', cursor: 'pointer', color: '#5A6070', transition: 'color 0.15s' }} onMouseEnter={e => e.currentTarget.style.color = '#F0F0F5'} onMouseLeave={e => e.currentTarget.style.color = '#5A6070'}>
          <svg width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path d="M13 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"/><polyline points="13 2 13 9 20 9"/></svg>
          <span style={{ fontSize: 14 }}>All Files</span>
        </div>
      </div>

      {/* ── USER FOOTER ── */}
      <div style={{ padding: '16px 20px', borderTop: '1px solid rgba(255,255,255,0.05)', display: 'flex', alignItems: 'center', gap: 12 }}>
        <div style={{ width: 36, height: 36, borderRadius: '50%', background: 'rgba(108,99,255,0.2)', color: '#A9A4FF', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 12, fontWeight: 700, flexShrink: 0 }}>
          {initials}
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 14, fontWeight: 600, color: '#F0F0F5', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{user?.name || 'Rahul Kalita'}</div>
          <div style={{ fontSize: 11, color: '#5A6070', marginTop: 2, textTransform: 'capitalize' }}>{roleLabel === 'student' ? 'Class Representative' : roleLabel}</div>
        </div>
        <button
          onClick={() => { logout(); navigate('/login'); }}
          title="Logout"
          style={{ background: 'transparent', border: 'none', color: '#5A6070', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', transition: 'color 0.15s' }}
          onMouseEnter={e => e.currentTarget.style.color = '#FF6B6B'}
          onMouseLeave={e => e.currentTarget.style.color = '#5A6070'}
        >
          <svg width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="3"/></svg>
        </button>
      </div>
    </aside>
  );
}
