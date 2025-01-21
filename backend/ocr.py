import logging
import sys
import os
import subprocess
from ctypes.util import find_library
from pypdf import PdfReader
from preprocessing import clean_text_files
find_library("gs")

def generate_ocr_files(input_folder_path, output_folder_path):
    os.makedirs(output_folder_path, exist_ok=True)
    
    file_list = []

    for filename in os.listdir(input_folder_path):
        if filename.endswith("pdf"):
            file_list.append(filename)


    for filename in file_list:
        print("Converting:", filename)
        input_filename = os.path.join(input_folder_path, filename)
        output_filename = os.path.join(output_folder_path, filename.replace(".pdf", "_ocr.pdf"))

        # Use subprocess to call ocrmypdf
        try:
            subprocess.run(
                ["ocrmypdf", "--deskew", "--force-ocr", input_filename, output_filename],
                check=True
            )
            print(f"Successfully processed: {filename}")
        except subprocess.CalledProcessError as e:
            print(f"Error processing {filename}: {e}")
    # Extract text from OCR processed PDFs into .txt files
    extract_text_from_pdfs(output_folder_path)
    # Clean extracted text files
    clean_text_files(output_folder_path)

def extract_text_from_pdfs(folder_path):
    for filename in os.listdir(folder_path):
        if filename.endswith("_ocr.pdf"):
            pdf_path = os.path.join(folder_path, filename)
            txt_path = os.path.join(folder_path, filename.replace("_ocr.pdf", ".txt"))
            reader = PdfReader(pdf_path)
            with open(txt_path, 'w') as f:
                for page in reader.pages:
                    f.write(page.extract_text() + "\n")
            print(f"Extracted text from {filename} to {txt_path}")