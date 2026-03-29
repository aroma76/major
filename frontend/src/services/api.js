import axios from 'axios';

const api = axios.create({ baseURL: (import.meta.env.VITE_API_URL || 'https://major-gin9.onrender.com') + '/api', headers: { 'Content-Type': 'application/json' } });

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('adtu_token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

api.interceptors.response.use((res) => res, (err) => {
  if (err.response?.status === 401) {
    localStorage.removeItem('adtu_token');
    localStorage.removeItem('adtu_user');
    window.location.href = '/login';
  }
  return Promise.reject(err);
});

export const authAPI = {
  register: (data) => api.post('/auth/register', data),
  login: (data) => api.post('/auth/login', data),
  getMe: () => api.get('/auth/me'),
  updateProfile: (data) => api.put('/auth/profile', data, { headers: { 'Content-Type': 'multipart/form-data' } }),
};
export const subjectAPI = {
  getAll: () => api.get('/subjects'),
  getById: (id) => api.get(`/subjects/${id}`),
  create: (data) => api.post('/subjects', data),
  update: (id, data) => api.put(`/subjects/${id}`, data),
  delete: (id) => api.delete(`/subjects/${id}`),
  getMembers: (id) => api.get(`/subjects/${id}/members`),
};
export const enrollmentAPI = {
  enroll: (data) => api.post('/enrollments', data),
  unenroll: (data) => api.delete('/enrollments', { data }),
  getMy: () => api.get('/enrollments/my'),
  bulkEnroll: (data) => api.post('/enrollments/bulk', data),
};
export const messageAPI = {
  getBySubject: (sid) => api.get(`/subjects/${sid}/messages`),
  send: (sid, data) => api.post(`/subjects/${sid}/messages`, data, { headers: { 'Content-Type': 'multipart/form-data' } }),
  getPinned: (sid) => api.get(`/subjects/${sid}/messages/pinned`),
  pin: (sid, mid) => api.put(`/subjects/${sid}/messages/${mid}/pin`),
  delete: (sid, mid) => api.delete(`/subjects/${sid}/messages/${mid}`),
};
export const noteAPI = {
  getBySubject: (sid, params) => api.get(`/subjects/${sid}/notes`, { params }),
  upload: (sid, data) => api.post(`/subjects/${sid}/notes`, data, { headers: { 'Content-Type': 'multipart/form-data' } }),
  delete: (sid, nid) => api.delete(`/subjects/${sid}/notes/${nid}`),
};
export const assignmentAPI = {
  getBySubject: (sid) => api.get(`/subjects/${sid}/assignments`),
  create: (sid, data) => api.post(`/subjects/${sid}/assignments`, data),
  update: (sid, id, data) => api.put(`/subjects/${sid}/assignments/${id}`, data),
  delete: (sid, id) => api.delete(`/subjects/${sid}/assignments/${id}`),
  submit: (sid, id, data) => api.post(`/subjects/${sid}/assignments/${id}/submit`, data, { headers: { 'Content-Type': 'multipart/form-data' } }),
  getSubmissions: (sid, id) => api.get(`/subjects/${sid}/assignments/${id}/submissions`),
  getMySubmission: (sid, id) => api.get(`/subjects/${sid}/assignments/${id}/my-submission`),
  grade: (sid, subId, data) => api.put(`/subjects/${sid}/assignments/submissions/${subId}/grade`, data),
};
export const announcementAPI = {
  getBySubject: (sid) => api.get(`/subjects/${sid}/announcements`),
  create: (sid, data) => api.post(`/subjects/${sid}/announcements`, data),
  delete: (sid, id) => api.delete(`/subjects/${sid}/announcements/${id}`),
};
export const notificationAPI = {
  getAll: () => api.get('/notifications'),
  getUnreadCount: () => api.get('/notifications/unread-count'),
  markRead: (id) => api.put(`/notifications/${id}/read`),
  markAllRead: () => api.put('/notifications/read-all'),
  delete: (id) => api.delete(`/notifications/${id}`),
};

export default api;
