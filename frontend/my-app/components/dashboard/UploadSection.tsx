'use client';

import { useState, useRef } from 'react';
import { upload } from '@/service/classification';
import { useToast } from "@/hooks/use-toast"

interface UploadSectionProps {
  onUploadSuccess: () => void;
}

export function UploadSection({ onUploadSuccess }: UploadSectionProps) {
  const [files, setFiles] = useState<File[] | null>(null);
  const [uploadStatus, setUploadStatus] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const { toast } = useToast();

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const selectedFiles = e.target.files;
    if (selectedFiles) {
      const newFiles = Array.from(selectedFiles);
      if (files) {
        const existingFileNames = files.map(f => f.name);
        const duplicateFiles = newFiles.filter(file => existingFileNames.includes(file.name));
        const uniqueNewFiles = newFiles.filter(file => !existingFileNames.includes(file.name));
        
        // Show toast if there are duplicate files
        if (duplicateFiles.length > 0) {
          toast({
            variant: "warning",
            title: "Duplicate files detected",
            description: `${duplicateFiles.map(f => f.name).join(', ')} ${duplicateFiles.length === 1 ? 'is' : 'are'} already selected.`
          });
        }

        setFiles(prevFiles => prevFiles ? [...prevFiles, ...uniqueNewFiles] : uniqueNewFiles);
      } else {
        setFiles(newFiles);
      }
    }
    // Reset the file input
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  const handleDeleteFile = (indexToDelete: number) => {
    setFiles(prevFiles => {
      if (!prevFiles) return null;
      const updatedFiles = prevFiles.filter((_, index) => index !== indexToDelete);
      return updatedFiles.length > 0 ? updatedFiles : null;
    });
    // Reset the file input after deletion
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  const handleUploadToBackend = async () => {
    if (!files) return;
    setIsLoading(true);
    try {
      const response = await upload(files);
      setUploadStatus("Upload successful");
      setFiles(null);
      onUploadSuccess();
      // Reset the file input after successful upload
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    } catch (error) {
      console.error('Upload failed:', error);
      setUploadStatus("Upload failed: " + error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="bg-white rounded-lg shadow p-6 mb-6">
      <div className="space-y-6">
        <div className="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center">
          <input
            ref={fileInputRef}
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
            {files && files.length > 0 ? (
              <div className="w-full">
                <ul className="space-y-2">
                  {files.map((file, index) => (
                    <li 
                      key={index}
                      className="flex items-center justify-between p-3 bg-gray-50 rounded-lg group hover:bg-gray-100 transition-colors"
                    >
                      <div className="flex items-center">
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
              <div>
                <p className="text-lg">Upload documents</p>
                <p className="text-sm text-gray-500 mt-1">
                  PDF, DOC, DOCX, TXT supported
                </p>
              </div>
            )}
          </label>
        </div>

        {files && files.length > 0 && (
          <button
            onClick={handleUploadToBackend}
            disabled={isLoading}
            className="w-full py-2 px-4 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
          >
            {isLoading ? 'Uploading...' : 'Upload Documents'}
          </button>
        )}

        {!isLoading && uploadStatus && (
          <div className={`mt-4 p-4 rounded-md ${
            uploadStatus.includes('failed') 
              ? 'bg-red-50 text-red-800' 
              : 'bg-green-50 text-green-800'
          }`}>
            <div className="flex items-center">
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
  );
}
  