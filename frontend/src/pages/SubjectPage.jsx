import { useState, useEffect, useRef } from 'react';
import { useParams } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { channelAPI, messageAPI, assignmentAPI, announcementAPI, fileAPI, notesAPI } from '../services/api';
import { io } from 'socket.io-client';

const SUBJ_COLORS = ['#6C63FF','#4ECDC4','#FFD93D','#FF6B6B','#FF63B8','#4ECDC4','#888780'];
const AV_COLORS = ['av-purple','av-teal','av-amber','av-pink','av-coral'];

function getAv(name = '') {
  const idx = Array.from(name).reduce((a,c) => a + c.charCodeAt(0), 0) % AV_COLORS.length;
  return AV_COLORS[idx];
}
function getInit(name = '') {
  return name.split(' ').map(w => w[0]).join('').slice(0,2).toUpperCase();
}
function fmtDate(d) {
  if (!d) return '';
  const dt = new Date(d);
  return dt.toLocaleTimeString('en-IN', { hour: 'numeric', minute: '2-digit' });
}
function fmtDue(d) {
  if (!d) return '';
  const dt = new Date(d);
  const today = new Date();
  today.setHours(0,0,0,0);
  const diff = dt - today;
  if (diff < 0) return { label: 'Overdue', cls: 'due-late' };
  if (diff < 86400000 * 2) return { label: dt.toLocaleDateString('en-US',{month:'short',day:'numeric'}), cls: 'due-soon' };
  return { label: dt.toLocaleDateString('en-US',{month:'short',day:'numeric'}), cls: 'due-soon' }; // Using yellow pill for all future ones to match design
}
function fmtSize(bytes) {
  if (!bytes) return '';
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1048576) return (bytes/1024).toFixed(0)+' KB';
  return (bytes/1048576).toFixed(1)+' MB';
}

