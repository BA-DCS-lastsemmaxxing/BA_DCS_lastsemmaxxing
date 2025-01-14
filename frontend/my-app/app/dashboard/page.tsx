'use client';

import { useState } from 'react';
import { useAuth } from '../context/AuthContext';

export default function Dashboard() {
  const { user, logout } = useAuth();
  const [file, setFile] = useState<File | null>(null);
  const [response, setResponse] = useState<string | null>(null);
  const [classifications, setClassifications] = useState<string[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setFile(file);
      setClassifications([]);
    }
  };

  const handleClassify = async () => {
    if (!file) return;

    setIsLoading(true);
    try {
      // Add classification API call here
      // const result = await api.classifyDocument(file);

      // Set dummy data
      setClassifications(["Financial", "Report", "Annual", "Confidential"]);
      setResponse("This document appears to be regarding MAS's annual financial report for 2024.")

    } catch (error) {
      console.error('Classification failed:', error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-100">
      <nav className="bg-red-600 shadow-sm">
        <div className="max-w-7xl mx-auto px-4 py-3 flex justify-between items-center">
          <h1 className="text-xl text-white font-bold">Document Classifier</h1>
          <button
            onClick={logout}
            className="text-white hover:text-gray-300"
          >
            Sign out
          </button>
        </div>
      </nav>

      <main className="max-w-4xl mx-auto mt-8 p-6 bg-white rounded-lg shadow">
        <div className="space-y-6">
          <div className="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center">
            <input
              type="file"
              onChange={handleFileUpload}
              className="hidden"
              id="file-upload"
              accept=".pdf,.doc,.docx,.txt"
            />
            <label
              htmlFor="file-upload"
              className="cursor-pointer text-blue-600 hover:text-blue-800"
            >
              {file ? file.name : 'Upload a document'}
            </label>
          </div>

          {file && (
            <button
              onClick={handleClassify}
              disabled={isLoading}
              className="w-full py-2 px-4 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
            >
              {isLoading ? 'Classifying...' : 'Classify Document'}
            </button>
          )}

          {classifications.length > 0 && (
            <div className="mt-4 p-4 bg-gray-50 rounded-md">
              <p className="mt-2">{response}</p>
              <div className="mt-4 flex flex-wrap gap-2">
                {classifications.map((classification, index) => (
                  <span
                    key={index}
                    className="px-3 py-1 bg-blue-100 text-blue-800 rounded-full text-sm"
                  >
                    {classification}
                  </span>
                ))}
              </div>
            </div>
          )}
        </div>
      </main>
    </div>
  );
} 