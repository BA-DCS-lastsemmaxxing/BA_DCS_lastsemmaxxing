import time
import os
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from classification import classify
from models import Document

# Replace with your folder path
path_to_watch = "./input_data"

def process_new_file(file_path, file_id):
    if file_path.endswith(".pdf"):  # Ensure it's a PDF
        with open(file_path, "rb") as file:
            file_content = file.read()  # Read the file as bytes
        filename = os.path.basename(file_path).replace(".pdf", "")
        
        # Call your existing function
        classify(file_content, filename, file_id)
        print(f"Processed: {file_path}")

# Custom event handler to detect new files
class NewFileHandler(FileSystemEventHandler):
    def on_created(self, event):
        if not event.is_directory:  # Ignore directory changes
            file_path = event.src_path
            file_name = os.path.basename(file_path)  # Extract the filename
            print(f"New file detected: {file_name}")

            file_id = Document.insert_file_record(file_name)  # Use filename
            process_new_file(file_path, file_id)

# Function to start watching a directory
def watch_directory(folder_path):
    event_handler = NewFileHandler()
    observer = Observer()
    observer.schedule(event_handler, folder_path, recursive=False)
    observer.start()
    
    print(f"Watching directory: {folder_path} for new files...")
    
    try:
        while True:
            time.sleep(1)  # Keep script running
    except KeyboardInterrupt:
        observer.stop()
    observer.join()


watch_directory(path_to_watch)
