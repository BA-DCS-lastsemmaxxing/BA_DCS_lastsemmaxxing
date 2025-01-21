import argparse
# from pdf_splitting import process_all_pdfs_in_folder
# from document_translator import process_and_combine
# from combine_extracted_csv import combine_csv_files
from datetime import datetime

from .ocr import generate_ocr_files




def main(input_dir, output_dir):
    ocr_output_dir = f"{output_dir}"

    start_time = datetime.now()

    generate_ocr_files(input_dir, ocr_output_dir)
    print(f"Processed data saved to {ocr_output_dir}")
    print(f"Start time: {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    end_time = datetime.now()
    print(f"End time: {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
    elapsed_time = end_time - start_time
    print(f"Elapsed time: {elapsed_time}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process some files.")
    parser.add_argument(
        "--input_dir",
        default="input_data",
        type=str,
        help="The input directory where your raw pdf files will be stored.",
    )
    parser.add_argument(
        "--output_dir",
        default="output_data",
        type=str,
        help="The output directory where the extracted.csv files will be stored.",
    )
    args = parser.parse_args()

    main(args.input_dir, args.output_dir)
