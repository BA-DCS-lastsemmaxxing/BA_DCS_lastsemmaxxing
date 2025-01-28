'use client';

import { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { useRouter } from 'next/navigation';
import { useToast } from "@/hooks/use-toast"


export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const { login } = useAuth();
  const router = useRouter(); // Initialize the router
  const { toast } = useToast();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    try {
      await login(email, password);
      // No need to manually redirect here as AuthContext handles it
      toast({
        title: "Login successful",
        description: "Welcome!"
      })
    } catch (error: any) {
      
      if (error.status === 401) {
        // Handle unauthorized error
        const data = await error.json();
        toast({
          variant: "destructive",
          title: "Authentication failed",
          description: data.message
        });
      } else {
        // Handle other errors
        toast({
          variant: "destructive",
          title: "Uh oh! Something went wrong.",
          description: error.message
        });
      }
    }
  };

  return (
    <div className="flex items-start justify-center h-[calc(100vh-4rem)] bg-gray-600">
      <div className="w-2/3 max-w-3xl space-y-8 p-8 bg-white rounded-lg shadow mt-16">
        <div>
          <h2 className="text-center text-3xl font-bold">Welcome!</h2>
          <p className="mt-2 text-center text-gray-900">Please login to access your documents</p>
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
