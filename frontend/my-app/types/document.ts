export interface Document {
  id: string;
  name: string;
  uploadedAt: string;
  status: 'processing' | 'completed' | 'failed';
  summary?: string;
  topics?: string[];
  classification?: string;
  confidence?: number;
} 