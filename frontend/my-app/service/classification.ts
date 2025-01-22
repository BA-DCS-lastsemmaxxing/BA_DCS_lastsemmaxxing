export async function upload(input: File[]) {
    console.log("Upload service reached");

    // Create a FormData object
    const formData = new FormData();

    // Append each file individually
    input.forEach((file) => {
        formData.append(`files`, file);
    });

    // Perform the fetch request
    const response = await fetch(`${process.env.NEXT_PUBLIC_BACKEND_API_URL}/upload`, {
    method: "POST",
    body: formData, // Attach FormData as the body
    });

    // Handle the response
    if (!response.ok) {
    throw new Error(`Failed to upload. Status: ${response.status}`);
    }

    return await response.json(); // Assuming the backend responds with JSON
}