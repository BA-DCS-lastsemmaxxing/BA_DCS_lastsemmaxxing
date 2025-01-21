import os

# from docx import Document
# from docx.shared import Inches
from pypdf import PdfReader

pdf_path = os.path.join(os.getcwd(), "input_data")
output_directory = os.path.join(
    os.getcwd(), "output_data"
)  # Specify the output directory

# Ensure the output directory exists
os.makedirs(output_directory, exist_ok=True)

listoffiles = os.listdir(pdf_path)


################################################################
for i in range(0, len(listoffiles)):
    try:
        reader = PdfReader(pdf_path + "/" + listoffiles[i])
        # Save the text files in the output_data directory
        output_file = os.path.join(
            output_directory, listoffiles[i].replace(".pdf", ".txt")
        )
        with open(output_file, "a", encoding="utf-8") as f:
            for page in reader.pages:
                f.write(page.extract_text() + "\n")
    except Exception as e:
        print(f"Error processing {listoffiles[i]}: {e}")
################################################################
