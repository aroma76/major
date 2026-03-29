import { useRef, useState } from 'react';

export default function FileUpload({ onFileSelect, accept, label = 'Upload File', hint }) {
  const inputRef = useRef(null);
  const [file, setFile] = useState(null);
  const [dragging, setDragging] = useState(false);

  const handleFile = (f) => { if (!f) return; setFile(f); onFileSelect(f); };
  const handleDrop = (e) => { e.preventDefault(); setDragging(false); handleFile(e.dataTransfer.files[0]); };

  return (
    <div>
      <div onDragOver={e => { e.preventDefault(); setDragging(true); }} onDragLeave={() => setDragging(false)} onDrop={handleDrop} onClick={() => inputRef.current?.click()}
        className={`border-2 border-dashed rounded-xl p-6 text-center cursor-pointer transition-all duration-200 ${dragging ? 'border-primary-500 bg-primary-50' : 'border-surface-200 hover:border-primary-400 hover:bg-surface-50'}`}>
        <svg className="w-8 h-8 text-surface-400 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
        </svg>
        {file
          ? <div><p className="text-sm font-medium text-primary-700">{file.name}</p><p className="text-xs text-surface-500 mt-0.5">{(file.size / 1024).toFixed(1)} KB</p></div>
          : <div><p className="text-sm font-medium text-surface-700">{label}</p><p className="text-xs text-surface-400 mt-1">{hint || 'Drag & drop or click to browse. Max 50MB.'}</p></div>}
      </div>
      <input ref={inputRef} type="file" accept={accept} className="hidden" onChange={e => handleFile(e.target.files[0])} />
      {file && <button type="button" onClick={e => { e.stopPropagation(); setFile(null); onFileSelect(null); }} className="mt-1.5 text-xs text-red-500 hover:underline">Remove file</button>}
    </div>
  );
}
