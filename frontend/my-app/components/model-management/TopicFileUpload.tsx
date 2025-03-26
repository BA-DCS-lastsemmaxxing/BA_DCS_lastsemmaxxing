'use client';

import { useState, useRef, useEffect } from "react";
import { useToast } from "@/hooks/use-toast";

interface TopicFileUploadProps {
  onFilesChange: (files: File[] | null) => void;
}

export function TopicFileUpload({ onFilesChange }: TopicFileUploadProps) {
  const [files, setFiles] = useState<File[] | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const { toast } = useToast();

  useEffect(() => {
    onFilesChange(files)
  }, [files]);

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const selectedFiles = e.target.files;
    if (selectedFiles) {
      const newFiles = Array.from(selectedFiles);
      if (files) {
        const existingFileNames = files.map((f) => f.name);
        const duplicateFiles = newFiles.filter((file) =>
          existingFileNames.includes(file.name)
        );
        const uniqueNewFiles = newFiles.filter(
          (file) => !existingFileNames.includes(file.name)
        );

        // Show toast if there are duplicate files
        if (duplicateFiles.length > 0) {
          toast({
            variant: "warning",
            title: "Duplicate files detected",
            description: `${duplicateFiles.map((f) => f.name).join(", ")} ${
              duplicateFiles.length === 1 ? "is" : "are"
            } already selected.`,
          });
        }

        setFiles((prevFiles) =>
          prevFiles ? [...prevFiles, ...uniqueNewFiles] : uniqueNewFiles
        );
      } else {
        setFiles(newFiles);
      }
    }
    // Reset the file input
    if (fileInputRef.current) {
      fileInputRef.current.value = "";
    }
  };

  const handleDeleteFile = (indexToDelete: number) => {
    setFiles((prevFiles) => {
      if (!prevFiles) return null;
      const updatedFiles = prevFiles.filter((_, index) => index !== indexToDelete);
      onFilesChange(updatedFiles.length > 0 ? updatedFiles : null);
      return updatedFiles.length > 0 ? updatedFiles : null;
    });
    if (fileInputRef.current) {
      fileInputRef.current.value = "";
    }
  };

  return (
    <div className="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center max-w-full">
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
                  <div className="flex items-center min-w-0 flex-1 mr-2">
                    <div className="flex-shrink-0">
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
                    </div>
                    <div className="min-w-0 flex-1 max-w-full">
                        <p
                        className="text-sm text-gray-600 truncate w-full"
                        title={file.name}
                        >
                        {file.name}
                        </p>

                      <p className="text-xs text-gray-400">
                        {(file.size / 1024).toFixed(1)} KB
                      </p>
                    </div>
                  </div>
                  <button
                    onClick={(e) => {
                      e.preventDefault();
                      handleDeleteFile(index);
                    }}
                    className="flex-shrink-0 text-red-500 hover:text-red-700 opacity-0 group-hover:opacity-100 transition-opacity"
                  >
                    Delete
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
              PDF Files Supported
            </p>
          </div>
        )}
      </label>
    </div>
  );
} 