export interface Topic {
  topic_name: string;
  document_count: number;
  created_at: string;
  status: 'Pending' | 'Completed' | 'Failed';
} 