import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export default function LoginPage() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({ identifier: '', password: '' });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true); setError('');
    try {
      await login(form.identifier, form.password);
      navigate('/dashboard');
    } catch (err) {
      setError(err.response?.data?.message || 'Login failed. Check your credentials.');
    } finally { setLoading(false); }
  };

  return (
    <div style={{ minHeight: '100vh', background: 'var(--bg)', display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative', overflow: 'hidden' }}>
      {/* Orbs */}
      <div className="animate-pulse-orb" style={{ position: 'absolute', width: 600, height: 600, borderRadius: '50%', background: 'radial-gradient(circle, rgba(108,99,255,0.18) 0%, transparent 70%)', top: -200, left: -100, pointerEvents: 'none' }} />
      <div className="animate-pulse-orb-rev" style={{ position: 'absolute', width: 500, height: 500, borderRadius: '50%', background: 'radial-gradient(circle, rgba(78,205,196,0.12) 0%, transparent 70%)', bottom: -150, right: -100, pointerEvents: 'none' }} />
      {/* Grid */}
      <div style={{ position: 'absolute', inset: 0, backgroundImage: 'linear-gradient(rgba(255,255,255,0.025) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.025) 1px, transparent 1px)', backgroundSize: '48px 48px', pointerEvents: 'none' }} />

      <div className="animate-slideUp" style={{ position: 'relative', zIndex: 1, width: 420, background: 'var(--bg2)', border: '1px solid var(--border2)', borderRadius: 20, padding: '40px 40px 36px' }}>
        {/* Logo */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 32 }}>
          <div style={{ width: 36, height: 36, background: 'linear-gradient(135deg, #6C63FF, #4ECDC4)', borderRadius: 10, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <svg viewBox="0 0 18 18" fill="none" style={{ width: 18, height: 18 }}>
              <rect x="2" y="2" width="6" height="6" rx="1.5" fill="white" fillOpacity="0.9"/>
              <rect x="10" y="2" width="6" height="6" rx="1.5" fill="white" fillOpacity="0.6"/>
              <rect x="2" y="10" width="6" height="6" rx="1.5" fill="white" fillOpacity="0.6"/>
              <rect x="10" y="10" width="6" height="6" rx="1.5" fill="white" fillOpacity="0.3"/>
            </svg>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            <div style={{ fontSize: 11, fontWeight: 600, color: '#4ECDC4', letterSpacing: '1.5px', textTransform: 'uppercase' }}>AdtU</div>
            <div style={{ fontSize: 10, color: 'var(--text3)', letterSpacing: '0.3px' }}>Academic Portal</div>
          </div>
        </div>

        <div className="font-syne" style={{ fontSize: 26, fontWeight: 700, lineHeight: 1.2, marginBottom: 6, letterSpacing: '-0.5px' }}>Welcome back</div>
        <div style={{ fontSize: 13.5, color: 'var(--text2)', marginBottom: 28, lineHeight: 1.5 }}>Sign in with your AdtU credentials to continue</div>

        {error && (
          <div style={{ background: 'rgba(255,107,107,0.1)', border: '1px solid rgba(255,107,107,0.25)', color: '#FF6B6B', padding: '10px 14px', borderRadius: 8, fontSize: 13, marginBottom: 16 }}>
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit}>
          <div style={{ marginBottom: 16 }}>
            <label style={{ display: 'block', fontSize: 12, fontWeight: 500, color: 'var(--text2)', marginBottom: 7, letterSpacing: '0.3px', textTransform: 'uppercase' }}>Roll Number or Email</label>
            <input
              type="text"
              placeholder="e.g. ADTU/2024/BTECH-CSE/001 or you@adtu.in"
              value={form.identifier}
              onChange={e => setForm(p => ({ ...p, identifier: e.target.value }))}
              required
              style={{ width: '100%', background: 'var(--bg3)', border: '1px solid var(--border2)', borderRadius: 8, padding: '11px 14px', fontSize: 14, fontFamily: 'DM Sans, sans-serif', color: 'var(--text)', outline: 'none' }}
              onFocus={e => e.target.style.borderColor = '#6C63FF'}
              onBlur={e => e.target.style.borderColor = 'var(--border2)'}
            />
          </div>

          <div style={{ marginBottom: 16 }}>
            <label style={{ display: 'block', fontSize: 12, fontWeight: 500, color: 'var(--text2)', marginBottom: 7, letterSpacing: '0.3px', textTransform: 'uppercase' }}>Password</label>
            <input
              type="password"
              placeholder="Your password"
              value={form.password}
              onChange={e => setForm(p => ({ ...p, password: e.target.value }))}
              required
              style={{ width: '100%', background: 'var(--bg3)', border: '1px solid var(--border2)', borderRadius: 8, padding: '11px 14px', fontSize: 14, fontFamily: 'DM Sans, sans-serif', color: 'var(--text)', outline: 'none' }}
              onFocus={e => e.target.style.borderColor = '#6C63FF'}
              onBlur={e => e.target.style.borderColor = 'var(--border2)'}
            />
            <div style={{ fontSize: 11, color: 'var(--text3)', marginTop: 5 }}>Use your university password or date of birth (YYYY-MM-DD)</div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="font-syne"
            style={{ width: '100%', padding: '13px', background: 'var(--accent)', border: 'none', borderRadius: 8, fontSize: 15, fontWeight: 600, color: '#fff', cursor: loading ? 'not-allowed' : 'pointer', marginTop: 8, opacity: loading ? 0.7 : 1, transition: 'opacity 0.2s', letterSpacing: '0.2px' }}
          >
            {loading ? 'Signing in...' : 'Sign In'}
          </button>
        </form>

        <div style={{ display: 'flex', alignItems: 'center', gap: 12, margin: '20px 0 16px' }}>
          <div style={{ flex: 1, height: 1, background: 'var(--border)' }} />
          <span style={{ fontSize: 11, color: 'var(--text3)' }}>or</span>
          <div style={{ flex: 1, height: 1, background: 'var(--border)' }} />
        </div>

        <Link to="/faculty-login" style={{ textDecoration: 'none' }}>
          <button style={{ width: '100%', padding: '11px', background: 'transparent', border: '1px solid var(--border2)', borderRadius: 8, fontFamily: 'DM Sans, sans-serif', fontSize: 13.5, color: 'var(--text2)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, transition: 'background 0.2s' }}
            onMouseEnter={e => e.currentTarget.style.background = 'var(--bg3)'}
            onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/></svg>
            Sign in as Faculty / Admin
          </button>
        </Link>

        <div style={{ textAlign: 'center', marginTop: 24, fontSize: 11, color: 'var(--text3)' }}>
          Part of Assam down town University · <a href="https://adtu.in" target="_blank" rel="noreferrer" style={{ color: 'var(--accent2)', textDecoration: 'none' }}>adtu.in</a>
        </div>
      </div>
    </div>
  );
}
