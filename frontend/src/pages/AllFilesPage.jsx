import { useState, useEffect } from 'react';
import { channelAPI, fileAPI } from '../services/api';

function fileIcon(name) {
  const ext = name.split('.').pop().toLowerCase();
  if (['pdf'].includes(ext)) return { label: 'PDF', cls: 'icon-pdf' };
  if (['doc', 'docx'].includes(ext)) return { label: 'DOC', cls: 'icon-doc' };
  if (['png', 'jpg', 'jpeg'].includes(ext)) return { label: 'IMG', cls: 'icon-img' };
  return { label: 'FILE', cls: 'icon-file' };
}
function fmtSize(bytes) {
  if (!bytes) return '';
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1048576) return (bytes/1024).toFixed(0)+' KB';
  return (bytes/1048576).toFixed(1)+' MB';
}

export default function AllFilesPage() {
  const [allFiles, setAllFiles] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchAllFiles = async () => {
      try {
        const { data } = await channelAPI.getAll();
        const channels = data.channels || [];
        
        const filesPromises = channels.map(async ch => {
          const res = await fileAPI.getByChannel(ch.id);
          // Attach channel info to files so we know where they came from
          return (res.data.files || []).map(f => ({ ...f, channel_name: ch.subject_name }));
        });

        const nestedFiles = await Promise.all(filesPromises);
        const flattened = nestedFiles.flat().sort((a,b) => new Date(b.created_at) - new Date(a.created_at));
        setAllFiles(flattened);
      } catch (err) { }
      setLoading(false);
    };
    fetchAllFiles();
  }, []);

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: '#0D0F14', overflowY: 'auto' }}>
      <div style={{ padding: '24px 32px', borderBottom: '1px solid rgba(255,255,255,0.05)', background: '#13161E' }}>
        <h1 style={{ margin: 0, fontSize: 24, fontWeight: 700, color: '#F0F0F5', fontFamily: 'Syne, sans-serif' }}>All Files</h1>
        <div style={{ fontSize: 13, color: '#5A6070', marginTop: 4 }}>Recent materials uploaded across all your subjects.</div>
      </div>
      
      <div style={{ padding: 32 }}>
        {loading ? (
          <div style={{ color: '#5A6070' }}>Loading files...</div>
        ) : allFiles.length === 0 ? (
          <div style={{ color: '#5A6070', textAlign: 'center', padding: '40px 0' }}>No files found across any subjects.</div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: 16 }}>
            {allFiles.map(f => {
              const fi = fileIcon(f.file_url || f.file_name || '');
              return (
                <div key={f.id} style={{ background: '#13161E', border: '1px solid rgba(255,255,255,0.05)', borderRadius: 14, padding: '20px', display: 'flex', gap: 16, alignItems: 'center' }}>
                  <div className={fi.cls} style={{ width: 48, height: 48, borderRadius: 12, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 14, fontWeight: 700, flexShrink: 0 }}>
                    {fi.label}
                  </div>
                  <div style={{ flex: 1, overflow: 'hidden' }}>
                    <div style={{ fontSize: 14, fontWeight: 600, color: '#F0F0F5', whiteSpace: 'nowrap', textOverflow: 'ellipsis', overflow: 'hidden', marginBottom: 4 }}>
                      <a href={f.file_url} target="_blank" rel="noreferrer" style={{ color: 'inherit', textDecoration: 'none' }}>{f.file_name}</a>
                    </div>
                    <div style={{ fontSize: 12, color: '#5A6070', marginBottom: 4 }}>{f.channel_name}</div>
                    <div style={{ fontSize: 11, color: '#5A6070' }}>{fmtSize(f.file_size)} · Uploaded by {f.uploaded_by_name}</div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
