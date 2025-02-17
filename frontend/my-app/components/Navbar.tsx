'use client';

import { useRouter, usePathname } from 'next/navigation';
import { useState, useEffect } from 'react';
import { auth } from '@/service/auth';
import Image from 'next/image';
import { Icons } from '@/components/Icons';

export default function Navbar() {
  const router = useRouter();
  const pathname = usePathname();
  const [user, setUser] = useState<any>(null);
  const [isUserMenuOpen, setUserMenuOpen] = useState(false);
  const isLoginPage = pathname === '/login';

  useEffect(() => {
    checkUser();
  }, []);

  const checkUser = async () => {
    try {
      const currentUser = await auth.getCurrentUser();
      setUser(currentUser);
    } catch (error) {
      console.error('No user session');
    }
  };

  const handleLogout = () => {
    auth.signOut();
    router.push('/login');
  };

  return (
    <div className="relative">
      <nav className="bg-white border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16 items-center">
            {/* Center section - Logo */}
            <div className="flex-shrink-0 flex items-center mx-auto">
              <h1 className="text-2xl font-bold">Document Classifier</h1>
            </div>

            {/* Right section - User menu */}
            {!isLoginPage && (
              <div className="flex items-center absolute right-8">
                <div className="relative">
                  <button
                    onClick={() => setUserMenuOpen(!isUserMenuOpen)}
                    className="flex items-center space-x-2 p-2 rounded-full hover:bg-gray-100"
                  >
                    <div className="h-8 w-8 rounded-full bg-gray-300 flex items-center justify-center">
                      <Icons.User className="h-5 w-5 text-gray-600" />
                    </div>
                    <Icons.ChevronDown className="h-4 w-4 text-gray-600" />
                  </button>

                  {/* User dropdown menu */}
                  {isUserMenuOpen && (
                    <div className="absolute right-0 mt-2 w-48 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5">
                      <div className="py-1">
                        <div className="px-4 py-2 text-sm text-gray-700 border-b">
                          <p className="font-medium">Welcome, {user?.user_email}</p>
                        </div>
                        <button
                          onClick={handleLogout}
                          className="w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                        >
                          Sign out
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>
        </div>
      </nav>
    </div>
  );
} 