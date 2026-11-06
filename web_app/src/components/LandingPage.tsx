import React, { useState } from 'react';
import {
  Infinity,
  ChevronDown,
  Menu,
  X,
  Scan,
  Layers,
  Cpu,
  Video,
  Smartphone,
  Server,
  AlertTriangle,
  CheckCircle2,
  ArrowRight,
  Lock
} from 'lucide-react';
import { AppView, UserProfile } from '../types/forensics';
import { BG_VIDEO } from '../data/siteConfig';

interface LandingPageProps {
  currentUser: UserProfile | null;
  onNavigateView: (view: AppView) => void;
}

export const LandingPage: React.FC<LandingPageProps> = ({
  currentUser,
  onNavigateView
}) => {
  const [menuOpen, setMenuOpen] = useState(false);

  const navLinks = [
    { label: 'Home', href: '#hero', active: true },
    { label: 'Pipelines', href: '#pipelines', dropdown: true },
    { label: 'Benchmarks', href: '#benchmarks' },
    { label: 'Guidelines', href: '#guidelines' }
  ];

  return (
    <div className="w-full min-h-screen bg-black text-white selection:bg-white selection:text-black">
      {/* ============================================================ */}
      {/* 1. FULL-SCREEN LIQUID GLASS VIDEO HERO */}
      {/* ============================================================ */}
      <div id="hero" className="relative w-full h-screen overflow-hidden">
        {/* Looping Background Video */}
        <video
          className="absolute inset-0 w-full h-full object-cover z-0 pointer-events-none"
          autoPlay
          muted
          loop
          playsInline
          src={BG_VIDEO}
        />

        {/* Solid Dark Contrast Scrims (Zero Gradients) */}
        <div className="absolute inset-0 bg-black/50 z-10 pointer-events-none" />
        <div className="absolute inset-0 bg-black/25 z-10 pointer-events-none" />

        {/* Top Navbar */}
        <header className="absolute top-0 left-0 right-0 z-20 flex items-center justify-between gap-8 px-5 sm:px-8 py-5">
          {/* Zone 1: Brand Wordmark */}
          <a
            href="#hero"
            className="flex items-center gap-2 text-white font-medium text-base whitespace-nowrap shrink-0"
          >
            <Infinity size={22} strokeWidth={1.5} />
            <span>DeepShield</span>
          </a>

          {/* Zone 2: Center Nav Pill */}
          <nav className="hidden md:flex liquid-glass items-center gap-1 rounded-xl px-2 py-2">
            {navLinks.map((link) => (
              <a
                key={link.label}
                href={link.href}
                className={`flex items-center gap-0.5 px-3 py-1.5 rounded-md text-sm transition-colors whitespace-nowrap shrink-0 ${
                  link.active
                    ? 'bg-white/15 text-white'
                    : 'text-white/70 hover:text-white'
                }`}
              >
                <span>{link.label}</span>
                {link.dropdown && <ChevronDown size={13} className="mt-px" />}
              </a>
            ))}
          </nav>

          {/* Zone 3: Right Auth / Dashboard CTAs */}
          <div className="hidden md:flex items-center gap-3 shrink-0">
            {currentUser ? (
              <button
                onClick={() => onNavigateView('dashboard')}
                className="bg-white text-black text-sm font-medium px-4 py-2.5 rounded-full hover:bg-white/90 transition-colors cursor-pointer whitespace-nowrap shrink-0"
              >
                Open Dashboard ({currentUser.name.split(' ')[0]})
              </button>
            ) : (
              <>
                <button
                  onClick={() => onNavigateView('login')}
                  className="liquid-glass text-white text-sm font-medium px-4 py-2.5 rounded-full hover:bg-white/5 transition-colors cursor-pointer whitespace-nowrap shrink-0"
                >
                  Log in
                </button>
                <button
                  onClick={() => onNavigateView('signup')}
                  className="bg-white text-black text-sm font-medium px-4 py-2.5 rounded-full hover:bg-white/90 transition-colors cursor-pointer whitespace-nowrap shrink-0"
                >
                  Begin Now
                </button>
              </>
            )}
          </div>

          {/* Mobile Menu Button */}
          <button
            onClick={() => setMenuOpen(!menuOpen)}
            className="md:hidden liquid-glass text-white p-2 rounded-lg cursor-pointer"
            aria-label="Toggle Menu"
          >
            {menuOpen ? <X size={18} /> : <Menu size={18} />}
          </button>
        </header>

        {/* Mobile Dropdown Menu */}
        {menuOpen && (
          <div className="absolute top-[72px] left-4 right-4 z-30 md:hidden liquid-glass-card rounded-2xl p-4 flex flex-col gap-1">
            {navLinks.map((link) => (
              <a
                key={link.label}
                href={link.href}
                onClick={() => setMenuOpen(false)}
                className="flex items-center justify-between w-full px-4 py-3 rounded-lg text-sm text-white/80 hover:text-white hover:bg-white/10 transition-colors"
              >
                <span>{link.label}</span>
                {link.dropdown && <ChevronDown size={13} className="mt-px" />}
              </a>
            ))}
            <div className="flex gap-2 mt-2 pt-3 border-t border-white/10">
              <button
                onClick={() => {
                  setMenuOpen(false);
                  onNavigateView('login');
                }}
                className="flex-1 liquid-glass text-white text-sm font-medium px-4 py-2.5 rounded-full hover:bg-white/5 transition-colors cursor-pointer"
              >
                Log in
              </button>
              <button
                onClick={() => {
                  setMenuOpen(false);
                  onNavigateView('signup');
                }}
                className="flex-1 bg-white text-black text-sm font-medium px-4 py-2.5 rounded-full hover:bg-white/90 transition-colors cursor-pointer"
              >
                Begin Now
              </button>
            </div>
          </div>
        )}

        {/* Hero Content (Bottom-Left) */}
        <div className="absolute bottom-0 left-0 z-20 px-6 sm:px-12 pb-10 sm:pb-16 max-w-2xl">
          <div className="flex items-center gap-2 text-xs text-white/70 mb-3">
            <span>Flutter Mobile Client</span>
            <span aria-hidden="true">Â·</span>
            <span>FastAPI Inference Engine</span>
            <span aria-hidden="true">Â·</span>
            <span>FaceForensics++ C23</span>
          </div>

          <h1 className="text-white text-4xl sm:text-5xl lg:text-6xl font-medium leading-tight tracking-tight mb-4 text-balance">
            Review media. Understand the signals.
          </h1>

          <p className="text-white/60 text-sm sm:text-base leading-relaxed mb-7 max-w-md">
            DeepShield analyzes photos and videos for potential AI-generation and manipulation signals. Review model estimates alongside the media source and other context.
          </p>

          <div className="flex flex-wrap items-center gap-3">
            <button
              onClick={() => onNavigateView(currentUser ? 'dashboard' : 'login')}
              className="bg-white text-black text-sm sm:text-base font-medium px-6 sm:px-7 py-3 rounded-full hover:bg-white/90 transition-colors cursor-pointer flex items-center gap-2 whitespace-nowrap shrink-0"
            >
              <Scan size={17} />
              <span>Start Today</span>
            </button>
            <button
              onClick={() => onNavigateView(currentUser ? 'dashboard' : 'signup')}
              className="liquid-glass text-white text-sm sm:text-base font-medium px-6 sm:px-7 py-3 rounded-full hover:bg-white/5 transition-colors cursor-pointer whitespace-nowrap shrink-0"
            >
              Create an account
            </button>
          </div>
        </div>
      </div>

      {/* ============================================================ */}
      {/* 2. MULTI-MODEL ARCHITECTURE & PIPELINES */}
      {/* ============================================================ */}
      <section id="pipelines" className="py-20 px-6 sm:px-12 bg-neutral-950 border-t border-white/10">
        <div className="max-w-7xl mx-auto">
          <div className="flex flex-col md:flex-row md:items-end justify-between gap-4 mb-12 pb-6 border-b border-white/10">
            <div>
              <div className="flex items-center gap-2 text-xs text-white/50 mb-2">
                <span>01. Detection Architecture</span>
                <span aria-hidden="true">Â·</span>
                <span>FastAPI + Pretrained &amp; Custom Weights</span>
              </div>
              <h2 className="text-3xl sm:text-4xl font-semibold tracking-tight text-white">
                Multi-Path Machine Learning Forensics
              </h2>
            </div>
            <p className="text-sm text-white/60 max-w-md leading-relaxed">
              DeepShield separates global AI synthesis signals from localized facial manipulation and evaluates video keyframes without requiring heavy temporal motion networks.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {/* Path 1 */}
            <div className="liquid-glass rounded-2xl p-6 border border-white/15 flex flex-col justify-between">
              <div>
                <div className="text-xs text-white/50 mb-2">01. Dual-Model Photo API</div>
                <h3 className="text-lg font-semibold text-white mb-2">
                  Whole-Image &amp; Facial Manipulation
                </h3>
                <p className="text-sm text-white/65 leading-relaxed mb-6">
                  When a photo is uploaded, the FastAPI service runs a whole-image model for AI-generation signals and a separate model on detected face crops for manipulation signals.
                </p>
              </div>
              <div className="pt-4 border-t border-white/10 flex items-center justify-between text-xs text-white/50">
                <span>2 Pretrained Models</span>
                <span>Global + Face ROI</span>
              </div>
            </div>

            {/* Path 2 */}
            <div className="liquid-glass rounded-2xl p-6 border border-white/15 flex flex-col justify-between">
              <div>
                <div className="text-xs text-white/50 mb-2">02. Custom Deepfake Detector</div>
                <h3 className="text-lg font-semibold text-white mb-2">
                  FaceForensics++ EfficientNet-B0
                </h3>
                <p className="text-sm text-white/65 leading-relaxed mb-6">
                  A dedicated FaceForensics++ detector uses a custom-trained EfficientNet-B0 backbone evaluated on C23 compressed face-swap data. It targets blending seams, affine warping, and boundary compression mismatches.
                </p>
              </div>
              <div className="pt-4 border-t border-white/10 flex items-center justify-between text-xs text-white/50">
                <span>EfficientNet-B0</span>
                <span>Trained on FF++ C23</span>
              </div>
            </div>

            {/* Path 3 */}
            <div className="liquid-glass rounded-2xl p-6 border border-white/15 flex flex-col justify-between">
              <div>
                <div className="text-xs text-white/50 mb-2">03. Video Keyframe Averaging</div>
                <h3 className="text-lg font-semibold text-white mb-2">
                  Uniform Frame Sampling Pipeline
                </h3>
                <p className="text-sm text-white/65 leading-relaxed mb-6">
                  For video uploads, DeepShield samples a few uniform frames, scores each extracted frame with the image detection model, and averages the resulting probabilities. It does not analyze inter-frame motion with a dedicated 3D video model.
                </p>
              </div>
              <div className="pt-4 border-t border-white/10 flex items-center justify-between text-xs text-white/50">
                <span>Keyframe Averaging</span>
                <span>Low-Latency 2D Pass</span>
              </div>
            </div>
          </div>

          {/* System Components Row */}
          <div className="mt-6 grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="liquid-glass-subtle rounded-xl p-5 border border-white/10 flex items-start gap-3.5">
              <Smartphone size={20} className="text-white/80 shrink-0 mt-0.5" />
              <div>
                <h4 className="text-sm font-semibold text-white">Flutter Mobile Application</h4>
                <p className="text-xs text-white/60 leading-relaxed mt-1">
                  Allows field users to upload photos and videos directly from device storage or camera roll and inspect granular model scores and labels.
                </p>
              </div>
            </div>

            <div className="liquid-glass-subtle rounded-xl p-5 border border-white/10 flex items-start gap-3.5">
              <Server size={20} className="text-white/80 shrink-0 mt-0.5" />
              <div>
                <h4 className="text-sm font-semibold text-white">FastAPI Inference Backend</h4>
                <p className="text-xs text-white/60 leading-relaxed mt-1">
                  Processes incoming media uploads, runs face isolation and frame extraction, and returns structured JSON confidence scores and labels.
                </p>
              </div>
            </div>

            <div className="liquid-glass-subtle rounded-xl p-5 border border-white/10 flex items-start gap-3.5">
              <Cpu size={20} className="text-white/80 shrink-0 mt-0.5" />
              <div>
                <h4 className="text-sm font-semibold text-white">Auxiliary Flask Web Dashboard</h4>
                <p className="text-xs text-white/60 leading-relaxed mt-1">
                  Includes a separate standalone image model in the repository. Because its training details are undocumented, no accuracy claims are made for it.
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ============================================================ */}
      {/* 3. FACEFORENSICS++ C23 BENCHMARK EVALUATION */}
      {/* ============================================================ */}
      <section id="benchmarks" className="py-20 px-6 sm:px-12 bg-black border-t border-white/10">
        <div className="max-w-7xl mx-auto">
          <div className="flex flex-col md:flex-row md:items-end justify-between gap-4 mb-12 pb-6 border-b border-white/10">
            <div>
              <div className="flex items-center gap-2 text-xs text-white/50 mb-2">
                <span>02. Empirical Performance</span>
                <span aria-hidden="true">Â·</span>
                <span>Compression &amp; False-Positive Characteristics</span>
              </div>
              <h2 className="text-3xl sm:text-4xl font-semibold tracking-tight text-white">
                FaceForensics++ C23 Evaluation &amp; Limits
              </h2>
            </div>
            <p className="text-sm text-white/60 max-w-md leading-relaxed">
              This website does not publish benchmark figures here. Check the project's evaluation reports with their dataset split and model run before interpreting performance.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
            <article className="liquid-glass-subtle rounded-2xl border border-white/10 p-5">
              <div className="text-xs text-white/50 mb-2">01 · Data separation</div>
              <h3 className="text-base font-semibold text-white mb-2">Official dataset splits</h3>
              <p className="text-xs text-white/60 leading-relaxed">The FaceForensics++ preparation pipeline follows the official train, validation, and test splits to keep related source videos together.</p>
            </article>
            <article className="liquid-glass-subtle rounded-2xl border border-white/10 p-5">
              <div className="text-xs text-white/50 mb-2">02 · Model outputs</div>
              <h3 className="text-base font-semibold text-white mb-2">Estimates, not probabilities</h3>
              <p className="text-xs text-white/60 leading-relaxed">Scores summarize model behavior. They are not calibrated probabilities and may not transfer to unfamiliar or heavily compressed media.</p>
            </article>
            <article className="liquid-glass-subtle rounded-2xl border border-white/10 p-5">
              <div className="text-xs text-white/50 mb-2">03 · Human review</div>
              <h3 className="text-base font-semibold text-white mb-2">Keep context in the loop</h3>
              <p className="text-xs text-white/60 leading-relaxed">A low manipulation signal does not establish authenticity. Check provenance and independent evidence before sharing a conclusion.</p>
            </article>
          </div>
        </div>
      </section>

      {/* ============================================================ */}
      {/* 4. FORENSIC GUIDELINES & CALL TO ACTION */}
      {/* ============================================================ */}
      <section id="guidelines" className="py-20 px-6 sm:px-12 bg-neutral-950 border-t border-white/10">
        <div className="max-w-5xl mx-auto">
          <div className="liquid-glass rounded-2xl p-8 sm:p-10 border border-white/15 flex flex-col lg:flex-row items-start lg:items-center justify-between gap-8">
            <div className="space-y-3 max-w-xl">
              <div className="flex items-center gap-2 text-xs text-amber-300">
                <AlertTriangle size={15} />
                <span>Indicators for Review, Not Definitive Proof</span>
              </div>
              <h2 className="text-2xl sm:text-3xl font-semibold tracking-tight text-white">
                Ready to Inspect Media in the DeepShield Console?
              </h2>
              <p className="text-sm text-white/65 leading-relaxed">
                Sign in to upload media, receive estimates from the configured DeepShield services, and review your scan history in this browser.
              </p>
            </div>

            <div className="flex flex-wrap items-center gap-3 shrink-0">
              <button
                onClick={() => onNavigateView('login')}
                className="bg-white text-black text-sm font-semibold px-6 py-3 rounded-full hover:bg-white/90 transition-colors cursor-pointer flex items-center gap-2 whitespace-nowrap shrink-0"
              >
                <Lock size={15} />
                <span>Sign In to Console</span>
              </button>
              <button
                onClick={() => onNavigateView('signup')}
                className="liquid-glass text-white text-sm font-medium px-6 py-3 rounded-full hover:bg-white/10 transition-colors cursor-pointer flex items-center gap-2 whitespace-nowrap shrink-0"
              >
                <span>Create Account</span>
                <ArrowRight size={15} />
              </button>
            </div>
          </div>
        </div>
      </section>

      {/* ============================================================ */}
      {/* FOOTER */}
      {/* ============================================================ */}
      <footer className="py-10 px-6 sm:px-12 bg-black border-t border-white/10 text-xs text-white/50">
        <div className="max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2 text-white">
            <Infinity size={18} strokeWidth={1.5} />
            <span className="font-semibold">DeepShield</span>
            <span className="text-white/30" aria-hidden="true">Â·</span>
            <span className="text-white/50">Photo &amp; video media review</span>
          </div>
          <div className="flex items-center gap-6">
            <button
              onClick={() => onNavigateView('login')}
              className="hover:text-white transition-colors cursor-pointer"
            >
              Analyst Login
            </button>
            <button
              onClick={() => onNavigateView('signup')}
              className="hover:text-white transition-colors cursor-pointer"
            >
              Create Account
            </button>
          </div>
        </div>
      </footer>
    </div>
  );
};
