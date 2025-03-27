import { useState, useEffect } from 'react';
import { Document } from '@/types/document';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog';
import { Badge } from '@/components/ui/badge';
import { getDownloadLink, sendFeedback } from '@/service/documentApi';
import { Icons } from '@/components/Icons';
import { Textarea } from '@/components/ui/textarea';
import { Button } from '@/components/ui/button';
import ClassificationFilter from '@/components/dashboard/ClassificationFilter';
import { configService } from '@/service/config';
import { useToast } from '@/hooks/use-toast';

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
  const [feedbackMode, setFeedbackMode] = useState<'viewing' | 'editing'>('viewing');
  const [userCategory, setUserCategory] = useState('');
  const [feedbackText, setFeedbackText] = useState('');
  const { toast } = useToast();
  
  // Use useEffect to initialize feedback form with existing data when document changes
  useEffect(() => {
    if (document) {
      setFeedbackMode('viewing');
      setUserCategory(document.user_corrected_category || '');
      setFeedbackText(document.feedback || '');
    }
  }, [document?.id]);
  
  if (!document) return null;

  // Check if document has previous feedback
  const hasPreviousFeedback = document.user_corrected_category || document.feedback;
  
  const isLLMBased = document.summary !== null && document.summary !== undefined;
  const isRuleBased = document.confidence !== null && document.confidence !== undefined;
  
  const handleDownload = async () => {
    try {
      setIsDownloading(true);
      console.log("Getting download for: ", document.id);
      const data = await getDownloadLink(document.id);
      
      if (!data || !data["download_url"]) {
        throw new Error("Download link not found in response.");
      }
      
      // Open the download link in a new tab
      const newTab = window.open(data["download_url"], '_blank');
      if (!newTab) {
        console.error("Failed to open download link in a new tab.");
      }
    } catch (error) {
      console.error('Download failed:', error);
    } finally {
      setIsDownloading(false);
    }
  };

  const handleFeedbackSubmit = async () => {
    // Validation: Ensure both category and feedback are provided
    if (!userCategory || !feedbackText) {
      toast({
        variant: "destructive",
        title: "Error",
        description: "Please fill in both the category and feedback."
      });
      return;
    }
  
    try {
      // Sending feedback to the API
      const response = await sendFeedback(document.id, userCategory, feedbackText)
      console.log("Feedback response: ", response)
      
      toast({
        title: "Success",
        variant: "success",
        description: "Feedback submitted successfully!"
      });
      
      // Update the document object with the new feedback (this would ideally be handled by refreshing data)
      document.user_corrected_category = userCategory;
      document.feedback = feedbackText;
      
      // Return to viewing mode
      setFeedbackMode('viewing');
    } catch (error) {
      console.error('Submission error:', error);
      toast({
        variant: "destructive",
        title: "Error",
        description: error instanceof Error ? error.message : 'Failed to submit feedback'
      });
    }
  };
  
  return (
    <Dialog open={isOpen} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg max-h-[80vh] overflow-y-auto">
        <DialogHeader>
          <div className="flex items-center justify-between">
            <DialogTitle className="pr-2 break-all" title={document.name}>
              {document.name}
            </DialogTitle>
            <button
              onClick={handleDownload}
              disabled={isDownloading}
              className="flex-shrink-0 flex items-center gap-2 px-3 py-1 text-sm bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
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
              <div className="mt-6 border-t pt-4">
                <div className="flex justify-between items-center mb-2">
                  <p className="text-sm font-medium text-gray-700">Classification Feedback</p>
                  
                  {hasPreviousFeedback && feedbackMode === 'viewing' && (
                    <Button 
                      variant="outline" 
                      size="sm"
                      onClick={() => setFeedbackMode('editing')}
                    >
                      Edit Feedback
                    </Button>
                  )}
                </div>
                
                {hasPreviousFeedback && feedbackMode === 'viewing' ? (
                  // Display existing feedback in view mode
                  <div className="space-y-3 bg-gray-50 p-3 rounded-md">
                    <div>
                      <p className="text-xs text-gray-500">Corrected Category:</p>
                      <p className="font-medium">{document.user_corrected_category}</p>
                    </div>
                    <div>
                      <p className="text-xs text-gray-500">Feedback:</p>
                      <p className="text-sm">{document.feedback}</p>
                    </div>
                  </div>
                ) : (
                  // Show feedback form in edit mode
                  <div>
                    <p className="text-sm text-gray-700 mb-2">Was this classification accurate?</p>
                    <div className="flex gap-3 mb-4">
                      <Button
                        variant="outline"
                        onClick={() => {
                          setUserCategory(document.classification || '');
                          setFeedbackText('Classification is correct');
                          handleFeedbackSubmit();
                        }}
                      >
                        👍 Yes
                      </Button>
                      <Button
                        variant="outline"
                        onClick={() => {
                          // Just open the form for correction
                          setFeedbackMode('editing');
                        }}
                      >
                        👎 No
                      </Button>
                    </div>
                    
                    {feedbackMode === 'editing' && (
                      <div className="space-y-3">
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

                        <div className="flex gap-2">
                          <Button
                            variant="outline"
                            onClick={() => {
                              if (hasPreviousFeedback) {
                                // Reset to original values
                                setUserCategory(document.user_corrected_category || '');
                                setFeedbackText(document.feedback || '');
                                setFeedbackMode('viewing');
                              } else {
                                setUserCategory('');
                                setFeedbackText('');
                              }
                            }}
                          >
                            Cancel
                          </Button>
                          <Button
                            onClick={handleFeedbackSubmit}
                          >
                            Submit Feedback
                          </Button>
                        </div>
                      </div>
                    )}
                  </div>
                )}
              </div>
              {/* ---------- Feedback UI Ends Here ---------- */}
            </>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
