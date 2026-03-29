import { NavLink, useLocation } from 'react-router-dom';
import { useState, useEffect } from 'react';
import { subjectAPI } from '../services/api';
import { useAuth } from '../context/AuthContext';

const navItems = [
  { to: '/dashboard', label: 'Dashboard', icon: <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" /></svg> },
  { to: '/notifications', label: 'Notifications', icon: <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" /></svg> },
  { to: '/profile', label: 'Profile', icon: <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" /></svg> },
];

const deptColors = { Engineering: 'bg-blue-100 text-blue-700', Management: 'bg-purple-100 text-purple-700', Pharmacy: 'bg-green-100 text-green-700', Arts: 'bg-orange-100 text-orange-700' };

export default function Sidebar() {
  const { user } = useAuth();
  const [subjects, setSubjects] = useState([]);
  const location = useLocation();

  useEffect(() => {
    subjectAPI.getAll().then(r => setSubjects(r.data.subjects.slice(0, 8))).catch(() => {});
  }, [location.pathname]);

  return (
    <aside className="hidden md:flex flex-col w-60 bg-white border-r border-surface-200 h-full overflow-y-auto">
      <div className="px-5 py-5 border-b border-surface-100">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 bg-gradient-to-br from-primary-600 to-primary-800 rounded-xl flex items-center justify-center text-white font-bold">A</div>
          <div>
            <p className="font-bold text-surface-900 text-sm">ADTU Collab</p>
            <p className="text-xs text-surface-500">{user?.department || 'Student'}</p>
          </div>
        </div>
      </div>
      <nav className="px-3 py-4 space-y-1">
        {navItems.map(item => (
          <NavLink key={item.to} to={item.to} className={({ isActive }) => `flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${isActive ? 'bg-primary-50 text-primary-700' : 'text-surface-600 hover:bg-surface-50 hover:text-surface-900'}`}>
            {item.icon}{item.label}
          </NavLink>
        ))}
      </nav>
      {subjects.length > 0 && (
        <div className="px-3 py-2 flex-1">
          <p className="text-xs font-semibold text-surface-400 uppercase tracking-wider px-3 mb-2">My Subjects</p>
          <div className="space-y-0.5">
            {subjects.map(sub => (
              <NavLink key={sub.id} to={`/subject/${sub.id}`} className={({ isActive }) => `flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm transition-colors truncate ${isActive ? 'bg-primary-50 text-primary-700 font-medium' : 'text-surface-600 hover:bg-surface-50'}`}>
                <span className={`w-6 h-6 rounded text-xs flex items-center justify-center font-bold shrink-0 ${deptColors[sub.department] || 'bg-surface-100 text-surface-600'}`}>{sub.name[0]}</span>
                <span className="truncate">{sub.name}</span>
              </NavLink>
            ))}
          </div>
        </div>
      )}
    </aside>
  );
}
