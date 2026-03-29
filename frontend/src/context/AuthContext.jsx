import { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { authAPI } from '../services/api';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(() => { try { const s = localStorage.getItem('adtu_user'); return s ? JSON.parse(s) : null; } catch { return null; } });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem('adtu_token');
    if (!token) { setLoading(false); return; }
    authAPI.getMe()
      .then(res => { setUser(res.data.user); localStorage.setItem('adtu_user', JSON.stringify(res.data.user)); })
      .catch(() => { localStorage.removeItem('adtu_token'); localStorage.removeItem('adtu_user'); setUser(null); })
      .finally(() => setLoading(false));
  }, []);

  const login = useCallback(async (email, password) => {
    const res = await authAPI.login({ email, password });
    const { token, user } = res.data;
    localStorage.setItem('adtu_token', token); localStorage.setItem('adtu_user', JSON.stringify(user)); setUser(user); return user;
  }, []);

  const register = useCallback(async (formData) => {
    const res = await authAPI.register(formData);
    const { token, user } = res.data;
    localStorage.setItem('adtu_token', token); localStorage.setItem('adtu_user', JSON.stringify(user)); setUser(user); return user;
  }, []);

  const logout = useCallback(() => { localStorage.removeItem('adtu_token'); localStorage.removeItem('adtu_user'); setUser(null); }, []);
  const updateUser = useCallback((u) => { setUser(u); localStorage.setItem('adtu_user', JSON.stringify(u)); }, []);

  return <AuthContext.Provider value={{ user, loading, login, register, logout, updateUser }}>{children}</AuthContext.Provider>;
};

export const useAuth = () => { const ctx = useContext(AuthContext); if (!ctx) throw new Error('useAuth must be within AuthProvider'); return ctx; };
