import { useState, useEffect } from 'react';
import { notificationAPI } from '../services/api';
import { formatDistanceToNow } from 'date-fns';

const typeStyles = {
  assignment:   { icon: '📋', color: 'bg-blue-50 border-blue-200' },
  announcement: { icon: '📢', color: 'bg-purple-50 border-purple-200' },
  grade:        { icon: '⭐', color: 'bg-yellow-50 border-yellow-200' },
  default:      { icon: '🔔', color: 'bg-surface-50 border-surface-200' },
};

export default function NotificationsPage() {
  const [notifications, setNotifications] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => { notificationAPI.getAll().then(r => setNotifications(r.data.notifications)).finally(() => setLoading(false)); }, []);

  const handleMarkAll  = async () => { await notificationAPI.markAllRead(); setNotifications(p => p.map(n => ({ ...n, is_read: true }))); };
  const handleMarkOne  = async (id) => { await notificationAPI.markRead(id); setNotifications(p => p.map(n => n.id === id ? { ...n, is_read: true } : n)); };
  const handleDelete   = async (id) => { await notificationAPI.delete(id); setNotifications(p => p.filter(n => n.id !== id)); };
  const unread = notifications.filter(n => !n.is_read).length;

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-surface-900">Notifications</h1>
          {unread > 0 && <p className="text-sm text-surface-500 mt-0.5">{unread} unread</p>}
        </div>
        {unread > 0 && <button className="btn-secondary text-sm" onClick={handleMarkAll}>Mark all as read</button>}
      </div>
      {loading ? (
        <div className="space-y-3">{[...Array(5)].map((_, i) => <div key={i} className="card animate-pulse flex gap-4 items-start"><div className="w-10 h-10 bg-surface-200 rounded-xl shrink-0" /><div className="flex-1 space-y-2"><div className="h-3 bg-surface-200 rounded w-3/4" /><div className="h-3 bg-surface-100 rounded w-1/2" /></div></div>)}</div>
      ) : notifications.length === 0 ? (
        <div className="text-center py-20"><p className="text-5xl mb-4">🔔</p><h3 className="text-lg font-semibold text-surface-700 mb-2">All caught up!</h3><p className="text-surface-500 text-sm">No notifications yet.</p></div>
      ) : (
        <div className="space-y-2">
          {notifications.map(n => {
            const style = typeStyles[n.type] || typeStyles.default;
            return (
              <div key={n.id} onClick={() => !n.is_read && handleMarkOne(n.id)}
                className={`card border flex gap-4 items-start cursor-pointer transition-all duration-200 ${style.color} ${!n.is_read ? 'shadow-sm' : 'opacity-70'}`}>
                <div className="text-2xl shrink-0">{style.icon}</div>
                <div className="flex-1 min-w-0">
                  <p className={`text-sm ${!n.is_read ? 'font-semibold text-surface-900' : 'text-surface-700'}`}>{n.title}</p>
                  {n.message && <p className="text-xs text-surface-500 mt-0.5 line-clamp-2">{n.message}</p>}
                  <p className="text-[10px] text-surface-400 mt-1.5">{formatDistanceToNow(new Date(n.created_at), { addSuffix: true })}</p>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  {!n.is_read && <div className="w-2 h-2 bg-primary-500 rounded-full" />}
                  <button onClick={e => { e.stopPropagation(); handleDelete(n.id); }} className="text-surface-300 hover:text-red-500 transition-colors p-1">
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg>
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
