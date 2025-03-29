'use client';

import { useEffect, useState } from 'react';
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ModelState, Topic } from '@/types/model';
import { Document } from '@/types/document';
import { getAllTopics, addNewTopic, removeTopic, feedbackRetraining } from '@/service/modelApi';
import { getCorrectedDocuments, fetchUploadUrl } from '@/service/documentApi';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Checkbox } from "@/components/ui/checkbox";
import { useToast } from "@/hooks/use-toast";
import { TopicFileUpload } from '@/components/model-management/TopicFileUpload';
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { Icons } from '@/components/Icons';

// Component to display when model is retraining
function ModelRetrainingState({ modelState }: { modelState: ModelState }) {
  // Calculate time elapsed since retraining started
  const startTime = new Date(modelState.startedAt);
  const [timeElapsed, setTimeElapsed] = useState<string>('');
  
  useEffect(() => {
    const calculateTimeElapsed = () => {
      const now = new Date();
      const diffMs = now.getTime() - startTime.getTime();
      const diffMins = Math.floor(diffMs / 60000);
      const diffHrs = Math.floor(diffMins / 60);
      const remainingMins = diffMins % 60;
      
      if (diffHrs > 0) {
        setTimeElapsed(`${diffHrs}h ${remainingMins}m`);
      } else {
        setTimeElapsed(`${diffMins}m`);
      }
    };
    
    calculateTimeElapsed();
    const interval = setInterval(calculateTimeElapsed, 60000); // Update every minute
    
    return () => clearInterval(interval);
  }, [startTime]);
  
  // Get appropriate message based on retraining type
  const getRetrainingMessage = () => {
    switch (modelState.type) {
      case "Feedback Retraining":
        return "The model is being retrained with user feedback to improve classification accuracy.";
      case "Adding New Topic":
        return "A new topic is being added to the model. This process involves training the model to recognize this topic.";
      case "Removing Topic":
        return "A topic is being removed from the model. This requires retraining the model without this topic.";
      default:
        return "Model retraining is in progress.";
    }
  };
  
  return (
    <div className="flex flex-col items-center justify-center min-h-[70vh] p-8">
      <div className="bg-white rounded-lg shadow-lg p-8 max-w-2xl w-full">
        <div className="flex items-center justify-center mb-6">
          <div className="bg-blue-100 p-3 rounded-full">
            <Icons.RefreshCw className="h-8 w-8 text-blue-600 animate-spin" />
          </div>
        </div>
        
        <h1 className="text-2xl font-bold text-center mb-2">Model Retraining in Progress</h1>
        <p className="text-gray-600 text-center mb-6">{modelState.type}</p>
        <p className="text-gray-500 text-center mb-6">{getRetrainingMessage()}</p>
        
        <div className="space-y-6">
          <div>
            <div className="flex justify-between mb-2">
              <span className="text-sm font-medium">Retraining Progress</span>
              <span className="text-sm font-medium">In Progress</span>
            </div>
          </div>
          
          <div className="grid grid-cols-2 gap-4 text-center">
            <div className="bg-gray-50 p-4 rounded-lg">
              <p className="text-sm text-gray-500">Started</p>
              <p className="font-medium">{startTime.toLocaleString()}</p>
            </div>
            <div className="bg-gray-50 p-4 rounded-lg">
              <p className="text-sm text-gray-500">Time Elapsed</p>
              <p className="font-medium">{timeElapsed}</p>
            </div>
          </div>
          
          <div className="bg-yellow-50 border-l-4 border-yellow-400 p-4">
            <div className="flex">
              <div className="flex-shrink-0">
                <Icons.AlertTriangle className="h-5 w-5 text-yellow-400" />
              </div>
              <div className="ml-3">
                <p className="text-sm text-yellow-700">
                  The model management features are temporarily unavailable during retraining. 
                  Please check back later.
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// Empty state component for when no documents have feedback
function NoFeedbackDocuments() {
  return (
    <div className="text-center py-12 bg-white rounded-lg shadow">
      <div className="mx-auto flex justify-center">
        <Icons.FileX className="h-12 w-12 text-gray-400" />
      </div>
      <h3 className="mt-2 text-lg font-medium text-gray-900">No feedback documents</h3>
      <p className="mt-1 text-sm text-gray-500">
        There are no documents with user feedback available for retraining.
      </p>
      <p className="mt-1 text-sm text-gray-500">
        When users provide feedback on document classifications, they will appear here.
      </p>
    </div>
  );
}

export default function ModelManagement() {
  const [selectedDocuments, setSelectedDocuments] = useState<Set<string>>(new Set());
  const [isDeleteDialogOpen, setIsDeleteDialogOpen] = useState(false);
  const [topicToDelete, setTopicToDelete] = useState<Topic | null>(null);
  const [isAddTopicDialogOpen, setIsAddTopicDialogOpen] = useState(false);
  const [newTopicName, setNewTopicName] = useState('');
  const { toast } = useToast();
  
  // Initialize modelState with null instead of undefined
  const [modelState, setModelState] = useState<ModelState | null>(null);
  const [documents, setDocuments] = useState<Document[]>([]);
  const [topics, setTopics] = useState<Topic[]>([]);
  const [topicFiles, setTopicFiles] = useState<File[] | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isAddingTopic, setIsAddingTopic] = useState(false);

  const fetchTopics = async () => {
    try {
      const response = await getAllTopics();
      console.log("Fetch topics response:", response);
      if ('state' in response) {
        setModelState(response.state);
      } else {
        setTopics(response.topics);
        setModelState(null); // Clear model state if we get topics
      }
    } catch (error) {
      console.error("Error fetching topics:", error);
    }
  };
  
  const fetchCorrectedDocuments = async () => {
    try {
      const response = await getCorrectedDocuments();
      console.log("Fetch documents response:", response);
      if ('state' in response) {
        setModelState(response.state);
      } else {
        setDocuments(response.documents);
        setModelState(null); // Clear model state if we get documents
      }
    } catch (error) {
      console.error("Error fetching corrected documents:", error);
    }
  };
  
  useEffect(() => {
    setIsLoading(true);
    fetchTopics();
    fetchCorrectedDocuments();
    setIsLoading(false);
  }, []);

  const handleDocumentSelect = (docId: string) => {
    const newSelected = new Set(selectedDocuments);
    if (newSelected.has(docId)) {
      newSelected.delete(docId);
    } else {
      newSelected.add(docId);
    }
    setSelectedDocuments(newSelected);
  };

  const handleSelectAll = () => {
    if (selectedDocuments.size === documents.length) {
      setSelectedDocuments(new Set());
    } else {
      setSelectedDocuments(new Set(documents.map(doc => doc.id)));
    }
  };

  const handleStartRetraining = async () => {
    if (selectedDocuments.size === 0) {
      toast({
        title: "No documents selected",
        description: "Please select at least one document for retraining.",
        variant: "destructive"
      });
      return;
    }
    setIsLoading(true);
    // Filter documents to only include those that are selected
    const selectedDocs = documents.filter(doc => selectedDocuments.has(doc.id));
    
    console.log("Retraining documents: ", selectedDocs);
    
    try {
      // Call your API with the selected documents
      const response = await feedbackRetraining(selectedDocs);
      toast({
        title: "Retraining started",
        description: (
            <>
              Started retraining with ${selectedDocuments.size} documents.
              <br />
              This may take a few moments.
            </>
          ),
        variant: "success"
      });
      setTimeout(() => {
        

        fetchTopics();
        fetchCorrectedDocuments();
      }, 5000);
      setIsLoading(false);
      // Refresh the page to show retraining state
      fetchTopics();
      fetchCorrectedDocuments();
    } catch (error) {
      console.error("Error starting retraining:", error);
      toast({
        title: "Retraining failed",
        description: "There was an error starting the retraining process.",
        variant: "destructive"
      });
    }
  };

  const handleDeleteTopic = async () => {
    if (!topicToDelete) return;
    const response = await removeTopic(topicToDelete.topic_name);
    // Add your delete topic API call here
    console.log("Delete topic response: ", response);
    toast({
      title: "Topic deletion triggered",
      description: (
        <>
          Deleting topic: {topicToDelete.topic_name}
          <br />
          This may take a few moments.
        </>
      ),
      variant: "success"
    });
    
    setIsDeleteDialogOpen(false);
    setTopicToDelete(null);
    fetchTopics();
  };

  const handleAddTopic = async () => {
    if (!newTopicName.trim()) {
      toast({
        title: "Invalid topic name",
        description: "Please enter a valid topic name.",
        variant: "destructive"
      });
      return;
    }
    if (!topicFiles) {
      toast({
        title: "Sample Documents Required",
        description: "Please upload some files relevant to the new topic.",
        variant: "destructive"
      });
      return;
    }
    if (topicFiles.length < 2) {
      toast({
        title: "Sample Documents Required",
        description: "Please upload at least 2 sample documents.",
        variant: "destructive"
      });
      return;
    }
    
    setIsAddingTopic(true);
    
    try {
      // Get presigned URLs for each file
      const uploadDetails = await Promise.all(topicFiles.map(file => fetchUploadUrl(file.type, file.name, true)));
      console.log("upload details: ", uploadDetails);
      
      const payload = uploadDetails.map((details, index) => ({
        file_id: details.file_id,
        file_name: topicFiles[index].name
      }));

      // Upload files to S3 using presigned URLs
      await Promise.all(uploadDetails.map((details, index) => {
        console.log("Current file: ", topicFiles[index]);
        return fetch(details.upload_url, {
          method: 'PUT',
          body: topicFiles?.[index],
          headers: {
            'Content-Type': topicFiles?.[index]?.type || 'application/octet-stream'
          }
        });
      }));
      
      const response = await addNewTopic(newTopicName, payload);
      toast({
        title: "Topic creation triggered",
        description: (
          <>
            Creating topic: {newTopicName}
            <br />
            This may take a few moments.
          </>
        ),
        variant: "success"
      });
    } catch (err) {
      console.log("Error creating topic: ", err);
      toast({
        title: "Error creating topic",
        description: `${err}`,
        variant: "destructive"
      });
    } finally {
      setIsLoading(true);
      setIsAddingTopic(false);
      setIsAddTopicDialogOpen(false);
      setNewTopicName('');
      setTopicFiles(null);
      setTimeout(() => {
        

        fetchTopics();
      }, 5000);
      setIsLoading(false);
    }
  };

  // Show loading state while initial data is being fetched
  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-[calc(100vh-4rem)]">
        <Icons.Loader className="h-8 w-8 animate-spin text-blue-600" />
      </div>
    );
  }

  // If model is retraining, show the retraining state UI
  if (modelState && modelState.isRetraining) {
    return <ModelRetrainingState modelState={modelState} />;
  }

  // Otherwise, show the normal UI
  return (
    <div className="h-[calc(100vh-4rem)] bg-gray-100">
      <div className="bg-white border-b">
        <div className="max-w-6xl mx-auto px-4 py-6">
          <h1 className="text-2xl font-bold">Model Management</h1>
        </div>
      </div>

      <div className="max-w-6xl mx-auto px-4 py-6">
        <Tabs defaultValue="retraining" className="w-full">
          <TabsList className="grid w-full grid-cols-2">
            <TabsTrigger value="retraining">Retraining</TabsTrigger>
            <TabsTrigger value="topics">Topic Configuration</TabsTrigger>
          </TabsList>

          <TabsContent value="retraining" className="mt-6">
            <div className="bg-white rounded-lg shadow p-6">
              <div className="flex justify-between items-center mb-6">
                <h2 className="text-xl font-semibold">Documents for Retraining</h2>
                <Button 
                  onClick={handleStartRetraining}
                  disabled={selectedDocuments.size === 0}
                >
                  Start Retraining
                </Button>
              </div>

              {documents.length === 0 ? (
                <NoFeedbackDocuments />
              ) : (
                <div className="overflow-x-auto">
                  <table className="min-w-full">
                    <thead>
                      <tr className="bg-gray-50">
                        <th className="px-2 py-3 text-left">
                          <Checkbox 
                            checked={selectedDocuments.size === documents.length}
                            onCheckedChange={handleSelectAll}
                          />
                        </th>
                        <th className="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase w-[15%]">
                          Document Name
                        </th>
                        <th className="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase w-[10%]">
                          Original Topic
                        </th>
                        <th className="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase w-[10%]">
                          Corrected Topic
                        </th>
                        <th className="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase w-[10%]">
                          Uploaded At
                        </th>
                        <th className="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase w-[8%]">
                          Confidence
                        </th>
                        <th className="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase w-[40%]">
                          Justification
                        </th>
                      </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                      {documents.map((doc) => (
                        <tr key={doc.id}>
                          <td className="px-2 py-4">
                            <Checkbox 
                              checked={selectedDocuments.has(doc.id)}
                              onCheckedChange={() => handleDocumentSelect(doc.id)}
                            />
                          </td>
                          <td className="px-3 py-4 text-sm">
                            <div className="truncate max-w-[200px]" title={doc.name}>
                              {doc.name}
                            </div>
                          </td>
                          <td className="px-3 py-4 text-sm">
                            {doc.classification}
                          </td>
                          <td className="px-3 py-4 text-sm">
                            {doc.user_corrected_category}
                          </td>
                          <td className="px-3 py-4 text-sm">
                            {doc.uploadedAt}
                          </td>
                          <td className="px-3 py-4 text-sm">
                            {doc.confidence ? (doc.confidence * 100).toFixed(1) : "-"}%
                          </td>
                          <td className="px-3 py-4 max-w-md">
                            {doc.feedback ? (
                              <TruncatedText text={doc.feedback} />
                            ) : (
                              <span className="text-gray-400 italic">No justification provided</span>
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          </TabsContent>

          <TabsContent value="topics" className="mt-6">
            <div className="bg-white rounded-lg shadow p-6">
              <div className="flex justify-between items-center mb-6">
                <h2 className="text-xl font-semibold">Topics</h2>
                <Button onClick={() => setIsAddTopicDialogOpen(true)}>
                  Add New Topic
                </Button>
              </div>

              <div className="overflow-x-auto">
                <table className="min-w-full">
                  <thead>
                    <tr className="bg-gray-50">
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        Topic Name
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        Created At
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        Actions
                      </th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {topics.map((topic) => (
                      <tr key={topic.topic_name}>
                        <td className="px-6 py-4 whitespace-nowrap text-sm">
                          {topic.topic_name}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm">
                          {topic.created_at}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm">
                          <Button
                            variant="ghost"
                            size="sm"
                            className="text-red-600 hover:text-red-800 hover:bg-red-50"
                            onClick={() => {
                              setTopicToDelete(topic);
                              setIsDeleteDialogOpen(true);
                            }}
                          >
                            Delete
                          </Button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </TabsContent>
        </Tabs>
      </div>

      {/* Delete Topic Dialog */}
      <Dialog open={isDeleteDialogOpen} onOpenChange={setIsDeleteDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete Topic</DialogTitle>
            <DialogDescription>
              Are you sure you want to delete this topic? This action cannot be undone.
            </DialogDescription>
          </DialogHeader>
          <p className="py-4">
            Topic: <span className="font-medium">{topicToDelete?.topic_name}</span>
          </p>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsDeleteDialogOpen(false)}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={handleDeleteTopic}>
              Delete
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Add Topic Dialog */}
      <Dialog open={isAddTopicDialogOpen} onOpenChange={(open) => {
        if (!isAddingTopic) setIsAddTopicDialogOpen(open);
      }}>
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>Add New Topic</DialogTitle>
            <DialogDescription>
              Create a new topic and upload sample documents for training.
            </DialogDescription>
          </DialogHeader>
          
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <label className="text-sm font-medium">Topic Name</label>
              <Input
                placeholder="Enter topic name"
                value={newTopicName}
                onChange={(e) => setNewTopicName(e.target.value)}
                disabled={isAddingTopic}
              />
            </div>
            
            <div className="space-y-2">
              <label className="text-sm font-medium">Sample Documents</label>
              <TopicFileUpload onFilesChange={setTopicFiles} />
            </div>
          </div>

          <DialogFooter>
            <Button 
              variant="outline" 
              onClick={() => setIsAddTopicDialogOpen(false)}
              disabled={isAddingTopic}
            >
              Cancel
            </Button>
            <Button 
              onClick={handleAddTopic}
              disabled={isAddingTopic}
            >
              {isAddingTopic ? (
                <>
                  <Icons.Loader className="mr-2 h-4 w-4 animate-spin" />
                  Creating...
                </>
              ) : (
                'Create Topic'
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

// TruncatedText component
function TruncatedText({ text, maxLength = 50 }: { text: string, maxLength?: number }) {
  const [isExpanded, setIsExpanded] = useState(false);
  
  if (!text) return <span className="text-gray-400 italic">No justification provided</span>;
  
  if (text.length <= maxLength) return <span>{text}</span>;
  
  return (
    <div className="relative">
      <p className={`${isExpanded ? '' : 'line-clamp-2'}`}>
        {text}
      </p>
      <button
        onClick={() => setIsExpanded(!isExpanded)}
        className="text-blue-600 hover:text-blue-800 text-xs flex items-center mt-1 focus:outline-none"
      >
        {isExpanded ? (
          <>
            <Icons.ChevronUp className="h-3 w-3 mr-1" />
            Show less
          </>
        ) : (
          <>
            <Icons.ChevronDown className="h-3 w-3 mr-1" />
            Show more
          </>
        )}
      </button>
    </div>
  );
} 