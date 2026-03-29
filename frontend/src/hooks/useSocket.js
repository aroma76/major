import { useEffect, useRef } from 'react';
import { io } from 'socket.io-client';
import { useAuth } from '../context/AuthContext';

let socketInstance = null;

export const useSocket = () => {
  const { user } = useAuth();
  const socketRef = useRef(null);
  useEffect(() => {
    if (!user) return;
    if (!socketInstance) {
      const socketUrl = import.meta.env.VITE_API_URL || 'https://major-gin9.onrender.com';
      socketInstance = io(socketUrl, { withCredentials: true, transports: ['websocket', 'polling'] });
    }
    socketRef.current = socketInstance;
    socketInstance.emit('user:join', String(user.id));
  }, [user]);
  return socketRef;
};

export const getSocket = () => socketInstance;
