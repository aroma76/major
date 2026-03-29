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
      socketInstance = io('/', { withCredentials: true, transports: ['websocket', 'polling'] });
    }
    socketRef.current = socketInstance;
    socketInstance.emit('user:join', String(user.id));
  }, [user]);
  return socketRef;
};

export const getSocket = () => socketInstance;
