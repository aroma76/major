import { useState, useEffect, useRef, useCallback } from 'react';
import { useParams } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { subjectAPI, messageAPI, noteAPI, assignmentAPI, announcementAPI } from '../services/api';
import { getSocket } from '../hooks/useSocket';
import Tabs from '../components/Tabs';
import ChatBubble from '../components/ChatBubble';
import AssignmentCard from '../components/AssignmentCard';
import FileUpload from '../components/FileUpload';
import { format } from 'date-fns';

// ─── Chat Tab ───────────────────────────────────────────────────────────────
function ChatTab({ subjectId }) {
  const { user } = useAuth();
  const [messages, setMessages] = useState([]);
  const [text, setText] = useState('');
  const [file, setFile] = useState(null);
  const [typing, setTyping] = useState('');
  const bottomRef = useRef(null);
  const typingTimer = useRef(null);

  useEffect(() => {
    messageAPI.getBySubject(subjectId).then(r => setMessages(r.data.messages));
    const socket = getSocket();
    if (!socket) return;
    socket.emit('subject:join', subjectId);
    socket.on('message:new', (msg) => setMessages(p => [...p, msg]));
    socket.on('typing:start', ({ userName }) => setTyping(`${userName} is typing...`));
    socket.on('typing:stop', () => setTyping(''));
    return () => { socket.emit('subject:leave', subjectId); socket.off('message:new'); socket.off('typing:start'); socket.off('typing:stop'); };
  }, [subjectId]);

  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: 'smooth' }); }, [messages]);

  const handleTyping = (e) => {
    setText(e.target.value);
    const socket = getSocket();
    if (!socket) return;
    socket.emit('typing:start', { subjectId, userName: user.name });
    clearTimeout(typingTimer.current);
    typingTimer.current = setTimeout(() => socket.emit('typing:stop', { subjectId }), 1500);
  };

  const sendMsg = async (e) => {
    e.preventDefault();
    if (!text.trim() && !file) return;
    const socket = getSocket();
    if (file) {
      const fd = new FormData();
      if (text.trim()) fd.append('content', text);
      fd.append('file', file);
      const res = await messageAPI.send(subjectId, fd);
      setMessages(p => [...p, res.data.message]);
    } else {
      socket?.emit('message:send', { subjectId, senderId: user.id, content: text });
    }
    setText(''); setFile(null);
  };

  const handlePin = async (msgId) => {
    const res = await messageAPI.pin(subjectId, msgId);
    setMessages(p => p.map(m => m.id === msgId ? res.data.message : m));
  };

  const grouped = messages.reduce((acc, msg) => {
    const day = format(new Date(msg.created_at), 'MMMM d, yyyy');
    if (!acc[day]) acc[day] = [];
    acc[day].push(msg);
    return acc;
  }, {});

  return (
    <div className="flex flex-col h-full">
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {Object.entries(grouped).map(([day, msgs]) => (
          <div key={day}>
            <div className="flex items-center gap-3 my-4"><div className="flex-1 h-px bg-surface-100" /><span className="text-xs font-medium text-surface-400 bg-surface-50 px-3 py-1 rounded-full">{day}</span><div className="flex-1 h-px bg-surface-100" /></div>
            <div className="space-y-3">{msgs.map(msg => <ChatBubble key={msg.id} message={msg} onPin={['faculty','admin'].includes(user.role) ? handlePin : null} />)}</div>
          </div>
        ))}
        {messages.length === 0 && <div className="text-center py-16 text-surface-400"><p className="text-3xl mb-2">💬</p><p className="text-sm">No messages yet. Start the conversation!</p></div>}
        {typing && <p className="text-xs italic text-surface-400 px-2">{typing}</p>}
        <div ref={bottomRef} />
      </div>
      <div className="border-t border-surface-100 p-4 bg-white">
        {file && <div className="mb-2 flex items-center gap-2 text-xs text-surface-600 bg-surface-50 rounded-lg px-3 py-2">📎 {file.name}<button onClick={() => setFile(null)} className="ml-auto text-red-500 hover:text-red-700">✕</button></div>}
        <form onSubmit={sendMsg} className="flex items-center gap-2">
          <label className="p-2 rounded-lg hover:bg-surface-100 cursor-pointer text-surface-500 transition-colors">
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13" /></svg>
            <input type="file" className="hidden" onChange={e => setFile(e.target.files[0])} />
          </label>
          <input className="input flex-1" placeholder="Type a message..." value={text} onChange={handleTyping} />
          <button type="submit" className="btn-primary px-4 py-2.5" disabled={!text.trim() && !file}>
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" /></svg>
          </button>
        </form>
      </div>
    </div>
  );
}

