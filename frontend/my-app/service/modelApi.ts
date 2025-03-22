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
    
    // Perform the fetch request
    const response = await fetch(`${api.backendUrl}/topics`, {
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