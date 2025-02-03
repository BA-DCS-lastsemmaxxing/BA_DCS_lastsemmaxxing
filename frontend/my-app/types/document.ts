export interface Document {
  id: BigInteger;
  name: string;
  uploadedAt: string;
  status: 'processing' | 'completed' | 'failed';
  summary?: string;
  tags?: string[];
} 