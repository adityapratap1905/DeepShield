import React, { useEffect, useRef, useState } from 'react';
import {
  Activity,
  AlertTriangle,
  CheckCircle2,
  Clock3,
  Download,
  FileJson,
  History,
  Image as ImageIcon,
  Infinity,
  Info,
  KeyRound,
  LayoutDashboard,
  LogOut,
  Search,
  ScanLine,
  Server,
  ShieldAlert,
  Upload,
  Video,
  X,
} from 'lucide-react';
import { BackendHealth, DashboardTab, MediaScanResult, UserProfile } from '../types/forensics';

interface DashboardLayoutProps {
  user: UserProfile;
  onLogout: () => void | Promise<void>;
}

const TOKEN_KEY = 'deepshield_web_access_token';
const IMAGE_LIMIT = 15 * 1024 * 1024;
const VIDEO_LIMIT = 200 * 1024 * 1024;

const tabs: { id: DashboardTab; label: string; icon: React.ReactNode }[] = [
  { id: 'overview', label: 'Overview', icon: <LayoutDashboard size={17} /> },
  { id: 'scanner', label: 'Media scanner', icon: <ScanLine size={17} /> },
  { id: 'history', label: 'Scan history', icon: <History size={17} /> },
  { id: 'benchmarks', label: 'Model status', icon: <Activity size={17} /> },
  { id: 'api', label: 'API details', icon: <KeyRound size={17} /> },
];

function readHistory(userId: string): MediaScanResult[] {
  try {
    const value = JSON.parse(localStorage.getItem(`deepshield_web_scans_${userId}`) || '[]');
    return Array.isArray(value) ? value as MediaScanResult[] : [];
  } catch {
    return [];
  }
}

function readableError(payload: unknown, fallback: string): string {
  if (!payload || typeof payload !== 'object') return fallback;
  const body = payload as Record<string, unknown>;
  const detail = body.detail || body.error;
  if (typeof detail === 'string') return detail;
  if (Array.isArray(detail)) return detail.map((item) => item && typeof item === 'object' && 'msg' in item ? String(item.msg) : String(item)).join(' ');
  return fallback;
}

function percent(value: unknown): number {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? Math.round(numeric * 1000) / 10 : 0;
}

function initials(name: string): string {
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0].toUpperCase()).join('') || 'DS';
}

function savedRecord(value: MediaScanResult): MediaScanResult {
  return { ...value, analystNotes: value.analystNotes || '' };
}

