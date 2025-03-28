'use client';

import { useEffect, useState } from 'react';
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Topic } from '@/types/model';
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

export default function ModelManagement() {
  const [selectedDocuments, setSelectedDocuments] = useState<Set<string>>(new Set());
  const [isDeleteDialogOpen, setIsDeleteDialogOpen] = useState(false);
  const [topicToDelete, setTopicToDelete] = useState<Topic | null>(null);
  const [isAddTopicDialogOpen, setIsAddTopicDialogOpen] = useState(false);
  const [newTopicName, setNewTopicName] = useState('');
  const { toast } = useToast();

  const [documents, setDocuments] = useState<Document[]>([]);

  const [topics, setTopics] = useState<Topic[]>([]);

  const [topicFiles, setTopicFiles] = useState<File[] | null>(null);

  const fetchTopics = async () => {
    try {
      const topics = await getAllTopics();
      console.log(" Topics: ", topics);
      setTopics(topics);
    } catch (error) {
      console.error("Error fetching topics:", error);
    }
  };
  const fetchCorrectedDocuments = async () => {
    try {
      const docs = await getCorrectedDocuments();
      console.log(" Corrected Documents: ", docs);
      setDocuments(docs);
    } catch (error) {
      console.error("Error fetching corrected documents:", error);
    }
  };
  useEffect(() => {
      fetchTopics();
      fetchCorrectedDocuments();
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
    
    // Filter documents to only include those that are selected
    const selectedDocs = documents.filter(doc => selectedDocuments.has(doc.id));
    
    console.log("Retraining documents: ", selectedDocs);
    
    try {
      // Call your API with the selected documents
      const response = await feedbackRetraining(selectedDocs);
      
      toast({
        title: "Retraining started",
        description: `Started retraining with ${selectedDocuments.size} documents.`,
        variant: "success"
      });
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
    console.log(
        "topic files:", topicFiles
    )
    try{
        // Get presigned URLs for each file
        const uploadDetails = await Promise.all(topicFiles.map(file => fetchUploadUrl(file.type ,file.name, true)));
        console.log("upload details: ", uploadDetails);
        
        const payload = uploadDetails.map((details, index) => ({
            file_id: details.file_id,
            file_name: topicFiles[index].name
        }));

        // Upload files to S3 using presigned URLs
        await Promise.all(uploadDetails.map((details, index) => {
        console.log("Current file: ", topicFiles[index])
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
    } catch (err){
        console.log("Error creating topic: ", err);
        toast({
            title: "Error creating topic",
            description: `${err}`,
            variant: "destructive"
            });
    } finally{
        setIsAddTopicDialogOpen(false);
        setNewTopicName('');
        setTopicFiles(null);
        fetchTopics();
    }
    };

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
                          {doc.feedback ? (<TruncatedText text={doc.feedback}/>) : "-"} 
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
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
                        Status
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        Topic Name
                      </th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                        Document Count
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
                        <td className="px-6 py-4 whitespace-nowrap">
                          <TooltipProvider>
                            <Tooltip>
                              <TooltipTrigger>
                                <div
                                  className={`h-3 w-3 rounded-full ${
                                    topic.status === 'Completed'
                                      ? 'bg-green-500'
                                      : topic.status === 'Pending'
                                      ? 'bg-yellow-500'
                                      : 'bg-red-500'
                                  }`}
                                />
                              </TooltipTrigger>
                              <TooltipContent>
                                <p>{topic.status}</p>
                              </TooltipContent>
                            </Tooltip>
                          </TooltipProvider>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm">
                          {topic.topic_name}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm">
                          {topic.document_count}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm">
                          {topic.created_at}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm">
                          <Button
                            variant="destructive"
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
              Are you sure you want to delete the topic &quot;{topicToDelete?.topic_name}&quot;? 
              This action cannot be undone.
            </DialogDescription>
          </DialogHeader>
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
      <Dialog open={isAddTopicDialogOpen} onOpenChange={setIsAddTopicDialogOpen}>
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
              />
            </div>
            
            <div className="space-y-2">
              <label className="text-sm font-medium">Sample Documents</label>
              <TopicFileUpload onFilesChange={setTopicFiles} />
            </div>
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={() => setIsAddTopicDialogOpen(false)}>
              Cancel
            </Button>
            <Button onClick={handleAddTopic}>
              Create Topic
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

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