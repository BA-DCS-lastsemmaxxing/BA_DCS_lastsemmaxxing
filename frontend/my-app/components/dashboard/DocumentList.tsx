'use client';

import { useState } from 'react';
import { Document } from '@/types/document';

interface DocumentListProps {
  documents: Document[];
  isLoading: boolean;
  onDocumentClick: (doc: Document) => void;
  onDelete: (docId: string) => void; // Ensure we handle docId as string (UUID)
}

export function DocumentList({
  documents,
  isLoading,
  onDocumentClick,
  onDelete,
}: DocumentListProps) {

  const handleDeleteClick = (docId: string, e: React.MouseEvent) => {
    e.stopPropagation(); // Prevent triggering onClick for the document
    onDelete(docId); // Call the delete handler passed from the parent
  };

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
      {documents.map((doc) => (
        <div
          key={String(doc.id)} // Ensure doc.id is a string (UUID)
          onClick={() => onDocumentClick(doc)}
          className="flex items-center justify-between p-4 border rounded-lg hover:bg-gray-50 cursor-pointer"
        >
          <div className="flex items-center space-x-4">
            <div className="flex-shrink-0">
              <div
                className={`h-3 w-3 rounded-full ${
                  doc.status === 'completed'
                    ? 'bg-green-500'
                    : doc.status === 'processing'
                    ? 'bg-yellow-500'
                    : 'bg-red-500'
                }`}
              />
            </div>
            <div>
              <h3 className="font-medium">{doc.name}</h3>
              <p className="text-sm text-gray-500">{doc.uploadedAt}</p>
            </div>
          </div>
          <button
            onClick={(e) => handleDeleteClick(doc.id.toString(), e)} // Ensure doc.id is passed as string (UUID)
            className="text-red-500 ml-4"
          >
            Delete
          </button>
        </div>
      ))}
    </div>
  );
}
