import { useState } from 'react';
import { Document } from '@/types/document';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog';
import { Badge } from '@/components/ui/badge';
import { getDownloadLink } from '@/service/classification';
import { Icons } from '@/components/Icons';
import { Textarea } from '@/components/ui/textarea';
import { Button } from '@/components/ui/button';
import ClassificationFilter from '@/components/dashboard/ClassificationFilter'; // Import the ClassificationFilter component

interface DocumentModalProps {
  isOpen: boolean;
  onOpenChange: (open: boolean) => void;
  document: Document | null;
}

export function DocumentModal({ isOpen, onOpenChange, document }: DocumentModalProps) {
  const [isDownloading, setIsDownloading] = useState(false);
  const [feedbackTriggered, setFeedbackTriggered] = useState(false);
  const [userCategory, setUserCategory] = useState('');
  const [feedbackText, setFeedbackText] = useState('');
  const [isFeedbackCorrected, setIsFeedbackCorrected] = useState(false); // Track if the user chose "No"

  if (!document) return null;

  const isLLMBased = document.summary !== null && document.summary !== undefined;
  const isRuleBased = document.confidence !== null && document.confidence !== undefined;

  const handleDownload = async () => {
    try {
      setIsDownloading(true);
      const data = await getDownloadLink(String(document.id));

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

  const handleFeedbackSubmit = () => {
    console.log('Feedback submitted:', {
      documentId: document.id,
      userCategory,
      feedbackText,
    });
    // Optional: Show toast here or reset state
    setIsFeedbackCorrected(false); // Reset after submitting
    setFeedbackTriggered(false); // Hide the feedback form
  };

  return (
    <Dialog open={isOpen} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg max-h-[80vh] overflow-y-auto">
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
          <DialogDescription>Uploaded on {document.uploadedAt}</DialogDescription>
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
                <Badge className="bg-green-500 text-white">{document.classification}</Badge>
              </div>

              {isLLMBased && <p className="text-gray-600">{document.summary}</p>}

              {document.confidence && isRuleBased && (
                <div className="flex items-center gap-2 text-gray-600">
                  <span>Confidence Score:</span>
                  <span className="font-medium">{(document.confidence * 100).toFixed(1)}%</span>
                </div>
              )}

              <div className="flex flex-wrap gap-2">
                {document.topics?.map((topic) => (
                  <Badge key={topic} variant="secondary">
                    {topic}
                  </Badge>
                ))}
              </div>

              {/* ---------- Feedback UI Starts Here ---------- */}
              <div className="mt-6">
                <p className="text-sm text-gray-700 mb-2">Was this classification accurate?</p>
                <div className="flex gap-3">
                  <Button
                    variant="outline"
                    onClick={() => {
                      setIsFeedbackCorrected(false); // User chose "Yes"
                      setFeedbackTriggered(false); // Hide the feedback form
                    }}
                  >
                    👍 Yes
                  </Button>
                  <Button
                    variant="outline"
                    onClick={() => {
                      setIsFeedbackCorrected(true); // User chose "No"
                      setFeedbackTriggered(true); // Show feedback form
                    }}
                  >
                    👎 No
                  </Button>
                </div>
              </div>

              {isFeedbackCorrected ? (
                <div className="mt-4 space-y-3">
                  <div>
                    <label className="text-sm font-medium text-gray-700 block mb-1">
                      User Corrected Category
                    </label>
                    <ClassificationFilter
                      classificationFilter={userCategory}
                      setClassificationFilter={setUserCategory}
                    />
                  </div>

                  <div>
                    <label className="text-sm font-medium text-gray-700 block mb-1">
                      Feedback
                    </label>
                    <Textarea
                      placeholder="Tell us why you agree or disagree..."
                      value={feedbackText}
                      onChange={(e) => setFeedbackText(e.target.value)}
                    />
                  </div>

                  <Button className="mt-2" onClick={handleFeedbackSubmit}>
                    ✅ Submit Feedback
                  </Button>
                </div>
              ) : (
                feedbackTriggered && (
                  <p className="text-green-500 text-center">Thank you for your feedback!</p>
                )
              )}
              {/* ---------- Feedback UI Ends Here ---------- */}
            </>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
