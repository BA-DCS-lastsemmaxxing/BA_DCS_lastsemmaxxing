'use client';

import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Search } from 'lucide-react';

interface SearchBarProps {
  searchQuery: string;
  setSearchQuery: (query: string) => void;
  handleSearch: (e?: React.FormEvent) => Promise<void>;
  isSearching: boolean;
}

export function SearchBar({ searchQuery, setSearchQuery, handleSearch, isSearching }: SearchBarProps) {
  return (
    <form onSubmit={handleSearch} className="mb-6">
      <div className="flex gap-2">
        <Input
          type="search"
          placeholder="Search documents..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="max-w-md"
        />
        <Button 
          type="submit" 
          disabled={isSearching}
          className="flex items-center gap-2"
        >
          <Search className="h-4 w-4" />
          {isSearching ? 'Searching...' : 'Search'}
        </Button>
      </div>
    </form>
  );
} 