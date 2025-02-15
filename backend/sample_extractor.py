'''
This function is used after the text has been extracted from the raw PDFs, and then it extracts a hybrid sample made out of the Intro, Middle and Conclusion, but contain no more than 16k tokens. This seeks to improve the efficiency of the model and save cost, since we pass in a sample that retains as much information as possible from the original text, but is not too large to be processed by the model.

'''

# Define input and output directories
input_directory = "Cleaned_Data_v2"  # Please enter folder of raw text that has been extracted from raw PDF.
output_directory = "Extracted_Data"  # Please enter folder to store extracted hybrid texts.

# Ensure output directory exists
os.makedirs(output_directory, exist_ok=True)

def extract_text_samples(input_directory, output_directory):
    """
    Reads text files from the input directory, applies hybrid text extraction, 
    and saves the hybrid extracted text into a structured output directory.
    """
    for main_topic in os.listdir(input_directory):
        main_topic_path = os.path.join(input_directory, main_topic)
        output_main_topic_path = os.path.join(output_directory, main_topic)

        if os.path.isdir(main_topic_path): 
            for root, _, files in os.walk(main_topic_path):
                relative_path = os.path.relpath(root, input_directory)  
                output_subfolder_path = os.path.join(output_directory, relative_path)

                os.makedirs(output_subfolder_path, exist_ok=True)  # Create output folder

                for file in files:
                    if file.endswith(".txt"):
                        file_path = os.path.join(root, file)

                        with open(file_path, "r", encoding="utf-8") as f:
                            content = f.read()

                        # Extract hybrid section
                        intro, middle, conclusion = extract_intro_middle_conclusion_v7(content, main_topic)
                        hybrid_text = f"{intro} {middle} {conclusion}"

                        # Define new filename for hybrid text
                        base_filename = os.path.splitext(file)[0]  # Remove .txt extension
                        hybrid_path = os.path.join(output_subfolder_path, f"{base_filename}_extracted.txt")

                        # Save hybrid text
                        with open(hybrid_path, "w", encoding="utf-8") as f:
                            f.write(hybrid_text)

                        print(f"Processed: {file} → Text sample saved to {output_subfolder_path}")

# Run the extraction process
extract_text_samples(input_directory, output_directory)
