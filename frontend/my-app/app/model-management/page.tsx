'use client';

import { useState } from 'react';

interface Model {
  id: string;
  name: string;
  status: 'active' | 'training' | 'failed';
  accuracy: number;
  lastUpdated: string;
}

export default function ModelManagement() {
  const [models] = useState<Model[]>([
    {
      id: '1',
      name: 'Document Classifier v1',
      status: 'active',
      accuracy: 0.95,
      lastUpdated: '2024-03-20'
    },
    {
      id: '2',
      name: 'Document Classifier v2',
      status: 'training',
      accuracy: 0.89,
      lastUpdated: '2024-03-21'
    }
  ]);

  return (
    <div className="h-[calc(100vh-4rem)] bg-gray-100">
      <div className="bg-white border-b">
        <div className="max-w-6xl mx-auto px-4 py-6">
          <h1 className="text-2xl font-bold">Model Management</h1>
        </div>
      </div>
      
      <div className="max-w-6xl mx-auto px-4 py-6">
        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex justify-between items-center mb-6">
            <h2 className="text-xl font-semibold">Models</h2>
            <button className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700">
              Train New Model
            </button>
          </div>

          <div className="overflow-x-auto">
            <table className="min-w-full">
              <thead>
                <tr className="bg-gray-50">
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Model Name
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Accuracy
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Last Updated
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {models.map((model) => (
                  <tr key={model.id}>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm font-medium text-gray-900">
                        {model.name}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full 
                        ${model.status === 'active' ? 'bg-green-100 text-green-800' : 
                          model.status === 'training' ? 'bg-yellow-100 text-yellow-800' : 
                          'bg-red-100 text-red-800'}`}>
                        {model.status}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-900">
                        {(model.accuracy * 100).toFixed(1)}%
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {model.lastUpdated}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <button className="text-blue-600 hover:text-blue-900 mr-4">
                        View Details
                      </button>
                      {model.status === 'active' && (
                        <button className="text-red-600 hover:text-red-900">
                          Deactivate
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
} 