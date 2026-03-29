import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

const DEPARTMENTS = ['Engineering', 'Management', 'Pharmacy', 'Arts'];
const SEMESTERS = [1,2,3,4,5,6,7,8];

export default function SignupPage() {
  const { register } = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({ name:'', email:'', password:'', role:'student', department:'', semester:'' });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault(); setLoading(true); setError('');
    try { await register({ ...form, semester: form.semester ? Number(form.semester) : undefined }); navigate('/dashboard'); }
    catch (err) { setError(err.response?.data?.message || 'Registration failed.'); }
    finally { setLoading(false); }
  };

  const field = (key) => ({ value: form[key], onChange: (e) => setForm(p => ({ ...p, [key]: e.target.value })) });

  return (
    <div className="min-h-screen bg-gradient-to-br from-primary-900 via-primary-800 to-indigo-900 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <div className="w-16 h-16 bg-white/10 backdrop-blur rounded-2xl flex items-center justify-center text-white font-bold text-2xl mx-auto mb-4">A</div>
          <h1 className="text-2xl font-bold text-white">ADTU Collab</h1>
          <p className="text-primary-300 text-sm mt-1">Academic Collaboration Platform</p>
        </div>
        <div className="bg-white rounded-2xl shadow-2xl p-8">
          <h2 className="text-xl font-bold text-surface-900 mb-1">Create account</h2>
          <p className="text-surface-500 text-sm mb-6">Join your academic community</p>
          {error && <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-sm mb-5">{error}</div>}
          <form onSubmit={handleSubmit} className="space-y-4">
            <div><label className="text-sm font-medium text-surface-700 block mb-1.5">Full Name</label><input type="text" className="input" placeholder="Rahul Sharma" {...field('name')} required /></div>
            <div><label className="text-sm font-medium text-surface-700 block mb-1.5">Email</label><input type="email" className="input" placeholder="you@adtu.in" {...field('email')} required /></div>
            <div><label className="text-sm font-medium text-surface-700 block mb-1.5">Password</label><input type="password" className="input" placeholder="Min. 8 characters" {...field('password')} required minLength={8} /></div>
            <div className="grid grid-cols-2 gap-3">
              <div><label className="text-sm font-medium text-surface-700 block mb-1.5">Role</label>
                <select className="input" {...field('role')} required>
                  {['student','faculty'].map(r => <option key={r} value={r}>{r.charAt(0).toUpperCase()+r.slice(1)}</option>)}
                </select>
              </div>
              <div><label className="text-sm font-medium text-surface-700 block mb-1.5">Semester</label>
                <select className="input" {...field('semester')}>
                  <option value="">Select</option>
                  {SEMESTERS.map(s => <option key={s} value={s}>Semester {s}</option>)}
                </select>
              </div>
            </div>
            <div><label className="text-sm font-medium text-surface-700 block mb-1.5">Department</label>
              <select className="input" {...field('department')}>
                <option value="">Select Department</option>
                {DEPARTMENTS.map(d => <option key={d} value={d}>{d}</option>)}
              </select>
            </div>
            <button type="submit" className="btn-primary w-full py-3 mt-2" disabled={loading}>{loading ? 'Creating account...' : 'Create Account'}</button>
          </form>
          <p className="text-center text-sm text-surface-500 mt-6">Already have an account? <Link to="/login" className="text-primary-600 font-medium hover:underline">Sign in</Link></p>
        </div>
      </div>
    </div>
  );
}