export const DashboardLayout: React.FC<DashboardLayoutProps> = ({ user, onLogout }) => {
  const [activeTab, setActiveTab] = useState<DashboardTab>('overview');
  const [records, setRecords] = useState<MediaScanResult[]>(() => readHistory(user.id));
  const [health, setHealth] = useState<BackendHealth | null>(null);
  const [healthError, setHealthError] = useState('');
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState('');
  const [activeResult, setActiveResult] = useState<MediaScanResult | null>(null);
  const [scanError, setScanError] = useState('');
  const [scanning, setScanning] = useState(false);
  const [query, setQuery] = useState('');
  const [loggingOut, setLoggingOut] = useState(false);
  const fileInput = useRef<HTMLInputElement>(null);

  useEffect(() => {
    localStorage.setItem(`deepshield_web_scans_${user.id}`, JSON.stringify(records));
  }, [records, user.id]);

  useEffect(() => {
    if (!selectedFile) {
      setPreviewUrl('');
      return;
    }
    const url = URL.createObjectURL(selectedFile);
    setPreviewUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [selectedFile]);

  useEffect(() => {
    let cancelled = false;
    fetch('/api/health')
      .then(async (response) => {
        const payload = await response.json().catch(() => ({}));
        if (!response.ok) throw new Error(readableError(payload, 'Could not load model status.'));
        return payload as BackendHealth;
      })
      .then((payload) => { if (!cancelled) { setHealth(payload); setHealthError(''); } })
      .catch((error: unknown) => { if (!cancelled) setHealthError(error instanceof Error ? error.message : 'Could not reach the backend.'); });
    return () => { cancelled = true; };
  }, []);

  const chooseFile = (file?: File) => {
    if (!file) return;
    const looksLikeImage = file.type.startsWith('image/') || /\.(jpg|jpeg|png)$/i.test(file.name);
    const looksLikeVideo = file.type.startsWith('video/') || /\.(mp4|mov|avi|mkv|webm)$/i.test(file.name);
    if (!looksLikeImage && !looksLikeVideo) {
      setScanError('Choose a JPG or PNG image, or an MP4, MOV, AVI, MKV, or WebM video.');
      setSelectedFile(null);
      return;
    }
    if (looksLikeImage && !/\.(jpg|jpeg|png)$/i.test(file.name) && !['image/jpeg', 'image/png'].includes(file.type)) {
      setScanError('Only JPEG and PNG images are supported.');
      setSelectedFile(null);
      return;
    }
    if (looksLikeVideo && !/\.(mp4|mov|avi|mkv|webm)$/i.test(file.name)) {
      setScanError('Use an MP4, MOV, AVI, MKV, or WebM video.');
      setSelectedFile(null);
      return;
    }
    const limit = looksLikeVideo ? VIDEO_LIMIT : IMAGE_LIMIT;
    if (file.size > limit) {
      setScanError(`This ${looksLikeVideo ? 'video' : 'image'} exceeds the ${looksLikeVideo ? '200 MB' : '15 MB'} limit.`);
      setSelectedFile(null);
      return;
    }
    setScanError('');
    setActiveResult(null);
    setSelectedFile(file);
  };

  const handleScan = async () => {
    if (!selectedFile) {
      setScanError('Choose a photo or video before starting a scan.');
      return;
    }
    const isVideo = selectedFile.type.startsWith('video/') || /\.(mp4|mov|avi|mkv|webm)$/i.test(selectedFile.name);
    setScanning(true);
    setScanError('');
    setActiveTab('scanner');
    try {
      const form = new FormData();
      form.append('file', selectedFile);
      const endpoint = isVideo ? '/api/v2/detect/video' : '/api/v1/scan/image';
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: sessionStorage.getItem(TOKEN_KEY)
          ? { Authorization: `Bearer ${sessionStorage.getItem(TOKEN_KEY)}` }
          : {},
        body: form,
      });
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) {
        if (response.status === 503) {
          throw new Error(`The ${isVideo ? 'FF++ video' : 'photo'} detector is not available. ${readableError(payload, 'Check backend model readiness and required local artifacts.')}`);
        }
        throw new Error(readableError(payload, `The ${isVideo ? 'video' : 'photo'} could not be analyzed.`));
      }
      if (payload && typeof payload === 'object' && 'is_demo' in payload && (payload as { is_demo: boolean }).is_demo) {
        throw new Error('The backend returned a demo result. It was not added to scan history.');
      }

      const body = payload as Record<string, unknown>;
      const timestamp = typeof body.scanned_at === 'string' ? body.scanned_at : new Date().toISOString();
      let record: MediaScanResult;
      if (isVideo) {
        record = {
          caseId: typeof body.id === 'string' ? body.id : crypto.randomUUID(),
          timestamp,
          title: selectedFile.name,
          mediaType: 'video',
          prediction: String(body.prediction || 'Unknown'),
          fakeProbability: Number(body.fake_probability),
          confidence: Number(body.confidence),
          threshold: Number(body.threshold),
          modelVersion: typeof body.model_version === 'string' ? body.model_version : undefined,
          framesAnalyzed: Number(body.frames_analyzed),
          noFaceFrames: Number(body.no_face_frames),
          aggregationMethod: typeof body.aggregation_method === 'string' ? body.aggregation_method : undefined,
          analystNotes: '',
        };
      } else {
        const extra = body.extra_data && typeof body.extra_data === 'object'
          ? body.extra_data as Record<string, unknown>
          : {};
        record = {
          caseId: typeof body.id === 'string' ? body.id : crypto.randomUUID(),
          timestamp,
          title: selectedFile.name,
          mediaType: 'image',
          prediction: String(extra.prediction || 'unknown'),
          fakeProbability: Number(extra.ai_generated_probability),
          confidence: Number(body.confidence_score),
          threshold: Number(extra.decision_threshold),
          modelVersion: typeof extra.model_version === 'string' ? extra.model_version : undefined,
          photoSignals: {
            aiGeneratedProbability: Number(extra.ai_generated_probability),
            faceManipulationProbability: Number(extra.face_manipulation_probability),
            facesDetected: Number(extra.faces_detected),
            facesAnalyzed: Number(extra.faces_analyzed),
            modelVersion: String(extra.model_version || 'unknown'),
            faceModelVersion: String(extra.face_model_version || 'unknown'),
            decisionThreshold: Number(extra.decision_threshold),
            faceManipulationPrediction: String(extra.face_manipulation_prediction || 'unknown'),
          },
          analystNotes: '',
        };
      }

      if (!Number.isFinite(record.fakeProbability) || !Number.isFinite(record.confidence)) {
        throw new Error('The detector response did not include valid model scores.');
      }
      record = savedRecord(record);
      setActiveResult(record);
      setRecords((previous) => [record, ...previous.filter((item) => item.caseId !== record.caseId)]);
    } catch (error) {
      setScanError(error instanceof Error ? error.message : 'The scan could not be completed.');
    } finally {
      setScanning(false);
    }
  };

  const setNotes = (caseId: string, analystNotes: string) => {
    setRecords((previous) => previous.map((item) => item.caseId === caseId ? { ...item, analystNotes } : item));
    setActiveResult((previous) => previous?.caseId === caseId ? { ...previous, analystNotes } : previous);
  };

  const exportJson = () => {
    const blob = new Blob([JSON.stringify(records, null, 2)], { type: 'application/json' });
    download(blob, `deepshield-scan-history-${new Date().toISOString().slice(0, 10)}.json`);
  };

  const exportCsv = () => {
    const rows = [
      ['Case ID', 'Timestamp', 'File', 'Media type', 'Prediction', 'Model score', 'Confidence estimate', 'Threshold', 'Frames analyzed', 'No-face frames'],
      ...records.map((item) => [
        item.caseId, item.timestamp, item.title, item.mediaType, item.prediction,
        Number.isFinite(item.fakeProbability) ? `${percent(item.fakeProbability)}%` : '',
        Number.isFinite(item.confidence) ? `${percent(item.confidence)}%` : '',
        Number.isFinite(item.threshold) ? `${percent(item.threshold)}%` : '',
        item.framesAnalyzed ?? '', item.noFaceFrames ?? '',
      ]),
    ];
    const csv = rows.map((row) => row.map((value) => `"${String(value).replace(/"/g, '""')}"`).join(',')).join('\n');
    download(new Blob([csv], { type: 'text/csv;charset=utf-8' }), `deepshield-scan-history-${new Date().toISOString().slice(0, 10)}.csv`);
  };

  const handleLogout = async () => {
    setLoggingOut(true);
    await onLogout();
    setLoggingOut(false);
  };

  const filteredRecords = records.filter((item) =>
    `${item.title} ${item.prediction} ${item.mediaType} ${item.caseId}`.toLowerCase().includes(query.toLowerCase().trim()),
  );
  const label = activeResult?.mediaType === 'image'
    ? activeResult.prediction === 'ai_generated' ? 'AI-generation signal detected' : 'No strong AI-generation signal'
    : activeResult?.prediction || '';
  const photoSignal = activeResult?.photoSignals;
  return (
    <div className="min-h-screen bg-black text-white">
      <div className="pointer-events-none fixed inset-0 -z-0 bg-[radial-gradient(ellipse_at_72%_0%,rgba(71,89,125,.14),transparent_36%)]" />
      <header className="relative z-10 border-b border-white/10 bg-black/80 backdrop-blur-xl">
        <div className="mx-auto flex max-w-[1500px] flex-col gap-3 px-4 py-3 sm:px-6 lg:flex-row lg:items-center lg:justify-between lg:px-8">
          <div className="flex items-center justify-between gap-4">
            <div className="flex items-center gap-2.5 text-base font-medium"><InfinityIcon /><span>DeepShield</span></div>
            <div className="flex items-center gap-2 lg:hidden">
              <span className="grid h-8 w-8 place-items-center rounded-full border border-white/15 bg-white/5 text-[10px]">{initials(user.name)}</span>
              <button type="button" onClick={handleLogout} disabled={loggingOut} className="rounded-lg border border-white/10 px-2.5 py-2 text-[11px] text-white/70 hover:bg-white/5 disabled:opacity-50">{loggingOut ? 'Signing out…' : 'Sign out'}</button>
            </div>
          </div>
          <nav className="flex gap-1 overflow-x-auto lg:ml-auto" aria-label="Workspace navigation">
            {tabs.map((tab) => (
              <button key={tab.id} type="button" onClick={() => setActiveTab(tab.id)} className={`flex shrink-0 items-center gap-2 rounded-lg px-3 py-2 text-[11px] transition-colors ${activeTab === tab.id ? 'bg-white text-black' : 'text-white/55 hover:bg-white/5 hover:text-white'}`}>
                {tab.icon}<span>{tab.label}</span>
              </button>
            ))}
          </nav>
          <div className="hidden items-center gap-2 border-l border-white/10 pl-4 lg:flex">
            <span className="grid h-8 w-8 place-items-center rounded-full border border-white/15 bg-white/5 text-[10px]">{initials(user.name)}</span>
            <span className="max-w-36 truncate text-xs text-white/75">{user.name}</span>
            <button type="button" onClick={handleLogout} disabled={loggingOut} className="ml-1 flex items-center gap-1.5 rounded-lg border border-white/10 px-3 py-2 text-[11px] text-white/65 hover:bg-white/5 disabled:opacity-50"><LogOut size={13} />{loggingOut ? 'Signing out…' : 'Sign out'}</button>
          </div>
        </div>
      </header>

      <main className="relative z-10 mx-auto max-w-[1500px] space-y-6 px-4 py-7 sm:px-6 lg:px-8 lg:py-10">
        {activeTab === 'overview' && (
          <>
            <section className="flex flex-col justify-between gap-4 border-b border-white/10 pb-6 md:flex-row md:items-end">
              <div>
                <div className="mb-2 flex items-center gap-2 text-[10px] uppercase tracking-[.18em] text-white/45"><span className="h-1.5 w-1.5 rounded-full bg-emerald-300" /> Your workspace</div>
                <h1 className="text-3xl font-medium tracking-tight sm:text-4xl">Welcome, {user.name.split(/\s+/)[0]}.</h1>
                <p className="mt-2 text-xs text-white/50">Your media reviews and service readiness at a glance.</p>
              </div>
              <button type="button" onClick={() => setActiveTab('scanner')} className="flex items-center justify-center gap-2 rounded-full bg-white px-5 py-3 text-xs font-semibold text-black transition-colors hover:bg-white/90"><ScanLine size={15} /> Open media scanner</button>
            </section>

            <section className="grid grid-cols-1 gap-3 sm:grid-cols-3">
              <MetricCard label="Scans in this browser" value={String(records.length)} detail="Saved locally for this account" icon={<History size={16} />} />
              <MetricCard label="Photo analysis" value={health?.model_loaded ? 'Available' : health ? 'Unavailable' : healthError ? 'No connection' : 'Checking'} detail={health?.model_version || health?.model_error || 'FastAPI pretrained photo pipeline'} icon={<ImageIcon size={16} />} positive={Boolean(health?.model_loaded)} />
              <MetricCard label="Video analysis" value={health?.ffpp_video_model_loaded ? 'Available' : health ? 'Unavailable' : healthError ? 'No connection' : 'Checking'} detail={health?.ffpp_image_model_version || health?.ffpp_model_error || 'FaceForensics++ frame-sampling pipeline'} icon={<Video size={16} />} positive={Boolean(health?.ffpp_video_model_loaded)} />
            </section>

            {(healthError || (health && (!health.model_loaded || !health.ffpp_video_model_loaded))) && (
              <div className="flex items-start gap-3 rounded-xl border border-amber-300/15 bg-amber-300/[.04] p-4 text-xs text-amber-100/80">
                <AlertTriangle size={16} className="mt-0.5 shrink-0 text-amber-200" />
                <p className="leading-relaxed">{healthError || 'One or more detector artifacts are not loaded. The scanner will show the backend response when a service is unavailable; it will not substitute sample results.'}</p>
              </div>
            )}

            <section className="liquid-glass-card overflow-hidden rounded-2xl border border-white/10">
              <div className="flex items-center justify-between gap-3 border-b border-white/10 px-5 py-4 sm:px-6">
                <div><h2 className="text-sm font-semibold">Recent scans</h2><p className="mt-1 text-[10px] text-white/45">Only completed backend results appear here.</p></div>
                <button type="button" onClick={() => setActiveTab('history')} className="text-[11px] text-white/60 hover:text-white">View history <span aria-hidden="true">→</span></button>
              </div>
              {records.length ? <ScanTable records={records.slice(0, 5)} onSelect={(record) => { setActiveResult(record); setActiveTab('scanner'); }} /> : <EmptyState title="No scans yet" detail="Choose a photo or video to request an analysis from the configured backend model." action="Start a scan" onAction={() => setActiveTab('scanner')} />}
            </section>

            <p className="text-[10px] leading-relaxed text-white/35">Model outputs are uncalibrated estimates. They can be wrong, and a low signal is not proof that media is authentic.</p>
          </>
        )}

        {activeTab === 'scanner' && (
          <>
            <section className="flex flex-col justify-between gap-4 border-b border-white/10 pb-5 sm:flex-row sm:items-end">
              <div><div className="mb-2 text-[10px] uppercase tracking-[.18em] text-white/45">Live media scanner</div><h1 className="text-3xl font-medium tracking-tight">Inspect a file</h1><p className="mt-2 max-w-2xl text-xs leading-relaxed text-white/55">Photos use the FastAPI whole-image and face-signal pipeline. Videos use the configured FaceForensics++ detector on sampled frames.</p></div>
              <span className="flex items-center gap-2 self-start rounded-full border border-white/10 px-3 py-2 text-[10px] text-white/50 sm:self-auto"><span className="h-1.5 w-1.5 rounded-full bg-white/60" /> Results are estimates</span>
            </section>

            <section className="grid grid-cols-1 items-start gap-5 xl:grid-cols-[minmax(320px,.88fr)_minmax(0,1.12fr)]">
              <div className="space-y-4">
                <div className="liquid-glass-card rounded-2xl border border-white/10 p-5 sm:p-6">
                  <div className="mb-4 flex items-start justify-between gap-4"><div><h2 className="text-sm font-semibold">Add media</h2><p className="mt-1 text-[10px] leading-relaxed text-white/45">Choose a photo or a supported video file.</p></div><Upload size={17} className="text-white/55" /></div>
                  <input ref={fileInput} type="file" accept="image/jpeg,image/png,video/mp4,video/quicktime,video/x-msvideo,video/x-matroska,video/webm" className="hidden" onChange={(event) => chooseFile(event.target.files?.[0])} />
                  <button type="button" onClick={() => fileInput.current?.click()} onDragOver={(event) => event.preventDefault()} onDrop={(event) => { event.preventDefault(); chooseFile(event.dataTransfer.files[0]); }} className="group flex min-h-48 w-full flex-col items-center justify-center rounded-xl border border-dashed border-white/20 bg-white/[.015] p-5 text-center transition-colors hover:border-white/40 hover:bg-white/[.03]">
                    {selectedFile ? <>{selectedFile.type.startsWith('video/') || /\.(mp4|mov|avi|mkv|webm)$/i.test(selectedFile.name) ? <Video size={24} className="mb-3 text-white/70" /> : <ImageIcon size={24} className="mb-3 text-white/70" />}<span className="max-w-full break-all text-xs font-medium">{selectedFile.name}</span><span className="mt-1 text-[10px] text-white/45">{(selectedFile.size / (1024 * 1024)).toFixed(2)} MB · click to replace</span></> : <><Upload size={24} className="mb-3 text-white/50 transition-transform group-hover:-translate-y-0.5" /><span className="text-xs font-medium">Drop a file here or browse</span><span className="mt-2 text-[10px] text-white/40">Images: JPG, PNG up to 15 MB</span><span className="mt-1 text-[10px] text-white/40">Videos: MP4, MOV, AVI, MKV, WebM up to 200 MB</span></>}
                  </button>
                  {selectedFile && previewUrl && (
                    <div className="mt-3 overflow-hidden rounded-xl border border-white/10 bg-black/50">
                      {selectedFile.type.startsWith('video/') || /\.(mp4|mov|avi|mkv|webm)$/i.test(selectedFile.name)
                        ? <video className="max-h-64 w-full object-contain" src={previewUrl} controls muted playsInline />
                        : <img className="max-h-64 w-full object-contain" src={previewUrl} alt="Selected media preview" />}
                    </div>
                  )}
                  <div className="mt-4 flex flex-col gap-2 sm:flex-row">
                    <button type="button" onClick={() => void handleScan()} disabled={scanning} className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-white px-4 py-3 text-xs font-semibold text-black transition-colors hover:bg-white/90 disabled:cursor-wait disabled:opacity-60">{scanning ? <><Activity size={15} className="animate-pulse" /> Sending to detector…</> : <><ScanLine size={15} /> Analyze media</>}</button>
                    {selectedFile && <button type="button" onClick={() => { setSelectedFile(null); setScanError(''); setActiveResult(null); if (fileInput.current) fileInput.current.value = ''; }} className="flex items-center justify-center gap-1.5 rounded-xl border border-white/10 px-4 py-3 text-xs text-white/65 hover:bg-white/5"><X size={14} /> Clear file</button>}
                  </div>
                  {scanError && <div className="mt-3 flex items-start gap-2 rounded-lg border border-rose-400/15 bg-rose-400/[.04] p-3 text-[11px] leading-relaxed text-rose-100/85" role="alert"><AlertTriangle size={14} className="mt-0.5 shrink-0" />{scanError}</div>}
                </div>
                <div className="flex items-start gap-2.5 rounded-xl border border-white/10 bg-white/[.02] p-4 text-[10px] leading-relaxed text-white/45"><Info size={14} className="mt-0.5 shrink-0 text-white/55" /><p>The browser keeps scan summaries locally in this account's history. It does not save your uploaded original file to that history.</p></div>
              </div>

              <div className="liquid-glass-card min-h-64 rounded-2xl border border-white/10 p-5 sm:p-6">
                {scanning ? <div className="flex min-h-52 flex-col items-center justify-center text-center"><Activity size={26} className="mb-3 animate-pulse text-white/60" /><h2 className="text-sm font-semibold">Waiting for the detector</h2><p className="mt-2 text-[11px] text-white/45">The file is being sent to the configured DeepShield model service.</p></div>
                  : activeResult ? <ScanResult record={activeResult} label={label} photoSignal={photoSignal} onNotesChange={setNotes} />
                    : <div className="flex min-h-52 flex-col items-center justify-center text-center"><ScanLine size={25} className="mb-3 text-white/25" /><h2 className="text-sm font-semibold text-white/70">Analysis will appear here</h2><p className="mt-2 max-w-sm text-[11px] leading-relaxed text-white/40">Start a scan to see the model response. If a required model is missing, DeepShield will show its availability message.</p></div>}
              </div>
            </section>
          </>
        )}

        {activeTab === 'history' && (
          <section className="liquid-glass-card overflow-hidden rounded-2xl border border-white/10">
            <div className="flex flex-col justify-between gap-3 border-b border-white/10 p-5 sm:flex-row sm:items-center sm:px-6">
              <div><div className="mb-1 text-[10px] uppercase tracking-[.18em] text-white/40">Local records</div><h1 className="text-xl font-semibold">Scan history</h1><p className="mt-1 text-[10px] text-white/45">{records.length} completed {records.length === 1 ? 'scan' : 'scans'} saved in this browser for this account.</p></div>
              <div className="flex flex-wrap gap-2">
                <label className="flex items-center gap-2 rounded-lg border border-white/10 px-3 py-2"><Search size={13} className="text-white/40" /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search files or labels" className="w-36 bg-transparent text-[11px] outline-none placeholder:text-white/35 sm:w-48" /></label>
                <button type="button" onClick={exportJson} disabled={!records.length} className="flex items-center gap-1.5 rounded-lg border border-white/10 px-3 py-2 text-[10px] text-white/65 hover:bg-white/5 disabled:opacity-40"><FileJson size={13} /> JSON</button>
                <button type="button" onClick={exportCsv} disabled={!records.length} className="flex items-center gap-1.5 rounded-lg border border-white/10 px-3 py-2 text-[10px] text-white/65 hover:bg-white/5 disabled:opacity-40"><Download size={13} /> CSV</button>
              </div>
            </div>
            {filteredRecords.length ? <ScanTable records={filteredRecords} onSelect={(record) => { setActiveResult(record); setActiveTab('scanner'); }} /> : <EmptyState title={records.length ? 'No matching scans' : 'No scan history yet'} detail={records.length ? 'Try another file name or prediction label.' : 'Completed backend analyses will appear here.'} action={records.length ? undefined : 'Open scanner'} onAction={records.length ? undefined : () => setActiveTab('scanner')} />}
          </section>
        )}

        {activeTab === 'benchmarks' && (
          <section className="space-y-5">
            <div className="border-b border-white/10 pb-5"><div className="mb-2 text-[10px] uppercase tracking-[.18em] text-white/45">Service status</div><h1 className="text-3xl font-medium tracking-tight">Model availability</h1><p className="mt-2 max-w-2xl text-xs leading-relaxed text-white/50">These readiness values come from the running backend's <code className="text-white/70">/health</code> response. No benchmark values are generated in the browser.</p></div>
            {healthError ? <div className="liquid-glass-card rounded-2xl border border-amber-200/15 p-5 text-xs text-amber-100/80">Backend health could not be read: {healthError}</div> : !health ? <div className="liquid-glass-card rounded-2xl border border-white/10 p-5 text-xs text-white/50">Loading backend model status…</div> : (
              <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
                <ModelCard title="Pretrained photo pipeline" description="Whole-image AI-generation estimate and a face-manipulation check on detected face crops." loaded={Boolean(health.model_loaded)} modelVersion={health.model_version} faceVersion={health.face_model_version} error={health.model_error} />
                <ModelCard title="FaceForensics++ image detector" description="Custom image classifier used by the image endpoint." loaded={Boolean(health.ffpp_image_model_loaded)} modelVersion={health.ffpp_image_model_version} error={health.ffpp_model_error} />
                <ModelCard title="FaceForensics++ video detector" description="Aggregates scores from sampled frames using a configured frame method. It is not a temporal motion model." loaded={Boolean(health.ffpp_video_model_loaded)} modelVersion={health.ffpp_image_model_version} error={health.ffpp_model_error} />
              </div>
            )}
            <div className="liquid-glass-subtle rounded-2xl border border-white/10 p-5 text-xs leading-relaxed text-white/55"><strong className="text-white/80">Evaluation reports:</strong> training, validation, and held-out test reports are generated by the model scripts and are not embedded here as static marketing numbers. Confirm which split and artifact produced a metric before comparing results.</div>
          </section>
        )}

        {activeTab === 'api' && (
          <section className="space-y-5">
            <div className="border-b border-white/10 pb-5"><div className="mb-2 text-[10px] uppercase tracking-[.18em] text-white/45">Developer reference</div><h1 className="text-3xl font-medium tracking-tight">Backend endpoints</h1><p className="mt-2 max-w-2xl text-xs leading-relaxed text-white/50">The project does not currently issue developer API keys, configure webhooks, or pair a browser account with mobile history. These are the existing scan endpoints.</p></div>
            <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
              <EndpointCard method="POST" path="/api/v1/scan/image" title="Photo signals" description="Multipart field: file. Returns AI-generation and face-manipulation model signals." />
              <EndpointCard method="POST" path="/api/v2/detect/video" title="Video estimate" description="Multipart field: file. Supports MP4, MOV, AVI, MKV, and WebM when the FF++ video model is loaded." />
              <EndpointCard method="POST" path="/api/v2/detect/image" title="FF++ image detector" description="Multipart field: file. Requires the trained FaceForensics++ image artifact." />
              <EndpointCard method="GET" path="/health" title="Model readiness" description="Reports whether the configured image and video model artifacts loaded in the backend." />
            </div>
            <div className="liquid-glass-subtle rounded-2xl border border-white/10 p-5 text-xs leading-relaxed text-white/55"><strong className="text-white/80">Authentication:</strong> the website uses the backend's existing email/password endpoints and bearer session token. The browser does not display or generate API keys.</div>
          </section>
        )}
      </main>
    </div>
  );
};

