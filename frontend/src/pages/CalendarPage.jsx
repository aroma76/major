import { useState, useEffect } from 'react';
import { channelAPI, assignmentAPI } from '../services/api';
import { useAuth } from '../context/AuthContext';

function fmtDue(d) {
  if (!d) return '';
  const dt = new Date(d);
  const today = new Date();
  today.setHours(0,0,0,0);
  const diff = dt - today;
  if (diff < 0) return { label: 'Overdue', cls: 'due-late', overdue: true };
  if (diff < 86400000 * 2) return { label: dt.toLocaleDateString('en-US',{month:'short',day:'numeric'}), cls: 'due-soon', overdue: false };
  return { label: dt.toLocaleDateString('en-US',{month:'short',day:'numeric'}), cls: 'due-soon', overdue: false };
}

export default function CalendarPage() {
  const { user } = useAuth();
  const [tasks, setTasks] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchTasks = async () => {
      try {
        const { data } = await channelAPI.getAll();
        const channels = data.channels || [];
        
        const assignmentsPromises = channels.map(async ch => {
          const res = await assignmentAPI.getByChannel(ch.id);
          return (res.data.assignments || []).map(a => ({ ...a, channel_name: ch.subject_name }));
        });

        const nestedTasks = await Promise.all(assignmentsPromises);
        let flattened = nestedTasks.flat().filter(a => !a.submission_status); // Only show pending Tasks on global calendar
        flattened.sort((a,b) => new Date(a.due_date) - new Date(b.due_date));
        setTasks(flattened);
      } catch (err) { }
      setLoading(false);
    };
    fetchTasks();
  }, []);

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: '#0D0F14', overflowY: 'auto' }}>
      <div style={{ padding: '24px 32px', borderBottom: '1px solid rgba(255,255,255,0.05)', background: '#13161E', display: 'flex', gap: 16, alignItems: 'center' }}>
        <h1 style={{ margin: 0, fontSize: 24, fontWeight: 700, color: '#F0F0F5', fontFamily: 'Syne, sans-serif' }}>Upcoming Deadlines</h1>
        <div style={{ background: 'rgba(255,217,61,0.1)', color: '#FFD93D', fontSize: 11, fontWeight: 700, padding: '4px 12px', borderRadius: 20 }}>
          {tasks.length} Pending
        </div>
      </div>
      
      <div style={{ padding: 32 }}>
        {loading ? (
          <div style={{ color: '#5A6070' }}>Loading calendar...</div>
        ) : tasks.length === 0 ? (
          <div style={{ color: '#5A6070', textAlign: 'center', padding: '40px 0' }}>No pending tasks! Enjoy your free time. 🎉</div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16, maxWidth: 800 }}>
            {tasks.map(a => {
              const due = fmtDue(a.due_date);
              return (
                <div key={a.id} style={{ background: '#13161E', border: '1px solid rgba(255,255,255,0.05)', borderRadius: 14, padding: '20px', display: 'flex', alignItems: 'center', gap: 20 }}>
                  <div style={{ width: 4, height: 48, background: due.overdue ? '#FF6B6B' : '#FFD93D', borderRadius: 4, flexShrink: 0 }} />
                  <div style={{ flex: 1 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 4 }}>
                      <div style={{ fontSize: 16, fontWeight: 600, color: '#F0F0F5' }}>{a.title}</div>
                      <div style={{ fontSize: 10, fontWeight: 700, background: due.overdue ? 'rgba(255,107,107,0.1)' : 'rgba(255,217,61,0.1)', color: due.overdue ? '#FF6B6B' : '#FFD93D', padding: '4px 8px', borderRadius: 6, textTransform: 'uppercase' }}>Due: {due.label}</div>
                    </div>
                    <div style={{ fontSize: 13, color: '#5A6070', marginBottom: 8 }}>{a.channel_name} · Created by {a.created_by_name}</div>
                    <div style={{ fontSize: 13, color: '#9096A8', lineHeight: 1.5 }}>{a.description}</div>
                  </div>
                  {user?.role === 'student' && (
                    <a href={`/channels/${a.channel_id}`} style={{ padding: '8px 16px', background: 'rgba(108,99,255,0.1)', border: '1px solid rgba(108,99,255,0.3)', borderRadius: 8, color: '#A9A4FF', fontSize: 12, fontWeight: 600, textDecoration: 'none', whiteSpace: 'nowrap' }}>
                      Go to Subject
                    </a>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
