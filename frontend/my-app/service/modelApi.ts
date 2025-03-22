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

export async function getAllTopics() {
    console.log("Get all topics service reached");
    return [{
        id: '1',
        name: 'Financial Report 2023.pdf',
        originalTopic: 'Administrative',
        correctedTopic: 'Financial',
        correctedAt: '2024-03-20',
        confidence: 0.75
      },
      {
        id: '2',
        name: 'Risk Assessment.pdf',
        originalTopic: 'Financial',
        correctedTopic: 'Risk Management',
        correctedAt: '2024-03-21',
        confidence: 0.82
      }]
    
    // Perform the fetch request
    const response = await fetch(`${api.backendUrl}/upload/url?}`, {
        method: "GET",
        headers: {
            "Authorization": `${getCookie("CognitoToken")}`
        }
    });

    // Handle the response
    if (!response.ok) {
        throw new Error(`Failed to fetch topics. Status: ${response.status}`);
    }

    return await response.json(); // Assuming the backend responds with JSON
}