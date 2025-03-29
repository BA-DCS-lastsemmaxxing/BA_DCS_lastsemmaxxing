export interface Document {
  id: string;
  name: string;
  uploadedAt: string;
  status: 'processing' | 'completed' | 'failed';
  summary?: string;
  topics?: string[];
  classification?: string;
  confidence?: number;
  user_corrected_category?: string;
  feedback?: string;
  classification_type: string;
} 