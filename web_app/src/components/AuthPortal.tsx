import React, { useState } from 'react';
import { AlertCircle, ArrowLeft, ArrowRight, Infinity, Lock, Mail, User } from 'lucide-react';
import { AppView, UserProfile } from '../types/forensics';

interface AuthPortalProps {
  initialMode: 'login' | 'signup';
  onAuthenticate: (session: { access_token: string; user: UserProfile }) => void;
  onNavigateView: (view: AppView) => void;
}

function responseMessage(payload: unknown): string {
  if (!payload || typeof payload !== 'object') return 'The request could not be completed.';
  const value = payload as Record<string, unknown>;
  const message = value.detail || value.error;
  if (typeof message === 'string') return message;
  if (Array.isArray(message)) {
    return message.map((item) => item && typeof item === 'object' && 'msg' in item ? String(item.msg) : String(item)).join(' ');
  }
  return 'The request could not be completed.';
}

export const AuthPortal: React.FC<AuthPortalProps> = ({ initialMode, onAuthenticate, onNavigateView }) => {
  const [mode, setMode] = useState<'login' | 'signup'>(initialMode);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [fullName, setFullName] = useState('');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setErrorMsg(null);
    if (!email.trim() || !email.includes('@')) {
      setErrorMsg('Enter a valid email address.');
      return;
    }
    if (password.length < 8 || password.length > 128) {
      setErrorMsg('Password must be between 8 and 128 characters.');
      return;
    }
    if (mode === 'signup' && !fullName.trim()) {
      setErrorMsg('Enter your name to create an account.');
      return;
    }

    setSubmitting(true);
    try {
      const response = await fetch(`/api/v1/auth/${mode === 'signup' ? 'register' : 'login'}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: email.trim(),
          password,
          ...(mode === 'signup' ? { name: fullName.trim() } : {}),
        }),
      });
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(responseMessage(payload));
      const session = payload as { access_token?: string; user?: UserProfile };
      if (!session.access_token || !session.user) throw new Error('The authentication service returned an invalid session.');
      onAuthenticate({ access_token: session.access_token, user: session.user });
    } catch (error) {
      setErrorMsg(error instanceof Error ? error.message : 'Could not connect to the authentication service.');
    } finally {
      setSubmitting(false);
    }
  };

  const changeMode = (nextMode: 'login' | 'signup') => {
    setMode(nextMode);
    setErrorMsg(null);
  };

  return (
    <div className="relative flex min-h-screen w-full flex-col justify-between overflow-y-auto bg-black p-5 text-white sm:p-8">
      <video className="pointer-events-none fixed inset-0 z-0 h-full w-full object-cover" autoPlay muted loop playsInline aria-hidden="true" src="https://d8j0ntlcm91z4.cloudfront.net/user_38xzZboKViGWJOttwIXH07lWA1P/hf_20260511_230229_7c9bc431-46cf-489a-948d-e8144d8eb5d4.mp4" />
      <div className="pointer-events-none fixed inset-0 z-10 bg-black/65" />

      <header className="relative z-20 mx-auto flex w-full max-w-6xl items-center justify-between">
        <button onClick={() => onNavigateView('landing')} className="flex cursor-pointer items-center gap-2 text-base font-medium text-white hover:opacity-85" type="button">
          <Infinity size={22} strokeWidth={1.5} />
          <span>DeepShield</span>
        </button>
        <button onClick={() => onNavigateView('landing')} className="liquid-glass flex cursor-pointer items-center gap-1.5 rounded-full px-3.5 py-2 text-xs font-medium text-white/80 transition-colors hover:text-white" type="button">
          <ArrowLeft size={14} /> Back to Website
        </button>
      </header>

      <main className="relative z-20 my-auto flex items-center justify-center py-8">
        <section className="liquid-glass-card w-full max-w-md rounded-2xl border border-white/15 p-6 sm:p-8" aria-labelledby="auth-heading">
          <div className="mb-6 grid grid-cols-2 gap-1 rounded-xl border border-white/10 bg-black/50 p-1" role="tablist" aria-label="Account access">
            <button type="button" onClick={() => changeMode('login')} aria-selected={mode === 'login'} className={`cursor-pointer rounded-lg py-2 text-xs font-medium transition-colors ${mode === 'login' ? 'bg-white font-semibold text-black' : 'text-white/70 hover:text-white'}`}>Sign in</button>
            <button type="button" onClick={() => changeMode('signup')} aria-selected={mode === 'signup'} className={`cursor-pointer rounded-lg py-2 text-xs font-medium transition-colors ${mode === 'signup' ? 'bg-white font-semibold text-black' : 'text-white/70 hover:text-white'}`}>Create account</button>
          </div>

          <div className="mb-6">
            <h1 id="auth-heading" className="text-2xl font-semibold tracking-tight text-white">
              {mode === 'login' ? 'Sign in to DeepShield' : 'Create your account'}
            </h1>
            <p className="mt-1 text-xs leading-relaxed text-white/60">
              {mode === 'login' ? 'Continue to your DeepShield media review workspace.' : 'Create an account to open your DeepShield workspace.'}
            </p>
          </div>

          {errorMsg && (
            <div className="mb-4 flex items-center gap-2.5 rounded-xl border border-rose-400/40 bg-rose-950/60 p-3 text-xs text-rose-200" role="alert">
              <AlertCircle size={15} className="shrink-0 text-rose-400" />
              <span>{errorMsg}</span>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            {mode === 'signup' && (
              <div>
                <label htmlFor="fullName" className="mb-1.5 block text-xs font-medium text-white/80">Full name</label>
                <div className="relative">
                  <User size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-white/40" />
                  <input id="fullName" required autoComplete="name" maxLength={80} value={fullName} onChange={(event) => setFullName(event.target.value)} placeholder="Your name" className="w-full rounded-xl border border-white/15 bg-black/50 py-2.5 pl-10 pr-3.5 text-sm text-white outline-none transition-colors placeholder:text-white/30 focus:border-white/50" />
                </div>
              </div>
            )}

            <div>
              <label htmlFor="email" className="mb-1.5 block text-xs font-medium text-white/80">Email address</label>
              <div className="relative">
                <Mail size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-white/40" />
                <input id="email" type="email" required autoComplete="email" maxLength={254} value={email} onChange={(event) => setEmail(event.target.value)} placeholder="you@example.com" className="w-full rounded-xl border border-white/15 bg-black/50 py-2.5 pl-10 pr-3.5 text-sm text-white outline-none transition-colors placeholder:text-white/30 focus:border-white/50" />
              </div>
            </div>

            <div>
              <label htmlFor="password" className="mb-1.5 block text-xs font-medium text-white/80">Password</label>
              <div className="relative">
                <Lock size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-white/40" />
                <input id="password" type="password" required autoComplete={mode === 'signup' ? 'new-password' : 'current-password'} minLength={8} maxLength={128} value={password} onChange={(event) => setPassword(event.target.value)} placeholder="At least 8 characters" className="w-full rounded-xl border border-white/15 bg-black/50 py-2.5 pl-10 pr-3.5 text-sm text-white outline-none transition-colors placeholder:text-white/30 focus:border-white/50" />
              </div>
            </div>

            <button type="submit" disabled={submitting} className="mt-2 flex w-full cursor-pointer items-center justify-center gap-2 rounded-xl bg-white py-3 text-sm font-semibold text-black transition-colors hover:bg-white/90 disabled:cursor-wait disabled:opacity-60">
              <span>{submitting ? 'Please wait…' : mode === 'login' ? 'Sign in to dashboard' : 'Create account'}</span>
              <ArrowRight size={16} />
            </button>
          </form>

          <p className="mt-5 text-center text-[11px] leading-relaxed text-white/45">
            Automated model output is an estimate for review, not proof of authenticity.
          </p>
        </section>
      </main>

      <footer className="relative z-20 text-center text-[11px] text-white/45">
        DeepShield · Sign in or create an account with the existing project authentication service.
      </footer>
    </div>
  );
};
