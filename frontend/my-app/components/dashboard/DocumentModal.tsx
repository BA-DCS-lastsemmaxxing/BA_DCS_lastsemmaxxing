'use client';

import { Document } from '@/types/document';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from '@/components/ui/dialog';
import { Badge } from '@/components/ui/badge';

interface DocumentModalProps {
  isOpen: boolean;
  onOpenChange: (open: boolean) => void;
  document: Document | null;
}

export function DocumentModal({ isOpen, onOpenChange, document }: DocumentModalProps) {
  if (!document) return null;

  const isLLMBased = document.summary !== null && document.summary !== undefined;
  const isRuleBased = document.confidence !== null && document.confidence !== undefined;

  return (
    <Dialog open={isOpen} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{document.name}</DialogTitle>
          <DialogDescription>
            Uploaded on {document.uploadedAt}
          </DialogDescription>
        </DialogHeader>

        <div className="mt-4 space-y-4">
          {document.status === 'processing' ? (
            <p className="text-yellow-600 text-center italic">
              Looks like this document is still being processed... please try again later!
            </p>
          ) : (
            <>
              <div className="flex items-center gap-2">
                <Badge variant="outline" className="text-blue-600 border-blue-600">
                  {isLLMBased ? 'LLM-based' : 'Rule-based'}
                </Badge>
                <Badge className="bg-green-500 text-white">
                  {document.classification}
                </Badge>
              </div>

              {isLLMBased && (
                <p className="text-gray-600">{document.summary}</p>
              )}

              {document.confidence && isRuleBased && (
                <div className="flex items-center gap-2 text-gray-600">
                  <span>Confidence Score:</span>
                  <span className="font-medium">{(document.confidence * 100).toFixed(1)}%</span>
                </div>
              )}
              
              <div className="flex flex-wrap gap-2">
                {document.topics?.map(topic => (
                  <Badge key={topic} variant="secondary">
                    {topic}
                  </Badge>
                ))}
              </div>
            </>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
} 