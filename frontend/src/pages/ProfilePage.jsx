import { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { authAPI } from '../services/api';
import FileUpload from '../components/FileUpload';

export default function ProfilePage() {
  const { user, updateUser } = useAuth();
  const [form, setForm] = useState({ name: user?.name || '' });
  const [avatar, setAvatar] = useState(null);
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState('');
  const [error, setError] = useState('');

  const initials = user?.name?.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2) || '?';
  const roleBadge = { student: 'bg-blue-100 text-blue-700', faculty: 'bg-green-100 text-green-700', admin: 'bg-red-100 text-red-700' }[user?.role] || 'bg-surface-100 text-surface-600';

  const handleSubmit = async (e) => {
    e.preventDefault(); setLoading(true); setSuccess(''); setError('');
    try {
      const fd = new FormData();
      Object.entries(form).forEach(([k, v]) => v && fd.append(k, v));
      if (avatar) fd.append('avatar', avatar);
      const res = await authAPI.updateProfile(fd);
      updateUser(res.data.user);
      setSuccess('Profile updated successfully!');
    } catch (err) { setError(err.response?.data?.message || 'Update failed'); }
    finally { setLoading(false); }
  };

  return (
    <div className="p-6 max-w-xl mx-auto">
      <h1 className="text-2xl font-bold text-surface-900 mb-6">My Profile</h1>
      <div className="card mb-6 flex items-center gap-5">
        <div className="relative shrink-0">
          {user?.avatar_url
            ? <img src={user.avatar_url} alt={user.name} className="w-20 h-20 rounded-full object-cover border-4 border-primary-100" />
            : <div className="w-20 h-20 rounded-full bg-primary-600 flex items-center justify-center text-white text-2xl font-bold border-4 border-primary-100">{initials}</div>}
        </div>
        <div>
          <h2 className="text-lg font-bold text-surface-900">{user?.name}</h2>
          <p className="text-sm text-surface-500">{user?.roll_number} • {user?.email}</p>
          <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium mt-1.5 ${roleBadge}`}>{user?.role}</span>
        </div>
      </div>
      <div className="card">
        <h3 className="font-semibold text-surface-800 mb-4">Edit Profile</h3>
        {success && <div className="bg-green-50 border border-green-200 text-green-700 px-4 py-3 rounded-lg text-sm mb-4">{success}</div>}
        {error && <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-sm mb-4">{error}</div>}
        <form onSubmit={handleSubmit} className="space-y-4">
          <div><label className="text-sm font-medium text-surface-700 block mb-1.5">Full Name</label><input className="input" value={form.name} onChange={e => setForm(p => ({ ...p, name: e.target.value }))} /></div>
          <div><label className="text-sm font-medium text-surface-700 block mb-1.5">Profile Photo</label><FileUpload onFileSelect={setAvatar} accept="image/*" label="Upload a photo" hint="JPG, PNG up to 5MB" /></div>
          <button type="submit" className="btn-primary w-full py-3" disabled={loading}>{loading ? 'Saving...' : 'Save Changes'}</button>
        </form>
        <div className="mt-6 pt-4 border-t border-surface-100 grid grid-cols-2 gap-4 text-sm">
          <div><p className="text-surface-400 text-xs mb-0.5">Email</p><p className="text-surface-700 font-medium">{user?.email}</p></div>
          <div><p className="text-surface-400 text-xs mb-0.5">Role</p><p className="text-surface-700 font-medium capitalize">{user?.role}</p></div>
        </div>
      </div>
    </div>
  );
}
