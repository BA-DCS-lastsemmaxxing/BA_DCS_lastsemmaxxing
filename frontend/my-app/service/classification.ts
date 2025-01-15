export async function classify(input: string) {
    console.log("classification service reached");
    const response = await fetch(`${process.env.NEXT_PUBLIC_BACKEND_API_URL}/classify`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ document: input }),
      })

      return response
  }
