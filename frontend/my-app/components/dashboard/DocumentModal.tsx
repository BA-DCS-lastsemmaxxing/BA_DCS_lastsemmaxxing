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
import { getDownloadLink } from '@/service/documentApi';
import { Icons } from '@/components/Icons';
import { Textarea } from '@/components/ui/textarea';
import { Button } from '@/components/ui/button';
import ClassificationFilter from '@/components/dashboard/ClassificationFilter';
import { configService } from '@/service/config';

const { api } = configService.get();



interface DocumentModalProps {
  isOpen: boolean;
  onOpenChange: (open: boolean) => void;
  document: Document | null;
}




function getCookie(name: string): string | undefined {
    const cookies = document.cookie.split("; ");
    for (const cookie of cookies) {
        const [cookieName, cookieValue] = cookie.split("=");
        if (cookieName === name) {
            return decodeURIComponent(cookieValue);
        }
    }
    return undefined;
}


export function DocumentModal({ isOpen, onOpenChange, document }: DocumentModalProps) {
  const [isDownloading, setIsDownloading] = useState(false);
  const [feedbackTriggered, setFeedbackTriggered] = useState(false);
  const [userCategory, setUserCategory] = useState('');
  const [feedbackText, setFeedbackText] = useState('');
  const [isFeedbackCorrected, setIsFeedbackCorrected] = useState(false);
  const [isFeedbackSubmitted, setIsFeedbackSubmitted] = useState(false);  // New state for feedback submission

  if (!document) return null;

  const isLLMBased = document.summary !== null && document.summary !== undefined;
  const isRuleBased = document.confidence !== null && document.confidence !== undefined;

  
  const handleDownload = async () => {
    try {
      setIsDownloading(true);
      console.log("Getting download for: ", document.id)
      const data = await getDownloadLink(document.id);
      
      console.log(data)
      if (!data || !data["download_url"]) {
        throw new Error("Download link not found in response.");
      }
      console.log('Download link:', data["download_url"]);

      // Open the download link in a new tab
      const newTab = window.open(data["download_url"], '_blank');

      // check if the new tab was opened
      if (newTab) {
        newTab.focus();
      } else {
        console.error("Failed to open download link in a new tab.")
      }
    } catch (error) {
      console.error('Download failed:', error);
    } finally {
      setIsDownloading(false);
    }
  };

  const handleFeedbackSubmit = async () => {
    // If user clicked "Yes", set feedback as 'N.A.'
    const finalCategory = userCategory || 'N.A.';
    const finalFeedback = feedbackText || '';
  
    // Validation: Ensure both category and feedback are provided
    if (!finalCategory || !finalFeedback) {
      alert("Please fill in both the category and feedback.");
      return;
    }
  
    // Sending feedback to the API without error handling
    const response = await fetch(`${api.backendUrl}/feedback?document_id=${encodeURIComponent(String(document.id))}`, {
      method: 'POST',
      headers: {
        "Authorization": `${getCookie("CognitoToken")}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        user_corrected_category: finalCategory,
        feedback: finalFeedback,
      }),
    });
  
    // Handle the API response
    const result = await response.json();
  
    if (response.ok) {
      console.log('Feedback submitted successfully:', result);
      alert(result.message || 'Feedback submitted successfully!');
      setIsFeedbackSubmitted(true);  // Set feedback as submitted
      setIsFeedbackCorrected(false);
      setFeedbackTriggered(false);
      setUserCategory('');
      setFeedbackText('');
    } else {
      console.error('Submission error:', result);
      alert(result.error || 'Failed to submit feedback');
    }
  };
  
  
  return (
    <Dialog open={isOpen} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg max-h-[80vh] overflow-y-auto">
        <DialogHeader>
          <div className="flex items-center justify-between max-w-full">
            <DialogTitle className="max-w-full break-all">{document.name}</DialogTitle>
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
                      setIsFeedbackCorrected(false);
                      setFeedbackTriggered(false);
                      setIsFeedbackSubmitted(true);  // Disable further editing if "Yes"
                      setUserCategory('N.A.');  // Set to 'N.A.' when "Yes" is clicked
                      setFeedbackText('');  // Clear the feedback text
                    }}
                    disabled={isFeedbackSubmitted}  // Disable "Yes" after submission
                  >
                    👍 Yes
                  </Button>
                  <Button
                    variant="outline"
                    onClick={() => {
                      setIsFeedbackCorrected(true);
                      setFeedbackTriggered(true);
                    }}
                  >
                    👎 No
                  </Button>
                </div>
              </div>

              {isFeedbackSubmitted ? (
                <p className="text-green-500 text-center">Thanks for the feedback!</p>
              ) : isFeedbackCorrected ? (
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

                  <Button
                    className="text-sm font-medium text-black border border-black bg-transparent hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-black"
                    onClick={handleFeedbackSubmit}
                  >
                    Submit Feedback
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
