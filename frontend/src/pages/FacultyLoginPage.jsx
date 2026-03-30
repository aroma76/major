import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export default function FacultyLoginPage() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({ identifier: '', password: '' });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault(); setLoading(true); setError('');
    try { await login(form.identifier, form.password); navigate('/dashboard'); }
    catch (err) { setError(err.response?.data?.message || 'Login failed. Please verify your credentials.'); }
    finally { setLoading(false); }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-indigo-900 via-surface-900 to-black flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <div className="w-16 h-16 bg-white/10 backdrop-blur border border-white/20 rounded-2xl flex items-center justify-center text-white font-bold text-2xl mx-auto mb-4">
             <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" /></svg>
          </div>
          <h1 className="text-2xl font-bold text-white tracking-widest uppercase">Faculty Portal</h1>
          <p className="text-indigo-200 text-sm mt-1">StudyHub Direct Access</p>
        </div>
        <div className="bg-white rounded-2xl shadow-2xl p-8 border-t-8 border-indigo-600">
          <h2 className="text-xl font-bold text-surface-900 mb-1">Secure Sign In</h2>
          <p className="text-surface-500 text-sm mb-6">Enter your professional credentials</p>
          {error && <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-sm mb-5 font-medium">{error}</div>}
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="text-sm font-bold text-surface-700 block mb-1.5 uppercase tracking-wide">University Email</label>
              <input type="text" className="input bg-surface-50 font-medium" placeholder="faculty@adtu.in" value={form.identifier} onChange={e => setForm(p => ({ ...p, identifier: e.target.value }))} required />
            </div>
            <div>
              <label className="text-sm font-bold text-surface-700 block mb-1.5 uppercase tracking-wide">Password</label>
              <input type="password" className="input bg-surface-50 font-medium" placeholder="Your password" value={form.password} onChange={e => setForm(p => ({ ...p, password: e.target.value }))} required />
            </div>
            <button type="submit" className="w-full py-3 mt-4 bg-indigo-600 hover:bg-indigo-700 text-white font-bold rounded-xl shadow-md transition-colors" disabled={loading}>{loading ? 'Authenticating...' : 'Sign In as Faculty'}</button>
          </form>
          <div className="mt-6 text-center border-t border-surface-100 pt-5">
             <p className="text-sm text-surface-500 mb-2">Are you a student?</p>
             <Link to="/login" className="text-indigo-600 font-bold hover:underline bg-indigo-50 px-4 py-2 rounded-lg inline-block">Go to Student Login</Link>
          </div>
        </div>
        <p className="text-center text-indigo-300 text-xs mt-6 opacity-60 uppercase tracking-widest font-bold">Assam down town University</p>
      </div>
    </div>
  );
}
