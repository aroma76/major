import { Link, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useState, useEffect } from 'react';
import { notificationAPI } from '../services/api';

export default function Navbar() {
  const { user, logout } = useAuth();
  const location = useLocation();
  const [unread, setUnread] = useState(0);
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    notificationAPI.getUnreadCount().then(r => setUnread(r.data.count)).catch(() => {});
  }, [location]);

  const initials = user?.name?.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2) || '?';
  const roleBadge = { student: 'badge-blue', faculty: 'badge-green', admin: 'badge-red' }[user?.role] || 'badge-gray';

  return (
    <header className="bg-white border-b border-surface-200 px-4 py-3 flex items-center justify-between sticky top-0 z-30">
      <div className="flex items-center gap-3">
        <div className="w-8 h-8 bg-gradient-to-br from-primary-600 to-primary-800 rounded-lg flex items-center justify-center text-white font-bold text-sm">A</div>
        <span className="font-bold text-surface-900 hidden sm:block">ADTU Collab</span>
      </div>
      <div className="flex items-center gap-3">
        <Link to="/notifications" className="relative p-2 rounded-lg hover:bg-surface-100 transition-colors">
          <svg className="w-5 h-5 text-surface-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
          </svg>
          {unread > 0 && <span className="absolute -top-0.5 -right-0.5 bg-red-500 text-white text-[10px] rounded-full w-4 h-4 flex items-center justify-center font-bold">{unread > 9 ? '9+' : unread}</span>}
        </Link>
        <div className="relative">
          <button onClick={() => setMenuOpen(p => !p)} className="flex items-center gap-2 p-1.5 rounded-lg hover:bg-surface-100 transition-colors">
            {user?.avatar_url
              ? <img src={user.avatar_url} alt={user.name} className="w-8 h-8 rounded-full object-cover" />
              : <div className="w-8 h-8 rounded-full bg-primary-600 text-white text-xs font-bold flex items-center justify-center">{initials}</div>}
            <div className="hidden md:block text-left">
              <p className="text-sm font-medium text-surface-900 leading-none">{user?.name}</p>
              <span className={`${roleBadge} mt-0.5 text-[10px]`}>{user?.role}</span>
            </div>
          </button>
          {menuOpen && (
            <div className="absolute right-0 top-full mt-2 w-44 bg-white rounded-xl shadow-lg border border-surface-100 py-1 z-50">
              <Link to="/profile" className="flex items-center gap-2 px-4 py-2.5 text-sm text-surface-700 hover:bg-surface-50" onClick={() => setMenuOpen(false)}>
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" /></svg>
                Profile
              </Link>
              <hr className="border-surface-100 my-1" />
              <button onClick={() => { logout(); setMenuOpen(false); }} className="flex w-full items-center gap-2 px-4 py-2.5 text-sm text-red-600 hover:bg-red-50">
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" /></svg>
                Sign out
              </button>
            </div>
          )}
        </div>
      </div>
    </header>
  );
}
