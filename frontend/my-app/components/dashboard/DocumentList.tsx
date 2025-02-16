"use client";

import { Document } from "@/types/document";

interface DocumentListProps {
  documents: Document[];
  isLoading: boolean;
  onDocumentClick: (doc: Document) => void;
}

export function DocumentList({
  documents,
  isLoading,
  onDocumentClick,
}: DocumentListProps) {
  if (isLoading) {
    return (
      <div className="text-center py-8">
        <p>Loading documents...</p>
      </div>
    );
  }

  if (documents.length === 0) {
    return (
      <div className="text-center py-8 text-gray-500">
        <p>No documents found</p>
      </div>
    );
  }

  return (
    <div className="grid gap-4">
<<<<<<< HEAD
      {documents.map((doc) => (
        <div
          key={doc.id.toString()}
          onClick={() => onDocumentClick(doc)}
          className="flex items-center justify-between p-4 border rounded-lg hover:bg-gray-50 cursor-pointer"
        >
          <div className="flex items-center space-x-4">
            <div className="flex-shrink-0">
              <div
                className={`h-3 w-3 rounded-full ${
                  doc.status === "completed"
                    ? "bg-green-500"
                    : doc.status === "processing"
                    ? "bg-yellow-500"
                    : "bg-red-500"
                }`}
              />
            </div>
            <div>
              <h3 className="font-medium">{doc.name}</h3>
              <p className="text-sm text-gray-500">{doc.uploadedAt}</p>
            </div>
=======
    {documents.map((doc) => (
      <div
        key={String(doc.id)} // Ensure doc.id is a string
        onClick={() => onDocumentClick(doc)}
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
>>>>>>> dockerise
          </div>
        </div>
      </div>
    ))}

    </div>
  );
}
