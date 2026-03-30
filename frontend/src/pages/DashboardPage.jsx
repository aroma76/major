import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { channelAPI } from '../services/api';
import { useAuth } from '../context/AuthContext';

const COLORS = ['#6C63FF','#4ECDC4','#FFD93D','#FF6B6B','#FF63B8','#4ECDC4','#888780'];

export default function DashboardPage() {
  const { user } = useAuth();
  const [channels, setChannels] = useState([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    channelAPI.getAll()
      .then(r => setChannels(r.data.channels || []))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const greeting = () => {
    const h = new Date().getHours();
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  };

  return (
    <div style={{ flex: 1, overflowY: 'auto', padding: '20px 24px', background: 'var(--bg)' }}>
      {/* Header */}
      <div style={{ marginBottom: 28 }}>
        <div className="font-syne" style={{ fontSize: 24, fontWeight: 700, letterSpacing: '-0.5px', marginBottom: 4 }}>
          {greeting()}, {user?.name?.split(' ')[0] || 'Student'} 👋
        </div>
        <div style={{ fontSize: 13.5, color: 'var(--text2)' }}>
          Welcome back to StudyHub. You have {channels.length} active subject channel{channels.length !== 1 ? 's' : ''}.
        </div>
      </div>

      {/* Channel grid */}
      {loading ? (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: 14 }}>
          {[...Array(6)].map((_,i) => (
            <div key={i} style={{ height: 120, background: 'var(--bg2)', borderRadius: 12, border: '1px solid var(--border)', opacity: 0.5 }} />
          ))}
        </div>
      ) : channels.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '80px 0' }}>
          <div style={{ fontSize: 40, marginBottom: 12 }}>📚</div>
          <div className="font-syne" style={{ fontSize: 18, fontWeight: 700, marginBottom: 6 }}>No channels yet</div>
          <div style={{ fontSize: 13.5, color: 'var(--text2)' }}>Your enrolled subject channels will appear here.</div>
        </div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: 14 }}>
          {channels.map((ch, i) => {
            const color = COLORS[i % COLORS.length];
            return (
              <div
                key={ch.id}
                onClick={() => navigate(`/channels/${ch.id}`)}
                style={{ background: 'var(--bg2)', border: '1px solid var(--border)', borderRadius: 14, padding: '16px 18px', cursor: 'pointer', transition: 'border-color 0.2s, transform 0.15s', position: 'relative', overflow: 'hidden' }}
                onMouseEnter={e => { e.currentTarget.style.borderColor = color; e.currentTarget.style.transform = 'translateY(-2px)'; }}
                onMouseLeave={e => { e.currentTarget.style.borderColor = 'var(--border)'; e.currentTarget.style.transform = 'none'; }}
              >
                {/* color accent bar */}
                <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 3, background: color, borderRadius: '14px 14px 0 0' }} />

                <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginTop: 8 }}>
                  <div style={{ width: 36, height: 36, borderRadius: 10, background: `${color}22`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16, flexShrink: 0 }}>
                    📖
                  </div>
                  <div style={{ fontSize: 10, background: 'rgba(108,99,255,0.15)', color: '#A9A4FF', padding: '2px 8px', borderRadius: 20, fontWeight: 500 }}>
                    Sem {ch.semester_number}
                  </div>
                </div>

                <div className="font-syne" style={{ fontSize: 14, fontWeight: 700, color: 'var(--text)', marginTop: 12, marginBottom: 4, lineHeight: 1.3 }}>
                  {ch.subject_name}
                </div>

                {ch.teacher_name && (
                  <div style={{ fontSize: 11, color: 'var(--text3)', display: 'flex', alignItems: 'center', gap: 4 }}>
                    <svg width="10" height="10" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
                    {ch.teacher_name}
                  </div>
                )}

                <div style={{ marginTop: 12, paddingTop: 10, borderTop: '1px solid var(--border)', display: 'flex', alignItems: 'center', gap: 6 }}>
                  <div style={{ width: 6, height: 6, borderRadius: '50%', background: color }} />
                  <span style={{ fontSize: 11, color: 'var(--text3)' }}>Enter channel →</span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