function download(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  URL.revokeObjectURL(url);
}

function InfinityIcon() {
  return <span className="grid h-8 w-8 place-items-center rounded-xl border border-white/10 bg-white/[.04]"><Infinity size={18} strokeWidth={1.6} /></span>;
}

function MetricCard({ label, value, detail, icon, positive }: { label: string; value: string; detail: string; icon: React.ReactNode; positive?: boolean }) {
  return <article className="liquid-glass-card rounded-2xl border border-white/10 p-4 sm:p-5"><div className="flex items-start justify-between"><span className="text-[10px] text-white/45">{label}</span><span className={`rounded-lg p-2 ${positive ? 'bg-emerald-200/[.07] text-emerald-100/80' : 'bg-white/[.04] text-white/55'}`}>{icon}</span></div><div className="mt-3 text-xl font-semibold tracking-tight">{value}</div><p className="mt-1 line-clamp-2 min-h-7 text-[10px] leading-relaxed text-white/40">{detail || 'Status is reported by the backend.'}</p></article>;
}

function EmptyState({ title, detail, action, onAction }: { title: string; detail: string; action?: string; onAction?: () => void }) {
  return <div className="flex min-h-48 flex-col items-center justify-center p-7 text-center"><Clock3 size={22} className="mb-3 text-white/25" /><h2 className="text-xs font-semibold text-white/75">{title}</h2><p className="mt-2 max-w-sm text-[10px] leading-relaxed text-white/40">{detail}</p>{action && onAction && <button type="button" onClick={onAction} className="mt-4 rounded-full border border-white/15 px-4 py-2 text-[10px] text-white/70 hover:bg-white/5">{action}</button>}</div>;
}

