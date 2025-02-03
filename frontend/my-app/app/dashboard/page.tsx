'use client';

import { useState, useEffect } from 'react';
import { searchDocuments } from '@/service/classification';
import type { Document } from '@/types/document';
import { UploadSection } from '@/components/dashboard/UploadSection';
import { SearchBar } from '@/components/dashboard/SearchBar';
import { DocumentList } from '@/components/dashboard/DocumentList';
import { DocumentModal } from '@/components/dashboard/DocumentModal';

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
      const data = await searchDocuments(searchQuery);
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