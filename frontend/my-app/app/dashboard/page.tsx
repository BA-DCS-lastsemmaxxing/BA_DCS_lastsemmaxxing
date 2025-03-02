'use client';

import { useState, useEffect } from 'react';
import { searchDocuments } from '@/service/classification';
import { Document } from '@/types/document';
import { UploadSection } from '@/components/dashboard/UploadSection';
import { SearchBar } from '@/components/dashboard/SearchBar';
import { DocumentList } from '@/components/dashboard/DocumentList';
import { DocumentModal } from '@/components/dashboard/DocumentModal';
import axios from 'axios';

export default function Dashboard() {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedDoc, setSelectedDoc] = useState<Document | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [documents, setDocuments] = useState<Document[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    handleSearch();
  }, []);

  const handleSearch = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    try {
      setIsSearching(true);
      setIsLoading(true);
  
      const data = await searchDocuments(searchQuery);
      console.log("Parsed Response Data:", data);
  
      let results = data.results;
  
      // If results is a string, try parsing it
      if (typeof results === "string") {
        try {
          results = JSON.parse(results);
          console.log("Parsed results:", results);
        } catch (error) {
          console.error("Error parsing 'results':", error);
          alert("Error parsing data. Please try again later.");
          return;
        }
      }
  
      // Ensure results is an array
      if (!Array.isArray(results)) {
        console.error("Unexpected format for results:", results);
        alert("Unexpected data format. Please try again later.");
        return;
      }
  
      // Map and set documents
      const mappedDocuments = results.map((doc: any) => ({
        id: doc.id,
        name: doc.name,
        uploadedAt: doc.uploadedAt,
        status: doc.status,
        summary: doc.summary,
        topics: doc.topics,
        classification: doc.classification,
        confidence: doc.confidence,
      }));
  
      setDocuments(mappedDocuments);
    } catch (error) {
      console.error("Search error:", error);
      alert("Search failed. Please try again later.");
    } finally {
      setIsSearching(false);
      setIsLoading(false);
    }
  };
  
  
  const handleDelete = async (docId: string) => { // Ensure the docId is a string (UUID)
    if (!docId) {
      console.error('Invalid document ID');
      alert('Invalid document ID');
      return;
    }

    try {
      console.log("Deleting document with ID:", docId); // Log the docId
      const response = await axios.delete(`http://localhost:5001/delete_document/${docId}`);
      if (response.status === 200) {
        alert(`Document ${docId} deleted successfully.`);
        // Remove the deleted document from the state
        setDocuments((prevDocs) => prevDocs.filter((doc) => doc.id !== docId)); // Compare string ID
      }
    } catch (error) {
      console.error('Error deleting document:', error);
      alert('Failed to delete the document.');
    }
  };

  return (
    <div className="h-[calc(100vh-4rem)] bg-gray-100">
      <div className="h-full max-w-6xl mx-auto px-4 py-6 flex flex-col">
        <UploadSection onUploadSuccess={handleSearch} />

        <div className="bg-white rounded-lg shadow p-6 flex flex-col flex-1 min-h-0">
          <SearchBar
            searchQuery={searchQuery}
            setSearchQuery={setSearchQuery}
            handleSearch={handleSearch}
            isSearching={isSearching}
          />

          <div className="overflow-y-auto flex-1">
            <DocumentList
              documents={documents}
              isLoading={isLoading}
              onDocumentClick={(doc) => {
                setSelectedDoc(doc);
                setIsModalOpen(true);
              }}
              onDelete={handleDelete} // Pass handleDelete directly as the onDelete handler
            />
          </div>
        </div>

        <DocumentModal
          isOpen={isModalOpen}
          onOpenChange={setIsModalOpen}
          document={selectedDoc}
        />
      </div>
    </div>
  );
}