function ScanTable({ records, onSelect }: { records: MediaScanResult[]; onSelect: (record: MediaScanResult) => void }) {
  return <div className="overflow-x-auto"><table className="w-full min-w-[720px] text-left text-[11px]"><thead><tr className="border-b border-white/10 text-[9px] uppercase tracking-wider text-white/35"><th className="px-5 py-3 font-medium sm:px-6">Media</th><th className="px-4 py-3 font-medium">Type</th><th className="px-4 py-3 font-medium">Estimate</th><th className="px-4 py-3 font-medium">Model score · uncalibrated</th><th className="px-4 py-3 font-medium">Scanned</th><th className="px-5 py-3 sm:px-6" /></tr></thead><tbody className="divide-y divide-white/[.06]">{records.map((record) => <tr key={record.caseId} className="transition-colors hover:bg-white/[.025]"><td className="max-w-[260px] px-5 py-3.5 sm:px-6"><div className="flex items-center gap-2.5"><span className="rounded-lg bg-white/[.05] p-2 text-white/50">{record.mediaType === 'video' ? <Video size={14} /> : <ImageIcon size={14} />}</span><span className="truncate font-medium text-white/80">{record.title}</span></div></td><td className="px-4 py-3.5 capitalize text-white/50">{record.mediaType}</td><td className="px-4 py-3.5 text-white/70">{record.mediaType === 'video' ? record.prediction : record.prediction === 'ai_generated' ? 'AI-generation signal' : 'No strong AI signal'}</td><td className="px-4 py-3.5 font-mono tabular-nums text-white/65">{percent(record.fakeProbability)}%</td><td className="px-4 py-3.5 text-white/45">{new Date(record.timestamp).toLocaleString()}</td><td className="px-5 py-3.5 text-right sm:px-6"><button type="button" onClick={() => onSelect(record)} className="rounded-lg border border-white/10 px-2.5 py-1.5 text-[10px] text-white/65 hover:bg-white/5">Open</button></td></tr>)}</tbody></table></div>;
}

