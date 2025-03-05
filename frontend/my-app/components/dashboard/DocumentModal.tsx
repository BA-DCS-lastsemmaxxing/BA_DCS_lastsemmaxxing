'use client';

import { useState } from 'react';
import { Document } from '@/types/document';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from '@/components/ui/dialog';
import { Badge } from '@/components/ui/badge';
import { getDownloadLink } from '@/service/classification';
import { Icons } from '@/components/Icons';

interface DocumentModalProps {
  isOpen: boolean;
  onOpenChange: (open: boolean) => void;
  document: Document | null;
}

export function DocumentModal({ isOpen, onOpenChange, document }: DocumentModalProps) {
  const [isDownloading, setIsDownloading] = useState(false);

  if (!document) return null;

  const isLLMBased = document.summary !== null && document.summary !== undefined;
  const isRuleBased = document.confidence !== null && document.confidence !== undefined;

  const handleDownload = async () => {
    try {
      setIsDownloading(true);
      const data = await getDownloadLink(String(document.id));
      
      // Use window.document instead of document prop
      const link = window.document.createElement('a');
      link.href = data.downloadUrl;
      link.download = document.name;
      window.document.body.appendChild(link);
      link.click();
      window.document.body.removeChild(link);
    } catch (error) {
      console.error('Download failed:', error);
    } finally {
      setIsDownloading(false);
    }
  };

  return (
    <Dialog open={isOpen} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <div className="flex items-center justify-between">
            <DialogTitle>{document.name}</DialogTitle>
            <button
              onClick={handleDownload}
              disabled={isDownloading}
              className="flex items-center gap-2 px-3 py-1 text-sm bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
            >
              {isDownloading ? (
                <Icons.Loader className="h-4 w-4 animate-spin" />
              ) : (
                <Icons.Download className="h-4 w-4" />
              )}
              {isDownloading ? 'Downloading...' : 'Download'}
            </button>
          </div>
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