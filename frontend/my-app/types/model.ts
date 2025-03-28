export interface Topic {
  topic_name: string;
  document_count: number;
  created_at: string;
  status: 'Pending' | 'Completed' | 'Failed';
} 

export interface ModelState {
    isRetraining: boolean;
    type: string;
    startedAt: Date;
}