'use client';

import { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { upload, searchDocuments } from '@/service/classification';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Search } from 'lucide-react';

interface Document {
  id: BigInteger;
  name: string;
  uploadedAt: string;
  status: 'processing' | 'completed' | 'failed';
  summary?: string;
  tags?: string[];
}

export default function Dashboard() {
  // Authentication and user management
  const { user, logout } = useAuth();

  // State management for file handling and upload status
  const [files, setFiles] = useState<File[] | null>(null);
  const [uploadStatus, setUploadStatus] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedDoc, setSelectedDoc] = useState<Document | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [documents, setDocuments] = useState<Document[]>([]);
  const [isSearching, setIsSearching] = useState(false);

  // Fetch recent documents on initial load
  useEffect(() => {
    handleSearch();
  }, []);


  const handleSearch = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    try {
      setIsSearching(true);
      const data = await searchDocuments(searchQuery);
      // Map the API response to Document interface
      const mappedDocuments = data.results.map((doc: any) => ({
        id: doc.id,
        name: doc.name,
        uploadedAt: doc.uploadedAt,
        status: doc.status,
        summary: doc.summary,
        tags: doc.tags
      }));
      setDocuments(mappedDocuments);
    } catch (error) {
      console.error('Search error:', error);
    } finally {
      setIsSearching(false);
    }
  };

  // Handles file selection from input
  // Adds new files to existing ones while preventing duplicates
  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const selectedFiles = e.target.files;
    if (selectedFiles) {
      const newFiles = Array.from(selectedFiles);
      const existingFileNames = files ? files.map(f => f.name) : [];
      const uniqueNewFiles = newFiles.filter(file => !existingFileNames.includes(file.name));
      
      setFiles(prevFiles => prevFiles ? [...prevFiles, ...uniqueNewFiles] : uniqueNewFiles);
    }
  };

  // Removes a specific file from the list by its index
  const handleDeleteFile = (indexToDelete: number) => {
    setFiles(prevFiles => prevFiles ? prevFiles.filter((_, index) => index !== indexToDelete) : null);
  };

  // Handles the upload process to the backend
  // Updates loading state and upload status accordingly
  const handleUploadToBackend = async () => {
    if (!files) return;
    setIsLoading(true);
    try {
      const response = await upload(files);
      setUploadStatus("Upload successful");
    } catch (error) {
      console.error('Upload failed:', error);
      setUploadStatus("Upload failed: " + error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-100">
      <div className="max-w-6xl mx-auto px-4 py-6">
        {/* Upload Section */}
        <div className="bg-white rounded-lg shadow p-6 mb-6">
          <div className="space-y-6">
            {/* File upload area with drag-and-drop styling */}
            <div className="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center">
              <input
                type="file"
                onChange={handleFileUpload}
                className="hidden"
                id="file-upload"
                accept=".pdf,.doc,.docx,.txt"
                multiple
              />
              <label
                htmlFor="file-upload"
                className="cursor-pointer text-blue-600 hover:text-blue-800"
              >
                {files ? (
                  // Display list of selected files with delete options
                  <div className="w-full">
                    <ul className="space-y-2">
                      {files.map((file, index) => (
                        <li 
                          key={index}
                          className="flex items-center justify-between p-3 bg-gray-50 rounded-lg group hover:bg-gray-100 transition-colors"
                        >
                          {/* File information display */}
                          <div className="flex items-center">
                            {/* Document icon */}
                            <svg 
                              className="w-5 h-5 text-gray-500 mr-2" 
                              fill="none" 
                              stroke="currentColor" 
                              viewBox="0 0 24 24"
                            >
                              <path 
                                strokeLinecap="round" 
                                strokeLinejoin="round" 
                                strokeWidth={2} 
                                d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" 
                              />
                            </svg>
                            <span className="text-gray-600">{file.name}</span>
                            <span className="ml-2 text-sm text-gray-400">
                              ({(file.size / 1024).toFixed(1)} KB)
                            </span>
                          </div>
                          {/* Delete button - appears on hover */}
                          <button
                            onClick={(e) => {
                              e.preventDefault();
                              handleDeleteFile(index);
                            }}
                            className="text-red-500 hover:text-red-700 opacity-0 group-hover:opacity-100 transition-opacity"
                          >
                            <svg 
                              className="w-5 h-5" 
                              fill="none" 
                              stroke="currentColor" 
                              viewBox="0 0 24 24"
                            >
                              <path 
                                strokeLinecap="round" 
                                strokeLinejoin="round" 
                                strokeWidth={2} 
                                d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" 
                              />
                            </svg>
                          </button>
                        </li>
                      ))}
                    </ul>
                    <p className="mt-4 text-sm text-blue-600">
                      Click to add more files
                    </p>
                  </div>
                ) : (
                  // Initial upload prompt when no files are selected
                  <div>
                    <p className="text-lg">Upload documents</p>
                    <p className="text-sm text-gray-500 mt-1">
                      PDF, DOC, DOCX, TXT supported
                    </p>
                  </div>
                )}
              </label>
            </div>

            {/* Upload button - only shown when files are selected */}
            {files && (
              <button
                onClick={handleUploadToBackend}
                disabled={isLoading}
                className="w-full py-2 px-4 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
              >
                {isLoading ? 'Uploading...' : 'Upload Documents'}
              </button>
            )}

            {/* Status message display - shows success or error state */}
            {!isLoading && uploadStatus && (
              <div className={`mt-4 p-4 rounded-md ${
                uploadStatus.includes('failed') 
                  ? 'bg-red-50 text-red-800' 
                  : 'bg-green-50 text-green-800'
              }`}>
                <div className="flex items-center">
                  {/* Status icon - changes based on success/failure */}
                  {uploadStatus.includes('failed') ? (
                    <svg className="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
                    </svg>
                  ) : (
                    <svg className="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                    </svg>
                  )}
                  <p className="font-medium">{uploadStatus}</p>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Search and Document List Section */}
        <div className="bg-white rounded-lg shadow p-6">
          <form onSubmit={handleSearch} className="mb-6">
            <div className="flex gap-2">
              <Input
                type="search"
                placeholder="Search documents..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="max-w-md"
              />
              <Button 
                type="submit" 
                disabled={isSearching}
                className="flex items-center gap-2"
              >
                <Search className="h-4 w-4" />
                {isSearching ? 'Searching...' : 'Search'}
              </Button>
            </div>
          </form>

          {isLoading ? (
            <div className="text-center py-8">
              <p>Loading documents...</p>
            </div>
          ) : documents.length === 0 ? (
            <div className="text-center py-8 text-gray-500">
              <p>No documents found</p>
            </div>
          ) : (
            <div className="grid gap-4">
              {documents.map((doc) => (
                <div
                  key={doc.id}
                  onClick={() => {
                    setSelectedDoc(doc);
                    setIsModalOpen(true);
                  }}
                  className="flex items-center justify-between p-4 border rounded-lg hover:bg-gray-50 cursor-pointer"
                >
                  <div className="flex items-center space-x-4">
                    <div className="flex-shrink-0">
                      <div className={`h-3 w-3 rounded-full ${
                        doc.status === 'completed' ? 'bg-green-500' :
                        doc.status === 'processing' ? 'bg-yellow-500' :
                        'bg-red-500'
                      }`} />
                    </div>
                    <div>
                      <h3 className="font-medium">{doc.name}</h3>
                      <p className="text-sm text-gray-500">
                        {doc.uploadedAt}
                      </p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Document Details Modal */}
      <Dialog open={isModalOpen} onOpenChange={setIsModalOpen}>
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>{selectedDoc?.name}</DialogTitle>
            <DialogDescription>
              Uploaded on {selectedDoc && selectedDoc.uploadedAt}
            </DialogDescription>
          </DialogHeader>

          <div className="mt-4 space-y-4">
            {selectedDoc?.status === 'processing' ? (
              <p className="text-yellow-600 text-center italic">
                Looks like this document is still being processed... please try again later!
              </p>
            ) : (
              <>
                <p className="text-gray-600">{selectedDoc?.summary}</p>
                
                <div className="flex flex-wrap gap-2">
                  {selectedDoc?.tags?.map(tag => (
                    <Badge key={tag} variant="secondary">
                      {tag}
                    </Badge>
                  ))}
                </div>
              </>
            )}
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
} 