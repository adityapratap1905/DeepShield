import { useEffect, useState } from 'react';
import { AuthPortal } from './components/AuthPortal';
import { DashboardLayout } from './components/DashboardLayout';
import { LandingPage } from './components/LandingPage';
import { AppView, UserProfile } from './types/forensics';

const TOKEN_KEY = 'deepshield_web_access_token';

interface AuthSession {
  access_token: string;
  user: UserProfile;
}

function messageFromPayload(payload: unknown): string {
  if (payload && typeof payload === 'object' && 'detail' in payload) {
    const detail = (payload as { detail: unknown }).detail;
    if (typeof detail === 'string') return detail;
    if (Array.isArray(detail)) return detail.map((item) => (item && typeof item === 'object' && 'msg' in item ? String(item.msg) : String(item))).join(' ');
  }
  if (payload && typeof payload === 'object' && 'error' in payload) {
    return String((payload as { error: unknown }).error);
  }
  return 'The request could not be completed.';
}

async function readJson(response: Response): Promise<unknown> {
  return response.json().catch(() => ({}));
}

function userFromApi(value: unknown): UserProfile {
  if (!value || typeof value !== 'object') throw new Error('The authentication service returned an invalid account.');
  const user = value as Record<string, unknown>;
  return {
    id: String(user.id || ''),
    name: String(user.name || 'DeepShield user'),
    email: String(user.email || ''),
    createdAt: typeof user.created_at === 'string' ? user.created_at : undefined,
  };
}

export default function App() {
  const [currentView, setCurrentView] = useState<AppView>('landing');
  const [currentUser, setCurrentUser] = useState<UserProfile | null>(null);
  const [checkingSession, setCheckingSession] = useState(true);

  useEffect(() => {
    let cancelled = false;

    async function restoreSession() {
      const token = sessionStorage.getItem(TOKEN_KEY);
      if (!token) {
        setCheckingSession(false);
        return;
      }

      try {
        const response = await fetch('/api/v1/auth/me', {
          headers: { Authorization: `Bearer ${token}` },
        });
        const payload = await readJson(response);
        if (!response.ok) throw new Error(messageFromPayload(payload));
        if (!cancelled) {
          setCurrentUser(userFromApi(payload));
          setCurrentView('dashboard');
        }
      } catch {
        sessionStorage.removeItem(TOKEN_KEY);
      } finally {
        if (!cancelled) setCheckingSession(false);
      }
    }

    void restoreSession();
    return () => { cancelled = true; };
  }, []);

  const handleAuthenticate = (session: AuthSession) => {
    sessionStorage.setItem(TOKEN_KEY, session.access_token);
    setCurrentUser(userFromApi(session.user));
    setCurrentView('dashboard');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleLogout = async () => {
    const token = sessionStorage.getItem(TOKEN_KEY);
    if (token) {
      try {
        await fetch('/api/v1/auth/logout', {
          method: 'POST',
          headers: { Authorization: `Bearer ${token}` },
        });
      } catch {
        // Local session is cleared even if the API cannot be reached.
      }
    }
    sessionStorage.removeItem(TOKEN_KEY);
    setCurrentUser(null);
    setCurrentView('landing');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  if (checkingSession) {
    return <div className="min-h-screen bg-black" aria-label="Loading DeepShield" />;
  }

  if (currentView === 'login' || currentView === 'signup') {
    return (
      <AuthPortal
        key={currentView}
        initialMode={currentView}
        onAuthenticate={handleAuthenticate}
        onNavigateView={setCurrentView}
      />
    );
  }

  if (currentView === 'dashboard' && currentUser) {
    return <DashboardLayout key={currentUser.id} user={currentUser} onLogout={handleLogout} />;
  }

  return <LandingPage currentUser={currentUser} onNavigateView={setCurrentView} />;
}
