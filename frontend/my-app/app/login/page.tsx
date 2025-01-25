'use client';

import { useState } from 'react';
import axios from 'axios';
import { useAuth } from '../context/AuthContext';
import { useRouter } from 'next/navigation'; // Import the useRouter hook

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const { login } = useAuth();
  const router = useRouter(); // Initialize the router

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    try {
      const response = await axios.post('http://localhost:5001/login', { email, password });

      if (response.status === 200) {
        // Handle successful login (e.g., store JWT token or user data)
        console.log('Login successful:', response.data);
        
        // Redirect to the dashboard page after successful login
        router.push('/dashboard');  // Redirect to the dashboard page
      }
    } catch (error) {
      console.error('Login failed:', error);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-600">
      <div className="max-w-md w-full space-y-8 p-8 bg-white rounded-lg shadow">
        <div>
          <h2 className="text-center text-3xl font-bold">Document Classifier</h2>
          <p className="mt-2 text-center text-gray-900">Sign in to your account</p>
        </div>
        <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
          <div className="space-y-4">
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="Email address"
              className="w-full px-3 py-2 border border-gray-300 rounded-md"
              required
            />
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Password"
              className="w-full px-3 py-2 border border-gray-300 rounded-md"
              required
            />
          </div>
          <button
            type="submit"
            className="w-full py-2 px-4 bg-blue-600 text-white rounded-md hover:bg-blue-700"
          >
            Sign in
          </button>
        </form>
      </div>
    </div>
  );
}
