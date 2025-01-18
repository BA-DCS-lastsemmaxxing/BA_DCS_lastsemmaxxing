from ocr import generate_ocr_files
# from pdf_splitting import process_all_pdfs_in_folder
# from document_translator import process_and_combine
# from combine_extracted_csv import combine_csv_files
from datetime import datetime
import argparse

# input_dir = 'input_files'
# output_dir = 'output_files'
# ocr_output_dir = f'{output_dir}/ocr_files'
# split_pdf_dir = f'{output_dir}/split_pdfs'
# extracted_csv_dir = f'{output_dir}/extracted_csv'

def main(input_dir, output_dir):
    ocr_output_dir = f'{output_dir}/AML_output'
    # split_pdf_dir = f'{output_dir}/split_pdfs'
    # extracted_csv_dir = f'{output_dir}/extracted_csv'

    start_time = datetime.now()
    
    generate_ocr_files(input_dir, ocr_output_dir)
    # process_all_pdfs_in_folder(ocr_output_dir, split_pdf_dir)
    # process_and_combine(split_pdf_dir, extracted_csv_dir)
    print(f"Processed data saved to {ocr_output_dir}")
    # combine_csv_files(extracted_csv_dir, extracted_csv_dir)
    print(f"Start time: {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    end_time = datetime.now()
    print(f"End time: {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
    elapsed_time = end_time - start_time
    print(f"Elapsed time: {elapsed_time}")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Process some files.')
    parser.add_argument('--input_dir', default="sample/test", type=str, help='The input directory where your raw pdf files will be stored.')
    parser.add_argument('--output_dir', default="pre_processing", type=str, help='The output directory where the extracted.csv files will be stored.')
    args = parser.parse_args()
    
    main(args.input_dir, args.output_dir)