function ScanResult({ record, label, photoSignal, onNotesChange }: { record: MediaScanResult; label: string; photoSignal: MediaScanResult['photoSignals']; onNotesChange: (caseId: string, notes: string) => void }) {
  const isVideo = record.mediaType === 'video';
  return <div className="space-y-5">
    <div className="flex flex-col justify-between gap-3 border-b border-white/10 pb-4 sm:flex-row sm:items-start"><div><div className="mb-1 flex items-center gap-2 text-[9px] uppercase tracking-[.16em] text-white/40"><CheckCircle2 size={12} className="text-emerald-200/70" /> Completed backend analysis</div><h2 className="max-w-xl break-all text-base font-semibold">{record.title}</h2><p className="mt-1 text-[10px] text-white/45">{isVideo ? 'FaceForensics++ video estimate' : 'Pretrained photo signals'} · {new Date(record.timestamp).toLocaleString()}</p></div><span className="self-start rounded-full border border-white/10 px-3 py-1.5 text-[10px] text-white/70">{label}</span></div>

    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
      <ScoreCard title={isVideo ? 'Fake estimate' : 'AI-generation estimate'} value={percent(record.fakeProbability)} note="Uncalibrated model score · not a probability" />
      <ScoreCard title="Confidence estimate" value={percent(record.confidence)} note="Uncalibrated · not proof of authenticity" />
    </div>

    {photoSignal && <div className="space-y-3 rounded-xl border border-white/10 bg-white/[.015] p-4"><h3 className="text-[11px] font-semibold text-white/80">Photo model details</h3><div className="grid grid-cols-1 gap-3 sm:grid-cols-2"><ScoreCard title="Face-manipulation signal" value={percent(photoSignal.faceManipulationProbability)} note={photoSignal.facesAnalyzed > 0 ? `${photoSignal.facesAnalyzed} face crop(s) analyzed` : 'No face crop was analyzed'} /><div className="rounded-xl border border-white/[.07] p-3"><div className="text-[9px] text-white/40">Detection details</div><div className="mt-2 text-[10px] leading-relaxed text-white/65">Faces detected: {photoSignal.facesDetected}<br />AI model: {photoSignal.modelVersion}<br />Face model: {photoSignal.faceModelVersion}</div></div></div></div>}

    {isVideo && <div className="grid grid-cols-2 gap-3"><DetailCard label="Frames analyzed" value={String(record.framesAnalyzed ?? '—')} /><DetailCard label="Frames without detected faces" value={String(record.noFaceFrames ?? '—')} /><DetailCard label="Aggregation" value={record.aggregationMethod || 'Backend-selected'} /><DetailCard label="Decision threshold" value={`${percent(record.threshold)}% · uncalibrated`} /></div>}

    {!isVideo && <DetailCard label="Photo decision threshold" value={`${percent(photoSignal?.decisionThreshold ?? record.threshold)}% · uncalibrated`} />}
    {record.modelVersion && <p className="text-[9px] text-white/35">Model version: {record.modelVersion}</p>}

    <div className="border-t border-white/10 pt-4"><label htmlFor={`notes-${record.caseId}`} className="mb-2 block text-[10px] font-medium text-white/60">Your review note <span className="font-normal text-white/35">(stored locally)</span></label><textarea id={`notes-${record.caseId}`} rows={2} maxLength={2000} value={record.analystNotes} onChange={(event) => onNotesChange(record.caseId, event.target.value)} placeholder="Add context or follow-up notes…" className="w-full resize-y rounded-xl border border-white/10 bg-black/40 p-3 text-[11px] text-white outline-none placeholder:text-white/25 focus:border-white/25" /></div>

    <div className="flex items-start gap-2 rounded-lg border border-amber-200/10 bg-amber-100/[.025] p-3 text-[10px] leading-relaxed text-white/45"><ShieldAlert size={14} className="mt-0.5 shrink-0 text-amber-100/70" /><p>{isVideo ? 'Video scores aggregate sampled image frames; no temporal motion model is used. A REAL label is not proof of authenticity.' : 'No strong model signal does not establish that this image is authentic. Face checks may be skipped when no face is detected.'} Review provenance and independent evidence before sharing.</p></div>
  </div>;
}

