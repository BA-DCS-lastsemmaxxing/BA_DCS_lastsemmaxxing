import { configService } from './config';
import { Document } from '@/types/document'
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

export async function addNewTopic(topic: string, files: {file_id: string, file_name: string}[]) {
    console.log("Add new topic service reached");
    
    // Perform the fetch request
    const response = await fetch(`${api.backendUrl}/topics`, {
        method: "POST",
        headers: {
            "Authorization": `${getCookie("CognitoToken")}`,
            "Content-Type": "application/json"
        },
        body: JSON.stringify({
            "topic": topic,
            "files": files 
        })
    });

    // Handle the response
    if (!response.ok) {
        throw new Error(`Failed to fetch topics. Status: ${response.status}`);
    }

    return await response; // Assuming the backend responds with JSON
}

export async function removeTopic(topic: string) {
    console.log("Remove topic service reached");
    console.log("Topic to delete: ", topic);
    // Perform the delete request
    const response = await fetch(`${api.backendUrl}/topics`, {
        method: "DELETE",
        headers: {
            "Authorization": `${getCookie("CognitoToken")}`,
            "Content-Type": "application/json"
        },
        body: JSON.stringify({
            "topic": topic
        })
    });

    // Handle the response
    if (!response.ok) {
        throw new Error(`Failed to delete topic. Status: ${response.status}`);
    }

    return await response.json(); // Assuming the backend responds with JSON
}

export async function feedbackRetraining(documents: Document[]) {
    // Perform the delete request
    const response = await fetch(`${api.backendUrl}/retrain`, {
        method: "POST",
        headers: {
            "Authorization": `${getCookie("CognitoToken")}`,
            "Content-Type": "application/json"
        },
        body: JSON.stringify({
            "documents": documents
        })
    });

    // Handle the response
    if (!response.ok) {
        throw new Error(`Failed to retrain model with feedback. Status: ${response.status}`);
    }

    return await response.json(); // Assuming the backend responds with JSON
}