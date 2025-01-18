"""
test_integration.py

Integration test for the entire training process.
We won't test the training loop exhaustively (because it's expensive),
but we can do a smoke test to ensure everything runs end-to-end.
"""

import pytest
import torch
from src.data_preparation import DataPreparator
from src.model import BertClassifier
from src.train import DocumentDataset, train_model

def test_integration_train_process():
    # Arrange
    raw_data = [
        {"text": "Finance text ...", "label": "Financial"},
        {"text": "Tech text ...", "label": "Technology"},
        {"text": "Another finance doc ...", "label": "Financial"},
        {"text": "Marketing text ...", "label": "Marketing"},
    ]
    label2id = {"Financial": 0, "Technology": 1, "Marketing": 2}

    prep = DataPreparator(model_name='ipuneetr/finbert-uncased')
    train_df, val_df = prep.split_data(raw_data)

    train_labels = train_df['label'].map(label2id).tolist()
    val_labels = val_df['label'].map(label2id).tolist()

    train_encodings = prep.tokenize(train_df['text'].tolist())
    val_encodings = prep.tokenize(val_df['text'].tolist())

    train_dataset = DocumentDataset(train_encodings, train_labels)
    val_dataset = DocumentDataset(val_encodings, val_labels)

    model = BertClassifier('ipuneetr/finbert-uncased', num_labels=len(label2id))

    # Act
    # We only run 1 epoch and very small batch size for a quick smoke test
    trained_model = train_model(model, train_dataset, val_dataset, epochs=1, batch_size=1, lr=2e-5)

    # Assert
    # Check if model is on CPU or GPU
    device = next(trained_model.parameters()).device
    assert device.type in ['cuda', 'cpu']
    # We can also do a quick forward pass check
    trained_model.eval()
    dummy_input_ids = torch.randint(0, 1000, (1, 8)).to(device)
    dummy_attention_mask = torch.ones((1, 8)).to(device)
    outputs = trained_model(dummy_input_ids, attention_mask=dummy_attention_mask)
    assert 'logits' in outputs
