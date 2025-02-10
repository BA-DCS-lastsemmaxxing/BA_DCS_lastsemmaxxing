# BA_DCS_lastsemmaxxing

## Key Resources
Weekly Updates: https://drive.google.com/drive/folders/1o8y0EWdAuGMQe17fiuy6eFUvAWo5dUt3?usp=drive_link
Figma Wireframe: https://www.figma.com/design/2C31Fox5FKbKZVwxzbCV9O/IS483-UI-Wireframe?node-id=0-1&p=f&t=W9CMfhO1DnFUEP5F-0 

## Installation
### Backend:
1. Navigate to the `backend` directory:
    ```bash
    cd backend
    ```
2. Create a virtual environment:
    ```bash
    python -m venv venv
    ```
3. Activate the virtual environment:
    - On Windows:
      ```bash
      venv\Scripts\activate
      ```
    - On macOS/Linux:
      ```bash
      source venv/bin/activate
      ```
4. Install required packages:
    ```bash
    pip install flask flask-cors ocrmypdf pypdf python-docx
    ```

### Frontend:
1. Navigate to the frontend project directory:
    ```bash
    cd frontend/my-app
    ```
2. Install dependencies (if not already installed):
    ```bash
    npm install
    ```
#### Env Files:
1. Create .env in frontend/my-app/:
    ```
    NEXT_PUBLIC_BACKEND_API_URL=http://localhost:5001
    ```
## Running the Application

### Backend:
1. Navigate to the `backend` directory:
    ```bash
    cd backend
    ```
2. Create and activate the virtual environment (if not already done):
    ```bash
    python -m venv venv
    venv\Scripts\activate  # For Windows
    # OR
    source venv/bin/activate  # For macOS/Linux
    ```
3. Start the backend server:
    ```bash
    python app.py
    ```
4. Open the backend in your browser or API client at:
    ```
    http://127.0.0.1:5001
    ```

### Frontend:
1. Navigate to the `frontend/my-app` directory:
    ```bash
    cd frontend/my-app
    ```
2. Start the development server:
    ```bash
    npm run dev
    ```
3. Open the application in your browser at:
    ```
    http://localhost:3000
    ```

