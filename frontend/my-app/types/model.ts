export interface TrainingDocument {
  id: string;
  name: string;
  originalTopic: string;
  correctedTopic: string;
  correctedAt: string;
  confidence: number;
  justification: string;
}

export interface Topic {
  topic_name: string;
  document_count: number;
  created_at: string;
} 