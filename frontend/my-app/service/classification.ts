import { configService } from './config';

const { api } = configService.get();

function getCookie(name: string): string | undefined {
    const cookies = document.cookie.split("; ");
    for (const cookie of cookies) {
        const [cookieName, cookieValue] = cookie.split("=");
        if (cookieName === name) {
            return decodeURIComponent(cookieValue);
        }
    }
    return undefined;
}

export async function upload(input: File[]) {
    console.log("Upload service reached");

    // Create a FormData object
    const formData = new FormData();

    // Append each file individually
    input.forEach((file) => {
        formData.append('files', file);
    });

    // Perform the fetch request
    const response = await fetch(`${api.backendUrl}/upload`, {
        method: "POST",
        body: formData, // Attach FormData as the body,
        headers: {
            "Authorization": `Bearer ${getCookie("CognitoToken")}`
        }
    });

    // Handle the response
    if (!response.ok) {
        throw new Error(`Failed to upload. Status: ${response.status}`);
    }

    return await response.json(); // Assuming the backend responds with JSON
}

export async function searchDocuments(query: string) {
    console.log("Search document service reached");
    const encodedQuery = encodeURIComponent(query); // Encode query for spaces/special characters
    const url = `${api.backendUrl}/documents?query=${encodedQuery}`;

    try {
        const response = await fetch(url, {
            method: "GET",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${getCookie("CognitoToken")}`,
            },
        });

        // Log full response headers and status code
        console.log('Response Status:', response.status);
        console.log('Response Headers:', [...response.headers]);

        // Check if the response is OK (status 200)
        if (!response.ok) {
            throw new Error(`Failed to fetch documents: ${response.statusText}`);
        }

        // Check the response content type
        const contentType = response.headers.get("Content-Type");
        console.log("Response Content-Type:", contentType);

        let responseData;
        if (contentType && contentType.includes("application/json")) {
            // If the response is JSON, just parse it once
            responseData = await response.json();
        } else {
            // If it's not JSON, log the raw response body
            const textResponse = await response.text();
            console.log("Non-JSON response body:", textResponse);
            responseData = textResponse; // Handle as required
        }

        console.log("Parsed Response Data:", responseData);
        return responseData;

    } catch (error) {
        console.error("Error during search:", error);
        throw new Error("An error occurred while searching documents");
    }
}

export async function getDownloadLink(documentId: string) {
    const response = await fetch(`${api.backendUrl}/download/${documentId}`);
    
    if (!response.ok) {
      throw new Error(`Failed to get download link. Status: ${response.status}`);
    }
  
    return await response.json();
  }
