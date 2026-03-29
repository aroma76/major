import { format, isPast, formatDistanceToNow } from 'date-fns';

const statusStyles = { pending:'badge-yellow', submitted:'badge-green', late:'badge-red' };

export default function AssignmentCard({ assignment, onSubmit, onGrade, role }) {
  const isOverdue = isPast(new Date(assignment.deadline));
  const status = assignment.submission_status || 'pending';
  return (
    <div className="card hover:shadow-md transition-all duration-200">
      <div className="flex items-start justify-between gap-3">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap mb-1">
            <h3 className="font-semibold text-surface-900">{assignment.title}</h3>
            {role === 'student' && <span className={statusStyles[status] || 'badge-gray'}>{status}</span>}
            {isOverdue && status === 'pending' && <span className="badge-red">Overdue</span>}
          </div>
          {assignment.description && <p className="text-sm text-surface-500 mt-1 line-clamp-2">{assignment.description}</p>}
        </div>
        <div className="shrink-0 text-right"><p className="text-xs text-surface-400">Max Marks</p><p className="font-bold text-surface-700">{assignment.max_marks}</p></div>
      </div>
      <div className="mt-3 flex items-center justify-between flex-wrap gap-2">
        <div className="flex items-center gap-4 text-xs text-surface-500">
          <span className={`flex items-center gap-1 ${isOverdue && status==='pending' ? 'text-red-600 font-medium' : ''}`}>
            📅 Due: {format(new Date(assignment.deadline), 'MMM d, yyyy h:mm a')}
          </span>
          {!isOverdue && <span className="text-surface-400">{formatDistanceToNow(new Date(assignment.deadline), { addSuffix: true })}</span>}
          {role === 'faculty' && <span>👥 {assignment.submission_count || 0} submissions</span>}
        </div>
        <div className="flex gap-2">
          {role === 'student' && status === 'pending' && <button onClick={() => onSubmit(assignment)} className="btn-primary text-xs px-3 py-1.5">Submit</button>}
          {role === 'student' && status !== 'pending' && <div className="text-xs text-surface-500">{assignment.marks != null ? `Score: ${assignment.marks}/${assignment.max_marks}` : 'Awaiting grade'}</div>}
          {(role === 'faculty' || role === 'admin') && <button onClick={() => onGrade && onGrade(assignment)} className="btn-secondary text-xs px-3 py-1.5">View Submissions</button>}
        </div>
      </div>
      {assignment.feedback && <div className="mt-3 pt-3 border-t border-surface-100"><p className="text-xs text-surface-500 font-medium mb-1">Feedback:</p><p className="text-sm text-surface-700">{assignment.feedback}</p></div>}
    </div>
  );
}
