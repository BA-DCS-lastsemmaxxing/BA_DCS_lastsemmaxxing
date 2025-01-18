"""
train.py

Script to fine-tune the BertClassifier using a Hugging Face Trainer or a custom loop.
Demonstrates single-label classification approach.
"""

import torch
from torch.utils.data import Dataset, DataLoader
from transformers import AdamW, get_linear_schedule_with_warmup
from tqdm import tqdm

class DocumentDataset(Dataset):
    """
    A PyTorch Dataset for our documents.
    Expects that 'input_ids' and 'attention_mask' are pre-tokenized,
    and 'label' is an integer representing the class.
    """
    def __init__(self, encodings, labels):
        self.encodings = encodings
        self.labels = labels

    def __getitem__(self, idx):
        item = {key: val[idx] for key, val in self.encodings.items()}
        item['labels'] = torch.tensor(self.labels[idx], dtype=torch.long)
        return item

    def __len__(self):
        return len(self.labels)

def train_model(model, train_dataset, val_dataset, epochs=3, batch_size=8, lr=1e-5):
    """
    Custom training loop for the classification model.
    """

    train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)
    val_loader = DataLoader(val_dataset, batch_size=batch_size, shuffle=False)

    optimizer = AdamW(model.parameters(), lr=lr)
    total_steps = len(train_loader) * epochs
    scheduler = get_linear_schedule_with_warmup(optimizer, 
                                                num_warmup_steps=0,
                                                num_training_steps=total_steps)

    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    model.to(device)

    for epoch in range(epochs):
        model.train()
        total_loss = 0

        for batch in tqdm(train_loader, desc=f"Epoch {epoch+1}/{epochs}"):
            input_ids = batch['input_ids'].to(device)
            attention_mask = batch['attention_mask'].to(device)
            labels = batch['labels'].to(device)

            optimizer.zero_grad()
            outputs = model(input_ids, attention_mask, labels=labels)
            loss = outputs['loss']
            loss.backward()
            optimizer.step()
            scheduler.step()

            total_loss += loss.item()

        avg_train_loss = total_loss / len(train_loader)
        print(f"Epoch {epoch+1}, Training loss: {avg_train_loss:.4f}")

        # Validation step
        model.eval()
        val_loss = 0
        correct = 0
        total = 0

        with torch.no_grad():
            for batch in val_loader:
                input_ids = batch['input_ids'].to(device)
                attention_mask = batch['attention_mask'].to(device)
                labels = batch['labels'].to(device)

                outputs = model(input_ids, attention_mask, labels=labels)
                val_loss += outputs['loss'].item()

                logits = outputs['logits']
                predictions = torch.argmax(logits, dim=1)
                correct += (predictions == labels).sum().item()
                total += labels.size(0)

        avg_val_loss = val_loss / len(val_loader)
        accuracy = correct / total
        print(f"Validation loss: {avg_val_loss:.4f}, Validation Accuracy: {accuracy:.4f}")

    return model

if __name__ == "__main__":
    # Example usage:

    from data_preparation import DataPreparator
    from base_model import BertClassifier

    # 1. Prepare data
    # Suppose we have a labeled dataset
    raw_data = [
        {"text": "Finance text ...", "label": "Financial"},
        {"text": "Tech text ...", "label": "Technology"},
        {"text": "Another finance doc ...", "label": "Financial"},
        {"text": "Marketing text ...", "label": "Marketing"},
        # ...
    ]

    # Convert labels to integers for training
    label2id = {"Financial": 0, "Technology": 1, "Marketing": 2}
    id2label = {v: k for k, v in label2id.items()}

    # 2. Initialize DataPreparator
    model_name = 'ipuneetr/finbert-uncased'
    preparator = DataPreparator(model_name=model_name)

    # 3. Split data
    train_df, val_df = preparator.split_data(raw_data)

    # Convert text labels to IDs
    train_labels = train_df['label'].map(label2id).tolist()
    val_labels = val_df['label'].map(label2id).tolist()

    # 4. Tokenize
    train_encodings = preparator.tokenize(train_df['text'].tolist())
    val_encodings = preparator.tokenize(val_df['text'].tolist())

    # 5. Create Datasets
    train_dataset = DocumentDataset(train_encodings, train_labels)
    val_dataset = DocumentDataset(val_encodings, val_labels)

    # 6. Instantiate model
    num_labels = len(label2id)
    model = BertClassifier(model_name, num_labels)

    # 7. Train model
    trained_model = train_model(model, train_dataset, val_dataset, epochs=2, batch_size=2, lr=2e-5)

    # 8. (Optional) Save the model
    torch.save(trained_model.state_dict(), "finbert_classifier.pt")
    print("Model training complete and saved.")
