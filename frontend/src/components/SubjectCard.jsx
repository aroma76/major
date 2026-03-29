import { Link } from 'react-router-dom';

const deptGradients = { Engineering:'from-blue-500 to-indigo-600', Management:'from-purple-500 to-pink-600', Pharmacy:'from-green-500 to-teal-600', Arts:'from-orange-500 to-red-500' };

export default function SubjectCard({ subject }) {
  const gradient = deptGradients[subject.department] || 'from-surface-600 to-surface-800';
  return (
    <Link to={`/subject/${subject.id}`} className="card hover:shadow-md transition-all duration-200 group cursor-pointer p-0 overflow-hidden">
      <div className={`bg-gradient-to-r ${gradient} p-5`}>
        <div className="flex items-start justify-between">
          <div className="w-10 h-10 bg-white/20 rounded-xl flex items-center justify-center text-white font-bold text-lg backdrop-blur-sm">{subject.name[0]}</div>
          <span className="text-white/80 text-xs bg-white/20 px-2 py-0.5 rounded-full font-medium">{subject.code}</span>
        </div>
        <h3 className="text-white font-bold mt-3 text-base leading-snug">{subject.name}</h3>
        <p className="text-white/70 text-xs mt-1">Sem {subject.semester}</p>
      </div>
      <div className="px-5 py-3 bg-white flex items-center justify-between">
        <div className="flex items-center gap-1.5"><div className="w-2 h-2 rounded-full bg-green-400"></div><span className="text-xs text-surface-500">{subject.department}</span></div>
        <span className="text-xs text-surface-400">{subject.faculty_name || 'TBA'}</span>
      </div>
    </Link>
  );
}
