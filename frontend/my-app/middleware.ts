import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';
import { auth } from '@/service/auth';

export async function middleware(request: NextRequest) {
  // Get the current path
  const path = request.nextUrl.pathname;

  // Allow static files and API routes to pass through
  if (
    path.startsWith('/_next') || 
    path.startsWith('/static') || 
    path.startsWith('/api')
  ) {
    return NextResponse.next();
  }

  // For all other routes, return the index.html but preserve the URL
  const url = request.nextUrl.clone();
  url.pathname = '/index.html';
  
  const response = NextResponse.rewrite(url);
  
  return response;
}

export const config = {
  matcher: [
    // Match all routes except static files and api
    '/((?!_next/static|_next/image|favicon.ico).*)',
  ],
}; 