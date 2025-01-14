## This function helps to loop through a directory and then replace a pdf that has been converted to ocr_pdf format into a text file. 

from pypdf import PdfReader
import os
from docx import Document
from docx.shared import Inches

pdf_path = os.path.join(os.getcwd(), "input_data")
################################################################
listoffiles = os.listdir(pdf_path)


################################################################
for i in range(0,len(listoffiles)):
  reader = PdfReader(pdf_path+"/"+listoffiles[i])
  with open(os.path.join(pdf_path, listoffiles[i].replace(".pdf",".txt") ), 'a') as f:
    for page in reader.pages:
      f.write(page.extract_text() + "\n")
################################################################