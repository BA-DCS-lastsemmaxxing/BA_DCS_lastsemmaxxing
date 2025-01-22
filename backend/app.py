import os
import sys
import subprocess
import threading
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

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

    if "files" not in request.files:
        return jsonify({"error": "No files part in the request"}), 400

    # Clear the input_data folder
    for file in os.listdir(INPUT_FOLDER):
        file_path = os.path.join(INPUT_FOLDER, file)
        try:
            if os.path.isfile(file_path):
                os.unlink(file_path)
        except Exception as e:
            print(f"Error deleting file {file_path}: {e}")

    # Clear the output_data folder
    for file in os.listdir(OUTPUT_FOLDER):
        file_path = os.path.join(OUTPUT_FOLDER, file)
        try:
            if os.path.isfile(file_path):
                os.unlink(file_path)
        except Exception as e:
            print(f"Error deleting file {file_path}: {e}")

    files = request.files.getlist("files")

    for file in files:
        if file.filename.endswith(".pdf"):
            file.save(os.path.join(INPUT_FOLDER, file.filename))

    # Run OCR and extraction in separate threads to avoid blocking
    threading.Thread(target=run_ocr, args=(INPUT_FOLDER, OUTPUT_FOLDER)).start()
    threading.Thread(target=run_extractor).start()

    return jsonify({"message": "Files uploaded and processing started."})


@app.route("/download/<filename>", methods=["GET"])
def download_file(filename):
    """Endpoint to download processed files."""
    file_path = os.path.join(OUTPUT_FOLDER, filename)
    if not os.path.exists(file_path):
        return jsonify({"error": "File not found"}), 404
    return send_file(file_path, as_attachment=True)


if __name__ == "__main__":
    app.run(debug=True, port=5001)
