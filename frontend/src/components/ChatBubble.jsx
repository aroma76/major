import { format } from 'date-fns';
import { useAuth } from '../context/AuthContext';

export default function ChatBubble({ message, onPin }) {
  const { user } = useAuth();
  const isMine = message.sender_id === user?.id;
  const isFaculty = message.sender_role === 'faculty' || message.sender_role === 'admin';
  const initials = message.sender_name?.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2) || '?';
  const ext = message.file_name?.split('.').pop()?.toLowerCase();
  const isImage = ['jpg','jpeg','png','gif','webp'].includes(ext);

  return (
    <div className={`flex items-end gap-2 msg-appear ${isMine ? 'flex-row-reverse' : 'flex-row'}`}>
      {!isMine && (
        <div className={`w-7 h-7 rounded-full flex items-center justify-center text-white text-xs font-bold shrink-0 mb-1 ${isFaculty ? 'bg-green-600' : 'bg-primary-500'}`}>
          {message.sender_avatar ? <img src={message.sender_avatar} alt="" className="w-7 h-7 rounded-full object-cover" /> : initials}
        </div>
      )}
      <div className={`max-w-xs md:max-w-md xl:max-w-lg ${isMine ? 'items-end' : 'items-start'} flex flex-col gap-1`}>
        {!isMine && <span className={`text-xs font-semibold px-1 ${isFaculty ? 'text-green-700' : 'text-surface-500'}`}>{message.sender_name} {isFaculty && '• Faculty'}</span>}
        <div className={`group relative rounded-2xl px-3.5 py-2 shadow-sm ${isMine ? 'bg-primary-600 text-white rounded-br-sm' : isFaculty ? 'bg-green-50 border border-green-200 text-surface-900 rounded-bl-sm' : 'bg-white border border-surface-100 text-surface-900 rounded-bl-sm'}`}>
          {message.is_pinned && <span className="text-xs opacity-70 flex items-center gap-1 mb-1">📌 Pinned</span>}
          {message.content && <p className="text-sm leading-relaxed whitespace-pre-wrap">{message.content}</p>}
          {message.file_url && (
            <div className="mt-1">
              {isImage
                ? <img src={message.file_url} alt={message.file_name} className="rounded-lg max-w-[220px] max-h-40 object-cover cursor-pointer" onClick={() => window.open(message.file_url)} />
                : <a href={message.file_url} target="_blank" rel="noreferrer" className={`flex items-center gap-2 text-xs underline ${isMine ? 'text-blue-200' : 'text-primary-600'}`}>📎 {message.file_name || 'Attachment'}</a>}
            </div>
          )}
          {onPin && <button onClick={() => onPin(message.id)} className="absolute -top-2 -right-2 hidden group-hover:flex w-6 h-6 bg-white border border-surface-200 rounded-full items-center justify-center text-[10px] shadow-sm hover:bg-surface-50">📌</button>}
        </div>
        <span className={`text-[10px] text-surface-400 px-1 ${isMine ? 'text-right' : ''}`}>{format(new Date(message.created_at), 'h:mm a')}</span>
      </div>
    </div>
  );
}