export default function SubjectPage() {
  const { id } = useParams();
  const { user } = useAuth();
  const [channel, setChannel] = useState(null);
  const [allChannelsCount, setAllChannelsCount] = useState(0);
  const [tab, setTab] = useState('dashboard');
  const [messages, setMessages] = useState([]);
  const [assignments, setAssignments] = useState([]);
  const [announcements, setAnnouncements] = useState([]);
  const [files, setFiles] = useState([]);
  const [notes, setNotes] = useState([]);
  const [chatMsg, setChatMsg] = useState('');
  const chatEndRef = useRef(null);
  const socketRef = useRef(null);

  const chIdx = parseInt(id) % SUBJ_COLORS.length;
  const chColor = SUBJ_COLORS[chIdx];

  // Load channel data
  useEffect(() => {
    if (!id) return;
    channelAPI.getAll().then(r => setAllChannelsCount(r.data.channels?.length || 0)).catch(() => {});
    channelAPI.getById(id).then(r => setChannel(r.data.channel)).catch(() => {});
    messageAPI.getByChannel(id).then(r => setMessages(r.data.messages || [])).catch(() => {});
    assignmentAPI.getByChannel(id).then(r => setAssignments(r.data.assignments || [])).catch(() => {});
    announcementAPI.getByChannel(id).then(r => setAnnouncements(r.data.announcements || [])).catch(() => {});
    fileAPI.getByChannel(id).then(r => setFiles(r.data.files || [])).catch(() => {});
    notesAPI.getByChannel(id).then(r => setNotes(r.data.notes || [])).catch(() => {});
  }, [id]);

  useEffect(() => {
    const socket = io(import.meta.env.VITE_API_URL || 'http://localhost:5000', {
      auth: { token: localStorage.getItem('adtu_token') }
    });
    socketRef.current = socket;
    socket.emit('join_channel', id);
    socket.on('new_message', msg => setMessages(prev => [...prev, msg]));
    return () => { socket.emit('leave_channel', id); socket.disconnect(); };
  }, [id]);

  useEffect(() => { chatEndRef.current?.scrollIntoView({ behavior: 'smooth' }); }, [messages]);

  const sendMessage = async () => {
    if (!chatMsg.trim()) return;
    const text = chatMsg;
    setChatMsg('');
    try {
      const fd = new FormData();
      fd.append('content', text);
      const r = await messageAPI.send(id, fd);
      setMessages(prev => [...prev, r.data.message]);
    } catch {}
  };

  const pendingAssign = assignments.filter(a => !a.submission_status && new Date(a.due_date) > new Date());
  const pinnedAnn = announcements[0]; // Assuming first is pinned

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden', background: '#13161E' }}>
      
      {/* ── HEADER ── */}
      <div style={{ padding: '20px 24px', borderBottom: '1px solid rgba(255,255,255,0.05)', display: 'flex', alignItems: 'center', gap: 12 }}>
        <div style={{ width: 10, height: 10, borderRadius: '50%', background: '#6C63FF', flexShrink: 0 }} />
        <div style={{ fontSize: 20, fontWeight: 700, fontFamily: 'Syne, sans-serif', letterSpacing: '-0.3px', color: '#fff' }}>
          {channel?.subject_name || 'Loading...'}
        </div>
        {channel?.teacher_name && (
          <div style={{ background: 'rgba(255,217,61,0.08)', border: '1px solid rgba(255,217,61,0.2)', color: '#FFD93D', padding: '4px 12px', borderRadius: 20, fontSize: 11, fontWeight: 500 }}>
            {channel.teacher_name}
          </div>
        )}
        <div style={{ marginLeft: 'auto', display: 'flex', gap: 12 }}>
          <button style={{ width: 36, height: 36, background: '#1A1D27', border: 'none', borderRadius: 10, color: '#9096A8', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
            <svg width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>
          </button>
          <button style={{ width: 36, height: 36, background: '#1A1D27', border: 'none', borderRadius: 10, color: '#9096A8', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
            <svg width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 01-3.46 0"/></svg>
          </button>
        </div>
      </div>

      {/* ── TABS ── */}
      <div style={{ display: 'flex', gap: 24, padding: '0 24px', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
        {['Dashboard', 'Notes', 'Assignments', 'Files'].map(t => {
          const active = tab === t.toLowerCase();
          return (
            <button key={t} onClick={() => setTab(t.toLowerCase())} style={{ background: 'none', border: 'none', padding: '16px 0', fontSize: 14, fontWeight: active ? 600 : 400, color: active ? '#6C63FF' : '#5A6070', borderBottom: active ? '2px solid #6C63FF' : '2px solid transparent', cursor: 'pointer', fontFamily: 'DM Sans, sans-serif' }}>
              {t}
            </button>
          );
        })}
      </div>

      {/* ── TAB CONTENT ── */}
      <div style={{ flex: 1, overflowY: 'auto', padding: 24 }}>
        {tab === 'dashboard' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            
            {/* STATS ROW (3 cols) */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16 }}>
              {[
                { num: files.length, label: 'Files uploaded', color: '#6C63FF' },
                { num: pendingAssign.length, label: 'Pending tasks', color: '#4ECDC4' },
                { num: allChannelsCount, label: 'Subjects this semester', color: '#FFD93D' }
              ].map((s, i) => (
                <div key={i} style={{ background: '#1A1D27', border: '1px solid rgba(255,255,255,0.05)', borderRadius: 14, padding: '20px', position: 'relative', overflow: 'hidden' }}>
                  <div style={{ position: 'absolute', width: 60, height: 60, borderRadius: '50%', top: -10, right: 10, background: s.color, opacity: 0.1 }} />
                  <div style={{ fontSize: 32, fontWeight: 700, fontFamily: 'Syne, sans-serif', color: s.color, lineHeight: 1, marginBottom: 8 }}>{s.num}</div>
                  <div style={{ fontSize: 13, color: '#5A6070' }}>{s.label}</div>
                </div>
              ))}
            </div>

            {/* PINNED ANNOUNCEMENT */}
            {pinnedAnn && (
              <div style={{ background: '#151421', border: '1px solid rgba(108,99,255,0.15)', borderRadius: 14, padding: '16px 20px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
                  <span style={{ fontSize: 14 }}>📢</span>
                  <span style={{ fontSize: 10, fontWeight: 700, letterSpacing: '1px', color: '#A9A4FF', textTransform: 'uppercase' }}>Pinned Announcement</span>
                </div>
                <div style={{ fontSize: 13.5, color: '#F0F0F5', lineHeight: 1.5 }}>
                  {pinnedAnn.content}
                </div>
                <div style={{ fontSize: 11, color: '#5A6070', marginTop: 8 }}>
                  {pinnedAnn.user_name || 'Dr. Manoj Sarma'} · {new Date(pinnedAnn.created_at).toLocaleDateString('en-US', {day:'numeric', month:'short'})}, {fmtDate(pinnedAnn.created_at)}
                </div>
              </div>
            )}

            {/* BOTTOM 2-COL LAYOUT */}
            <div style={{ display: 'grid', gridTemplateColumns: '1.9fr 1.1fr', gap: 16, alignItems: 'start' }}>
              
              {/* LEFT COL: ASSIGNMENTS + FILES */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                
                {/* Assignments Card */}
                <div style={{ background: '#1A1D27', border: '1px solid rgba(255,255,255,0.05)', borderRadius: 14, padding: '20px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
                    <div style={{ fontSize: 10, fontWeight: 600, letterSpacing: '1px', color: '#5A6070', textTransform: 'uppercase' }}>Assignments</div>
                    <div style={{ fontSize: 11, color: '#6C63FF', cursor: 'pointer' }}>See all</div>
                  </div>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                    {assignments.slice(0, 4).map((a, i) => {
                      const isDone = Boolean(a.submission_status);
                      const due = fmtDue(a.due_date);
                      return (
                        <div key={a.id} style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                          {isDone ? (
                            <div style={{ width: 18, height: 18, borderRadius: 4, background: '#4ECDC4', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                              <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="#000" strokeWidth="3"><path d="M20 6L9 17l-5-5"/></svg>
                            </div>
                          ) : (
                            <div style={{ width: 18, height: 18, borderRadius: 4, border: '1.5px solid rgba(255,255,255,0.1)' }} />
                          )}
                          <div style={{ flex: 1, fontSize: 13, color: isDone ? '#5A6070' : '#F0F0F5', textDecoration: isDone ? 'line-through' : 'none' }}>
                            {a.title}
                          </div>
                          {isDone ? (
                            <div style={{ fontSize: 10, fontWeight: 600, background: 'rgba(78,205,196,0.1)', color: '#4ECDC4', padding: '2px 8px', borderRadius: 6 }}>Done</div>
                          ) : (
                            <div style={{ fontSize: 10, fontWeight: 600, background: due.label === 'Overdue' ? 'rgba(255,107,107,0.1)' : 'rgba(255,217,61,0.1)', color: due.label === 'Overdue' ? '#FF6B6B' : '#FFD93D', padding: '2px 8px', borderRadius: 6 }}>{due.label}</div>
                          )}
                        </div>
                      );
                    })}
                    {assignments.length === 0 && <div style={{ fontSize: 12, color: '#5A6070' }}>No assignments yet</div>}
                  </div>
                </div>

                {/* Recent Files Card */}
                <div style={{ background: '#1A1D27', border: '1px solid rgba(255,255,255,0.05)', borderRadius: 14, padding: '20px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
                    <div style={{ fontSize: 10, fontWeight: 600, letterSpacing: '1px', color: '#5A6070', textTransform: 'uppercase' }}>Recent Files</div>
                    <div style={{ fontSize: 11, color: '#6C63FF', cursor: 'pointer' }}>See all</div>
                  </div>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                    {files.slice(0, 3).map(f => {
                      const fi = fileIcon(f.file_url || f.file_name || '');
                      return (
                        <div key={f.id} style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                          <div className={fi.cls} style={{ width: 32, height: 32, borderRadius: 8, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 10, fontWeight: 700 }}>
                            {fi.label}
                          </div>
                          <div style={{ flex: 1, overflow: 'hidden' }}>
                            <div style={{ fontSize: 13, color: '#F0F0F5', whiteSpace: 'nowrap', textOverflow: 'ellipsis', overflow: 'hidden' }}>{f.file_name}</div>
                            {f.description && <div style={{ fontSize: 11, color: '#5A6070', whiteSpace: 'nowrap', textOverflow: 'ellipsis', overflow: 'hidden' }}>{f.description}</div>}
                          </div>
                          <div style={{ fontSize: 11, color: '#5A6070' }}>{fmtSize(f.file_size)}</div>
                        </div>
                      );
                    })}
                    {files.length === 0 && <div style={{ fontSize: 12, color: '#5A6070' }}>No files yet</div>}
                  </div>
                </div>
              </div>

              {/* RIGHT COL: CHAT PANEL */}
              <div style={{ background: '#1A1D27', border: '1px solid rgba(255,255,255,0.05)', borderRadius: 14, display: 'flex', flexDirection: 'column', height: '600px' }}>
                <div style={{ padding: '16px 20px', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                  <div style={{ fontSize: 14, fontWeight: 600, color: '#F0F0F5', marginBottom: 4 }}>
                    {channel?.subject_name?.split(' ')[0] || 'Channel'} — Chat
                  </div>
                  <div style={{ fontSize: 11, color: '#4ECDC4', display: 'flex', alignItems: 'center', gap: 6 }}>
                    <div style={{ width: 6, height: 6, borderRadius: '50%', background: '#4ECDC4' }} />
                    14 online
                  </div>
                </div>
                
                {/* Messages Area */}
                <div style={{ flex: 1, overflowY: 'auto', padding: '16px 20px', display: 'flex', flexDirection: 'column', gap: 16 }}>
                  {messages.map((m, i) => {
                    const isTeacher = m.sender_role === 'faculty' || m.sender_role === 'admin';
                    const isCR = m.sender_role === 'class_representative';
                    return (
                      <div key={m.id || i} style={{ display: 'flex', gap: 12 }}>
                        <div className={isTeacher ? 'av-teacher' : getAv(m.sender_name)} style={{ width: 32, height: 32, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 11, fontWeight: 600, flexShrink: 0 }}>
                          {getInit(m.sender_name || 'U')}
                        </div>
                        <div style={{ flex: 1 }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                            <span style={{ fontSize: 13, color: '#F0F0F5' }}>{m.sender_name || 'User'}</span>
                            {isTeacher && <span style={{ background: 'rgba(255,217,61,0.1)', color: '#FFD93D', fontSize: 9, padding: '2px 6px', borderRadius: 4, fontWeight: 600 }}>Teacher</span>}
                            {isCR && <span style={{ background: 'rgba(108,99,255,0.15)', color: '#A9A4FF', fontSize: 9, padding: '2px 6px', borderRadius: 4, fontWeight: 600 }}>CR</span>}
                            <span style={{ fontSize: 11, color: '#5A6070', marginLeft: 'auto' }}>{fmtDate(m.created_at)}</span>
                          </div>
                          {m.content && (
                            <div style={{ background: '#20242F', border: '1px solid rgba(255,255,255,0.05)', borderRadius: '0 12px 12px 12px', padding: '10px 14px', fontSize: 13, color: '#9096A8', lineHeight: 1.5 }}>
                              {m.content}
                            </div>
                          )}
                        </div>
                      </div>
                    )
                  })}
                  <div ref={chatEndRef} />
                </div>

                {/* Input Area */}
                <div style={{ padding: '16px', borderTop: '1px solid rgba(255,255,255,0.05)' }}>
                  <input
                    value={chatMsg}
                    onChange={e => setChatMsg(e.target.value)}
                    onKeyDown={e => e.key === 'Enter' && sendMessage()}
                    placeholder="Type a message..."
                    style={{ width: '100%', background: '#20242F', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 8, padding: '12px 16px', fontSize: 13, color: '#fff', outline: 'none', fontFamily: 'DM Sans, sans-serif' }}
                  />
                </div>
              </div>

            </div>
          </div>
        )}

        {/* ── NOTES TAB ── */}
        {tab === 'notes' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
              <div style={{ fontSize: 16, fontWeight: 600, color: '#F0F0F5' }}>Shared Notes</div>
            </div>
            {notes.map(n => (
              <div key={n.id} style={{ background: '#1A1D27', border: '1px solid rgba(255,255,255,0.05)', borderRadius: 14, padding: '20px' }}>
                <div style={{ fontSize: 15, fontWeight: 600, color: '#4ECDC4', marginBottom: 8 }}>{n.title}</div>
                <div style={{ fontSize: 13.5, color: '#9096A8', lineHeight: 1.6, marginBottom: 16, whiteSpace: 'pre-wrap' }}>{n.content}</div>
                <div style={{ fontSize: 11, color: '#5A6070' }}>
                  By {n.author_name} · {new Date(n.created_at).toLocaleDateString('en-US', {day:'numeric', month:'short'})}
                </div>
              </div>
            ))}
            {notes.length === 0 && (
              <div style={{ textAlign: 'center', padding: '40px 0', color: '#5A6070', fontSize: 13 }}>No notes shared yet.</div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
