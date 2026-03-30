import axios from 'axios';

const api = axios.create({ baseURL: (import.meta.env.VITE_API_URL || 'http://localhost:5000') + '/api', headers: { 'Content-Type': 'application/json' } });

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('adtu_token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

api.interceptors.response.use((res) => res, (err) => {
  if (err.response?.status === 401) {
    localStorage.removeItem('adtu_token');
    localStorage.removeItem('adtu_user');
    if (window.location.pathname !== '/login' && window.location.pathname !== '/signup') {
      window.location.href = '/login';
    }
  }
  return Promise.reject(err);
});

export const authAPI = {
  register: (data) => api.post('/auth/register', data),
  login: (data) => api.post('/auth/login', data),
  getMe: () => api.get('/auth/me'),
  updateProfile: (data) => api.put('/auth/profile', data, { headers: { 'Content-Type': 'multipart/form-data' } }),
};
export const channelAPI = {
  getAll: () => api.get('/channels'),
  getById: (id) => api.get(`/channels/${id}`),
  create: (data) => api.post('/channels', data),
  update: (id, data) => api.put(`/channels/${id}`, data),
  delete: (id) => api.delete(`/channels/${id}`),
  getMembers: (id) => api.get(`/channels/${id}/members`),
};
export const enrollmentAPI = {
  enroll: (data) => api.post('/enrollments', data),
  unenroll: (data) => api.delete('/enrollments', { data }),
  getMy: () => api.get('/enrollments/my'),
  bulkEnroll: (data) => api.post('/enrollments/bulk', data),
};
export const messageAPI = {
  getByChannel: (sid) => api.get(`/channels/${sid}/messages`),
  send: (sid, data) => api.post(`/channels/${sid}/messages`, data, { headers: { 'Content-Type': 'multipart/form-data' } }),
  getPinned: (sid) => api.get(`/channels/${sid}/messages/pinned`),
  pin: (sid, mid) => api.put(`/channels/${sid}/messages/${mid}/pin`),
  delete: (sid, mid) => api.delete(`/channels/${sid}/messages/${mid}`),
};
export const fileAPI = {
  getByChannel: (sid, params) => api.get(`/channels/${sid}/files`, { params }),
  upload: (sid, data) => api.post(`/channels/${sid}/files`, data, { headers: { 'Content-Type': 'multipart/form-data' } }),
  delete: (sid, nid) => api.delete(`/channels/${sid}/files/${nid}`),
};
export const assignmentAPI = {
  getByChannel: (sid) => api.get(`/channels/${sid}/assignments`),
  create: (sid, data) => api.post(`/channels/${sid}/assignments`, data),
  update: (sid, id, data) => api.put(`/channels/${sid}/assignments/${id}`, data),
  delete: (sid, id) => api.delete(`/channels/${sid}/assignments/${id}`),
  submit: (sid, id, data) => api.post(`/channels/${sid}/assignments/${id}/submit`, data, { headers: { 'Content-Type': 'multipart/form-data' } }),
  getSubmissions: (sid, id) => api.get(`/channels/${sid}/assignments/${id}/submissions`),
  getMySubmission: (sid, id) => api.get(`/channels/${sid}/assignments/${id}/my-submission`),
  grade: (sid, subId, data) => api.put(`/channels/${sid}/assignments/submissions/${subId}/grade`, data),
};
export const announcementAPI = {
  getByChannel: (sid) => api.get(`/channels/${sid}/announcements`),
  create: (sid, data) => api.post(`/channels/${sid}/announcements`, data),
  delete: (sid, id) => api.delete(`/channels/${sid}/announcements/${id}`),
};
export const notificationAPI = {
  getAll: () => api.get('/notifications'),
  getUnreadCount: () => api.get('/notifications/unread-count'),
  markRead: (id) => api.put(`/notifications/${id}/read`),
  markAllRead: () => api.put('/notifications/read-all'),
  delete: (id) => api.delete(`/notifications/${id}`),
};
export const notesAPI = {
  getByChannel: (sid) => api.get(`/channels/${sid}/notes`),
  create: (sid, data) => api.post(`/channels/${sid}/notes`, data),
  delete: (sid, nid) => api.delete(`/channels/${sid}/notes/${nid}`),
};

export default api;
