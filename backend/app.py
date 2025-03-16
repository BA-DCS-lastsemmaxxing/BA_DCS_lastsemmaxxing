import os
from flask import Flask, request, jsonify
from flask_cors import CORS

# Import the SQLAlchemy and Bcrypt classes
from config import Config
from routes import auth_blueprint
from models import Document

app = Flask(__name__)
CORS(app, origins="http://localhost:3000", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"], allow_headers=["Content-Type"])

app.config.from_object(Config)
app.register_blueprint(auth_blueprint)

# Define paths relative to the backend folder
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
INPUT_FOLDER = os.path.join(BASE_DIR, "input_data")
OUTPUT_FOLDER = os.path.join(BASE_DIR, "output_data")

# Ensure folders exist
os.makedirs(INPUT_FOLDER, exist_ok=True)
os.makedirs(OUTPUT_FOLDER, exist_ok=True)

@app.route("/upload", methods=["POST"])
def upload_files():
    """Endpoint to upload PDF files."""
    try:
        if "files" not in request.files:
            return jsonify({"error": "No files part in the request"}), 400

        # Clear the input_data and output_data folders
        for folder in [INPUT_FOLDER, OUTPUT_FOLDER]:
            for file in os.listdir(folder):
                file_path = os.path.join(folder, file)
                try:
                    if os.path.isfile(file_path):
                        os.unlink(file_path)
                except Exception as e:
                    print(f"Error deleting file {file_path}: {e}")

        files = request.files.getlist("files")
        for file in files:
            if file.filename.endswith(".pdf"):
                file_path = os.path.join(INPUT_FOLDER, file.filename)
                file.save(file_path)

                # Insert metadata into the database
                Document.insert_file_record(file.filename)

        return jsonify({"message": "Files uploaded and processing started."})
    except Exception as e:
        print(f"Error during file upload: {e}")
        return jsonify({"error": "Internal Server Error"}), 500

@app.route("/documents", methods=["GET", "OPTIONS"])
def search_documents():
    if request.method == "OPTIONS":
        response = jsonify({})
        response.headers.add("Access-Control-Allow-Origin", "http://localhost:3000")
        response.headers.add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        response.headers.add("Access-Control-Allow-Headers", "Content-Type")
        return response, 200

    query = request.args.get("query", default=None)
    documents = Document.get_documents(query)
    response = jsonify({"results": documents})
    response.headers.add("Access-Control-Allow-Origin", "http://localhost:3000")
    return response

@app.route("/send_feedback", methods=["POST"])
def send_feedback():
    """Endpoint to update user-corrected category and feedback."""
    try:
        # Get document_id from query parameters
        document_id = request.args.get("document_id")
        if not document_id:
            return jsonify({"error": "Missing document ID"}), 400

        document_id = document_id.strip()
        print(f"Received request to update document ID: {document_id}")

        # Ensure request body is JSON
        if not request.is_json:
            return jsonify({"error": "Request body must be JSON"}), 400

        data = request.get_json()
        print(f"Request Data: {data}")

        if not data:
            return jsonify({"error": "No JSON data provided"}), 400

        user_corrected_category = data.get("user_corrected_category")
        feedback = data.get("feedback")

        if not user_corrected_category or not feedback:
            return jsonify({"error": "Missing required fields"}), 400

        print(f"Updating document with category: {user_corrected_category}, feedback: {feedback}")

        # Call update method
        success = Document.update_document(document_id, user_corrected_category, feedback)
        if success:
            return jsonify({"message": f"Document {document_id} updated successfully."}), 200
        else:
            return jsonify({"error": f"Document {document_id} not found."}), 404

    except Exception as e:
        print(f"Error updating document: {e}")
        return jsonify({"error": "Internal Server Error"}), 500


@app.route("/delete_document/<string:id>", methods=["DELETE"])
def delete_document(id):
    """Endpoint to delete a document by ID."""
    try:
        success = Document.delete_document(id)
        if success:
            return jsonify({"message": f"Document {id} deleted successfully."}), 200
        else:
            return jsonify({"error": f"Document {id} not found."}), 404
    except Exception as e:
        print(f"Error during document deletion: {e}")
        return jsonify({"error": "Internal Server Error"}), 500

if __name__ == "__main__":
    app.run(debug=True, port=5001)
