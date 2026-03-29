import { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { subjectAPI } from '../services/api';
import SubjectCard from '../components/SubjectCard';

export default function DashboardPage() {
  const { user } = useAuth();
  const [subjects, setSubjects] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');

  useEffect(() => {
    subjectAPI.getAll().then(r => setSubjects(r.data.subjects)).catch(console.error).finally(() => setLoading(false));
  }, []);

  const filtered = subjects.filter(s =>
    s.name.toLowerCase().includes(search.toLowerCase()) ||
    s.code.toLowerCase().includes(search.toLowerCase()) ||
    s.department.toLowerCase().includes(search.toLowerCase())
  );

  const hour = new Date().getHours();
  const greeting = hour < 12 ? 'morning' : hour < 17 ? 'afternoon' : 'evening';

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-surface-900">Good {greeting}, {user?.name?.split(' ')[0]} 👋</h1>
        <p className="text-surface-500 mt-1 text-sm">{user?.department} · Semester {user?.semester} · {subjects.length} subject{subjects.length !== 1 ? 's' : ''}</p>
      </div>
      <div className="relative mb-6 max-w-sm">
        <svg className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-surface-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
        <input className="input pl-9" placeholder="Search subjects..." value={search} onChange={e => setSearch(e.target.value)} />
      </div>
      {loading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {[...Array(6)].map((_, i) => <div key={i} className="card animate-pulse p-0 overflow-hidden"><div className="h-28 bg-surface-200" /><div className="p-5 space-y-2"><div className="h-3 bg-surface-200 rounded w-3/4" /><div className="h-3 bg-surface-100 rounded w-1/2" /></div></div>)}
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-20"><div className="text-5xl mb-4">📚</div><h3 className="text-lg font-semibold text-surface-700 mb-2">{search ? 'No subjects found' : 'No subjects yet'}</h3><p className="text-surface-500 text-sm">{search ? 'Try a different search term.' : 'You will be enrolled by your faculty or admin.'}</p></div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {filtered.map(s => <SubjectCard key={s.id} subject={s} />)}
        </div>
      )}
    </div>
  );
}
