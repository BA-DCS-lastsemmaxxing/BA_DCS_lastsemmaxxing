'use client';

import { useState, useEffect } from 'react';
import { searchDocuments } from '@/service/classification';
import { Document } from '@/types/document';
import { UploadSection } from '@/components/dashboard/UploadSection';
import { SearchBar } from '@/components/dashboard/SearchBar';
import { DocumentList } from '@/components/dashboard/DocumentList';
import { DocumentModal } from '@/components/dashboard/DocumentModal';
import axios from 'axios';
import ClassificationFilter from '@/components/dashboard/ClassificationFilter'; // Import ClassificationFilter

export default function Dashboard() {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedDoc, setSelectedDoc] = useState<Document | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [documents, setDocuments] = useState<Document[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  // Filter & Sort states
  const [classificationFilter, setClassificationFilter] = useState<string>('');
  const [sortOption, setSortOption] = useState<string>('');

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

      if (typeof results === "string") {
        try {
          results = JSON.parse(results);
        } catch (error) {
          console.error("Error parsing 'results':", error);
          alert("Error parsing data. Please try again later.");
          return;
        }
      }

      if (!Array.isArray(results)) {
        console.error("Unexpected format for results:", results);
        alert("Unexpected data format. Please try again later.");
        return;
      }

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

  const handleDelete = async (docId: string) => {
    if (!docId) {
      console.error('Invalid document ID');
      alert('Invalid document ID');
      return;
    }

    try {
      console.log("Deleting document with ID:", docId);
      
      // Replace with your actual API Gateway or CloudFront URL
      const response = await axios.delete(`https://d1ztk01ovm0zc3.cloudfront.net/delete_document/${docId}`);
      
      if (response.status === 200) {
        alert(`Document ${docId} deleted successfully.`);
        // Remove the deleted document from the state
        setDocuments((prevDocs) => prevDocs.filter((doc) => String(doc.id) !== docId));
      } else {
        console.error('Failed to delete document:', response);
        alert('Failed to delete the document.');
      }
    } catch (error) {
      console.error('Error deleting document:', error);
      alert('Failed to delete the document.');
    }
  };

  const handleSortChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    setSortOption(e.target.value);
  };

  const processedDocuments = [...documents]
    .filter((doc) => (classificationFilter ? doc.classification === classificationFilter : true))
    .sort((a, b) => {
      if (sortOption === 'date-asc') return new Date(a.uploadedAt).getTime() - new Date(b.uploadedAt).getTime();
      if (sortOption === 'date-desc') return new Date(b.uploadedAt).getTime() - new Date(a.uploadedAt).getTime();
      if (sortOption === 'title-asc') return a.name.localeCompare(b.name);
      if (sortOption === 'title-desc') return b.name.localeCompare(a.name);
      return 0;
    });

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

          {/* Filters & Sorting */}
          <div className="flex gap-4 mb-4">
            {/* Classification Filter */}
            <ClassificationFilter
              classificationFilter={classificationFilter}
              setClassificationFilter={setClassificationFilter}
            />

            {/* Sorting Options */}
            <div className="flex-1">
              <label className="block text-gray-700 text-sm font-bold mb-1">
                Sort By:
              </label>
              <select
                className="border rounded w-full p-2"
                value={sortOption}
                onChange={handleSortChange}
              >
                <option value="">None</option>
                <option value="date-asc">Date (Oldest First)</option>
                <option value="date-desc">Date (Newest First)</option>
                <option value="title-asc">Title (A-Z)</option>
                <option value="title-desc">Title (Z-A)</option>
              </select>
            </div>
          </div>

          <div className="overflow-y-auto flex-1">
            <DocumentList
              documents={processedDocuments}
              isLoading={isLoading}
              onDocumentClick={(doc) => {
                setSelectedDoc(doc);
                setIsModalOpen(true);
              }}
              onDelete={handleDelete}
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
