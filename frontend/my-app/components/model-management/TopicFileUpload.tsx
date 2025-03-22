'use client';

import { useState, useRef } from "react";
import { useToast } from "@/hooks/use-toast";

interface TopicFileUploadProps {
  onFilesChange: (files: File[] | null) => void;
}

export function TopicFileUpload({ onFilesChange }: TopicFileUploadProps) {
  const [files, setFiles] = useState<File[] | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const { toast } = useToast();

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