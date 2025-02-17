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

  console.log(document);

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
              <p className="text-gray-600">{document.summary}</p>
              
              <div className="flex flex-wrap gap-2">
                {document.topics?.map(topic => (
                  <Badge key={topic} variant="secondary">
                    {topic}
                  </Badge>
                ))}
              </div>
              <Badge className="bg-green-500 text-white">{document.classification}</Badge>
            </>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
} 