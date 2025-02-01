import os
import sys
import subprocess
import threading
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS

# Import the SQLAlchemy and Bcrypt classes
import mysql.connector
import bcrypt
from config import Config
from routes import auth_blueprint
from models import Document

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "http://localhost:3000"}})


app.config.from_object(Config)

app.register_blueprint(auth_blueprint)

# Define paths relative to the backend folder
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
INPUT_FOLDER = os.path.join(BASE_DIR, "input_data")
OUTPUT_FOLDER = os.path.join(BASE_DIR, "output_data")
OCR_SCRIPT = os.path.join(BASE_DIR, "ocr.py")
EXTRACTOR_SCRIPT = os.path.join(BASE_DIR, "pdf_extractor.py")

# Ensure folders exist
os.makedirs(INPUT_FOLDER, exist_ok=True)
os.makedirs(OUTPUT_FOLDER, exist_ok=True)


# To test the Flask app       
@app.route('/')
def home():
    return jsonify({"message": "Welcome to Flask!"})

def run_ocr(input_folder, output_folder):
    """Run the OCR script as a subprocess."""
    try:
        subprocess.run(
            [sys.executable, OCR_SCRIPT, input_folder, output_folder],
            check=True
        )
    except subprocess.CalledProcessError as e:
        print(f"Error running OCR script: {e}")

def run_extractor():
    """Run the PDF extractor script as a subprocess."""
    try:
        subprocess.run(
            [sys.executable, EXTRACTOR_SCRIPT],
            check=True
        )
    except subprocess.CalledProcessError as e:
        print(f"Error running extractor script: {e}")
        

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

                # Store metadata in database with dummy values
                Document.store_metadata(file.filename)

        # Run OCR and extraction in separate threads
        threading.Thread(target=run_ocr, args=(INPUT_FOLDER, OUTPUT_FOLDER)).start()
        threading.Thread(target=run_extractor).start()

        return jsonify({"message": "Files uploaded and processing started."})
    except Exception as e:
        print(f"Error during file upload: {e}")
        return jsonify({"error": "Internal Server Error"}), 500


####################################################################################################################

@app.route("/documents", methods=["GET"])
def search_documents():
    query = request.args.get("query", default=None)
    print("Query: ", query, flush=True)

    # Fetch documents metadata
    documents = Document.get_documents(query)

    return jsonify({"results": documents}), 200

    
    
    
    
    
####################################################################################################################


# @app.route("/download/<filename>", methods=["GET"])
# def download_file(filename):
#     """Endpoint to download processed files."""
#     file_path = os.path.join(OUTPUT_FOLDER, filename)
#     if not os.path.exists(file_path):
#         return jsonify({"error": "File not found"}), 404
#     return send_file(file_path, as_attachment=True)





if __name__ == "__main__":
    app.run(debug=True, port=5001)