function ScoreCard({ title, value, note }: { title: string; value: number; note: string }) {
  return <div className="rounded-xl border border-white/[.08] bg-black/25 p-3.5"><div className="flex items-center justify-between gap-2"><span className="text-[10px] text-white/55">{title}</span><span className="font-mono text-sm font-semibold tabular-nums">{value}%</span></div><div className="mt-2 h-1 overflow-hidden rounded-full bg-white/[.07]"><div className="h-full rounded-full bg-white/70" style={{ width: `${Math.min(100, Math.max(0, value))}%` }} /></div><p className="mt-2 text-[9px] text-white/35">{note}</p></div>;
}

function DetailCard({ label, value }: { label: string; value: string }) {
  return <div className="rounded-xl border border-white/[.08] bg-black/25 p-3"><div className="text-[9px] text-white/40">{label}</div><div className="mt-1 break-words text-[10px] text-white/70">{value}</div></div>;
}

function ModelCard({ title, description, loaded, modelVersion, faceVersion, error }: { title: string; description: string; loaded: boolean; modelVersion?: string | null; faceVersion?: string | null; error?: string | null }) {
  return <article className="liquid-glass-card rounded-2xl border border-white/10 p-5 sm:p-6"><div className="flex items-start justify-between gap-3"><div><h2 className="text-sm font-semibold">{title}</h2><p className="mt-2 max-w-xl text-[11px] leading-relaxed text-white/50">{description}</p></div><span className={`shrink-0 rounded-full border px-2.5 py-1 text-[9px] ${loaded ? 'border-emerald-100/15 text-emerald-100/80' : 'border-amber-100/15 text-amber-100/70'}`}>{loaded ? 'Loaded' : 'Unavailable'}</span></div><div className="mt-5 space-y-2 border-t border-white/10 pt-4 text-[10px] text-white/45"><div className="flex items-center gap-2"><Server size={12} /> Model: <span className="text-white/70">{modelVersion || 'Not loaded'}</span></div>{faceVersion && <div className="flex items-center gap-2"><Server size={12} /> Face model: <span className="text-white/70">{faceVersion}</span></div>}{error && <p className="mt-2 break-words leading-relaxed text-amber-100/60">{error}</p>}</div></article>;
}

function EndpointCard({ method, path, title, description }: { method: string; path: string; title: string; description: string }) {
  return <article className="liquid-glass-card rounded-2xl border border-white/10 p-5"><div className="mb-3 flex items-center gap-2"><span className="rounded-md border border-emerald-100/10 bg-emerald-100/[.04] px-2 py-1 font-mono text-[9px] text-emerald-100/75">{method}</span><code className="break-all text-[10px] text-white/65">{path}</code></div><h2 className="text-xs font-semibold">{title}</h2><p className="mt-2 text-[10px] leading-relaxed text-white/45">{description}</p></article>;
}
