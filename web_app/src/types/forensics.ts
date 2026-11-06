export type AppView = 'landing' | 'login' | 'signup' | 'dashboard';

export type DashboardTab = 'overview' | 'scanner' | 'history' | 'benchmarks' | 'api';

export interface UserProfile {
  id: string;
  name: string;
  email: string;
  createdAt?: string;
}

export interface PhotoScanSignals {
  aiGeneratedProbability: number;
  faceManipulationProbability: number;
  facesDetected: number;
  facesAnalyzed: number;
  modelVersion: string;
  faceModelVersion: string;
  decisionThreshold: number;
  faceManipulationPrediction: string;
}

export interface MediaScanResult {
  caseId: string;
  timestamp: string;
  title: string;
  mediaType: 'image' | 'video';
  prediction: string;
  fakeProbability: number;
  confidence: number;
  threshold: number;
  modelVersion?: string;
  framesAnalyzed?: number;
  noFaceFrames?: number;
  aggregationMethod?: string;
  photoSignals?: PhotoScanSignals;
  analystNotes: string;
}

export interface BackendHealth {
  status: string;
  model_loaded?: boolean;
  model_version?: string | null;
  model_error?: string | null;
  face_model_version?: string | null;
  ffpp_image_model_loaded?: boolean;
  ffpp_video_model_loaded?: boolean;
  ffpp_image_model_version?: string | null;
  ffpp_model_error?: string | null;
}
