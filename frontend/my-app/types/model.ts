export interface TrainingDocument {
  id: string;
  name: string;
  originalTopic: string;
  correctedTopic: string;
  correctedAt: string;
  confidence: number;
}

export interface Topic {
  name: string;
  documentCount: number;
  createdAt: string;
} 