// ─── Notes Tab ───────────────────────────────────────────────────────────────
function NotesTab({ subjectId, role }) {
  const [notes, setNotes] = useState([]);
  const [search, setSearch] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ title: '', description: '' });
  const [file, setFile] = useState(null);
  const [loading, setLoading] = useState(false);
  const load = useCallback(() => { noteAPI.getBySubject(subjectId, { search }).then(r => setNotes(r.data.notes)); }, [subjectId, search]);
  useEffect(() => { load(); }, [load]);
  const fileIcon = (type) => { if (type?.includes('pdf')) return '📄'; if (type?.includes('word')||type?.includes('doc')) return '📝'; if (type?.includes('ppt')) return '📊'; if (type?.includes('image')) return '🖼️'; return '📁'; };
  const handleUpload = async (e) => {
    e.preventDefault(); if (!file || !form.title) return; setLoading(true);
    const fd = new FormData(); fd.append('title', form.title); fd.append('description', form.description); fd.append('file', file);
    await noteAPI.upload(subjectId, fd); setShowForm(false); setForm({ title:'', description:'' }); setFile(null); load(); setLoading(false);
  };
  return (
    <div className="p-5 space-y-4">
      <div className="flex items-center gap-3 flex-wrap">
        <div className="relative flex-1 min-w-0 max-w-xs">
          <svg className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-surface-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
          <input className="input pl-9 text-sm" placeholder="Search notes..." value={search} onChange={e => setSearch(e.target.value)} />
        </div>
        {(role==='faculty'||role==='admin') && <button className="btn-primary text-sm" onClick={() => setShowForm(p=>!p)}>{showForm?'Cancel':'+ Upload Note'}</button>}
      </div>
      {showForm && (
        <form onSubmit={handleUpload} className="card space-y-3 border-2 border-primary-100">
          <h3 className="font-semibold text-surface-800">Upload New Note</h3>
          <input className="input" placeholder="Title*" value={form.title} onChange={e => setForm(p=>({...p,title:e.target.value}))} required />
          <textarea className="input resize-none" rows={2} placeholder="Description" value={form.description} onChange={e => setForm(p=>({...p,description:e.target.value}))} />
          <FileUpload onFileSelect={setFile} label="Select note file" />
          <button type="submit" className="btn-primary w-full" disabled={loading||!file}>{loading?'Uploading...':'Upload Note'}</button>
        </form>
      )}
      {notes.length === 0 ? (
        <div className="text-center py-16 text-surface-400"><p className="text-3xl mb-2">📚</p><p className="text-sm">{search?'No matching notes':'No notes uploaded yet'}</p></div>
      ) : (
        <div className="space-y-3">
          {notes.map(note => (
            <div key={note.id} className="card flex items-center gap-4">
              <div className="text-3xl">{fileIcon(note.file_type)}</div>
              <div className="flex-1 min-w-0"><h4 className="font-medium text-surface-900 truncate">{note.title}</h4>{note.description&&<p className="text-xs text-surface-400 mt-0.5 truncate">{note.description}</p>}<p className="text-xs text-surface-400 mt-1">by {note.uploaded_by_name} · {format(new Date(note.created_at),'MMM d, yyyy')}</p></div>
              <a href={note.file_url} target="_blank" rel="noreferrer" className="btn-secondary text-xs px-3 py-2 flex items-center gap-1.5 shrink-0">
                <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" /></svg>Download
              </a>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ─── Assignments Tab ─────────────────────────────────────────────────────────
function AssignmentsTab({ subjectId, role }) {
  const [assignments, setAssignments] = useState([]);
  const [showForm, setShowForm] = useState(false);
  const [submitTarget, setSubmitTarget] = useState(null);
  const [subFile, setSubFile] = useState(null);
  const [subLoading, setSubLoading] = useState(false);
  const [form, setForm] = useState({ title:'', description:'', deadline:'', max_marks:100 });
  const [creating, setCreating] = useState(false);
  const load = useCallback(() => { assignmentAPI.getBySubject(subjectId).then(r => setAssignments(r.data.assignments)); }, [subjectId]);
  useEffect(() => { load(); }, [load]);
  const handleCreate = async (e) => { e.preventDefault(); setCreating(true); await assignmentAPI.create(subjectId, form); setShowForm(false); setForm({title:'',description:'',deadline:'',max_marks:100}); load(); setCreating(false); };
  const handleSubmit = async (e) => { e.preventDefault(); setSubLoading(true); const fd=new FormData(); if(subFile) fd.append('file',subFile); await assignmentAPI.submit(subjectId,submitTarget.id,fd); setSubmitTarget(null); setSubFile(null); load(); setSubLoading(false); };
  return (
    <div className="p-5 space-y-4">
      {(role==='faculty'||role==='admin')&&<div className="flex justify-end"><button className="btn-primary text-sm" onClick={()=>setShowForm(p=>!p)}>{showForm?'Cancel':'+ New Assignment'}</button></div>}
      {showForm&&(
        <form onSubmit={handleCreate} className="card space-y-3 border-2 border-primary-100">
          <h3 className="font-semibold text-surface-800">Create Assignment</h3>
          <input className="input" placeholder="Title*" value={form.title} onChange={e=>setForm(p=>({...p,title:e.target.value}))} required />
          <textarea className="input resize-none" rows={3} placeholder="Description" value={form.description} onChange={e=>setForm(p=>({...p,description:e.target.value}))} />
          <div className="grid grid-cols-2 gap-3">
            <div><label className="text-xs font-medium text-surface-600 mb-1 block">Deadline*</label><input type="datetime-local" className="input" value={form.deadline} onChange={e=>setForm(p=>({...p,deadline:e.target.value}))} required /></div>
            <div><label className="text-xs font-medium text-surface-600 mb-1 block">Max Marks</label><input type="number" className="input" value={form.max_marks} onChange={e=>setForm(p=>({...p,max_marks:Number(e.target.value)}))} /></div>
          </div>
          <button type="submit" className="btn-primary w-full" disabled={creating}>{creating?'Creating...':'Create Assignment'}</button>
        </form>
      )}
      {submitTarget&&(
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-xl p-6 w-full max-w-md">
            <h3 className="font-bold text-surface-900 mb-1">Submit: {submitTarget.title}</h3>
            <p className="text-sm text-surface-500 mb-4">Upload your assignment file</p>
            <form onSubmit={handleSubmit} className="space-y-4">
              <FileUpload onFileSelect={setSubFile} label="Upload your work" />
              <div className="flex gap-3">
                <button type="submit" className="btn-primary flex-1" disabled={subLoading||!subFile}>{subLoading?'Submitting...':'Submit'}</button>
                <button type="button" className="btn-secondary flex-1" onClick={()=>setSubmitTarget(null)}>Cancel</button>
              </div>
            </form>
          </div>
        </div>
      )}
      {assignments.length===0 ? <div className="text-center py-16 text-surface-400"><p className="text-3xl mb-2">📋</p><p className="text-sm">No assignments yet</p></div>
        : <div className="space-y-4">{assignments.map(a=><AssignmentCard key={a.id} assignment={a} role={role} onSubmit={setSubmitTarget} onGrade={null} />)}</div>}
    </div>
  );
}

// ─── Announcements Tab ───────────────────────────────────────────────────────
function AnnouncementsTab({ subjectId, role }) {
  const [items, setItems] = useState([]);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ title:'', content:'', is_important:false });
  const [loading, setLoading] = useState(false);
  const load = useCallback(() => { announcementAPI.getBySubject(subjectId).then(r => setItems(r.data.announcements)); }, [subjectId]);
  useEffect(() => { load(); }, [load]);
  const handleCreate = async (e) => { e.preventDefault(); setLoading(true); await announcementAPI.create(subjectId, form); setShowForm(false); setForm({title:'',content:'',is_important:false}); load(); setLoading(false); };
  const handleDelete = async (id) => { if(!confirm('Delete this announcement?')) return; await announcementAPI.delete(subjectId, id); setItems(p=>p.filter(a=>a.id!==id)); };
  return (
    <div className="p-5 space-y-4">
      {(role==='faculty'||role==='admin')&&<div className="flex justify-end"><button className="btn-primary text-sm" onClick={()=>setShowForm(p=>!p)}>{showForm?'Cancel':'📢 Post Announcement'}</button></div>}
      {showForm&&(
        <form onSubmit={handleCreate} className="card space-y-3 border-2 border-primary-100">
          <h3 className="font-semibold text-surface-800">New Announcement</h3>
          <input className="input" placeholder="Title*" value={form.title} onChange={e=>setForm(p=>({...p,title:e.target.value}))} required />
          <textarea className="input resize-none" rows={4} placeholder="Content*" value={form.content} onChange={e=>setForm(p=>({...p,content:e.target.value}))} required />
          <label className="flex items-center gap-2 text-sm text-surface-700 cursor-pointer"><input type="checkbox" checked={form.is_important} onChange={e=>setForm(p=>({...p,is_important:e.target.checked}))} className="w-4 h-4 accent-primary-600" />Mark as important</label>
          <button type="submit" className="btn-primary w-full" disabled={loading}>{loading?'Posting...':'Post Announcement'}</button>
        </form>
      )}
      {items.length===0 ? <div className="text-center py-16 text-surface-400"><p className="text-3xl mb-2">📢</p><p className="text-sm">No announcements yet</p></div>
        : <div className="space-y-4">{items.map(a=>(
          <div key={a.id} className={`card border-l-4 ${a.is_important?'border-l-red-500':'border-l-primary-500'}`}>
            <div className="flex items-start justify-between gap-3">
              <div className="flex-1">
                <div className="flex items-center gap-2"><h4 className="font-semibold text-surface-900">{a.title}</h4>{a.is_important&&<span className="badge-red text-[10px]">IMPORTANT</span>}</div>
                <p className="text-sm text-surface-600 mt-2 whitespace-pre-wrap">{a.content}</p>
                <p className="text-xs text-surface-400 mt-3">Posted by {a.created_by_name} · {format(new Date(a.created_at),'MMM d, yyyy h:mm a')}</p>
              </div>
              {(role==='faculty'||role==='admin')&&<button onClick={()=>handleDelete(a.id)} className="text-surface-400 hover:text-red-500 transition-colors p-1"><svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg></button>}
            </div>
          </div>
        ))}</div>}
    </div>
  );
}

// ─── Main Subject Page ────────────────────────────────────────────────────────
const TABS = [
  { id:'chat', label:'Chat', icon:'💬' },
  { id:'notes', label:'Notes', icon:'📚' },
  { id:'assignments', label:'Assignments', icon:'📋' },
  { id:'announcements', label:'Announcements', icon:'📢' },
];

export default function SubjectPage() {
  const { id } = useParams();
  const { user } = useAuth();
  const [subject, setSubject] = useState(null);
  const [activeTab, setActiveTab] = useState('chat');

  useEffect(() => { subjectAPI.getById(id).then(r => setSubject(r.data.subject)); }, [id]);

  if (!subject) return <div className="flex items-center justify-center h-full"><div className="w-8 h-8 border-4 border-primary-600 border-t-transparent rounded-full animate-spin" /></div>;

  const tabContent = {
    chat: <ChatTab subjectId={id} />,
    notes: <NotesTab subjectId={id} role={user?.role} />,
    assignments: <AssignmentsTab subjectId={id} role={user?.role} />,
    announcements: <AnnouncementsTab subjectId={id} role={user?.role} />,
  };

  return (
    <div className="flex flex-col h-full">
      <div className="bg-white border-b border-surface-200 px-6 py-4">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 bg-primary-100 rounded-xl flex items-center justify-center text-primary-700 font-bold text-lg">{subject.name[0]}</div>
          <div><h2 className="font-bold text-surface-900">{subject.name}</h2><p className="text-xs text-surface-500">{subject.code} · {subject.department} · Sem {subject.semester}</p></div>
        </div>
        <Tabs tabs={TABS} active={activeTab} onChange={setActiveTab} />
      </div>
      <div className="flex-1 overflow-hidden">
        {activeTab==='chat' ? <div className="h-full flex flex-col">{tabContent.chat}</div> : <div className="h-full overflow-y-auto">{tabContent[activeTab]}</div>}
      </div>
    </div>
  );
}
