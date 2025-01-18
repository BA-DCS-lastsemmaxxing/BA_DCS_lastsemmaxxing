"""
test_base_model.py

Unit tests for model.py
"""

import torch
from src.model import BertClassifier

def test_bert_classifier_forward_pass():
    # Arrange
    model_name = 'ipuneetr/finbert-uncased'
    num_labels = 3
    model = BertClassifier(model_name, num_labels)

    # Create some dummy data
    batch_size = 2
    seq_length = 10
    input_ids = torch.randint(0, 1000, (batch_size, seq_length))
    attention_mask = torch.ones((batch_size, seq_length))
    labels = torch.tensor([0, 2])  # Example labels

    # Act
    outputs = model(input_ids, attention_mask=attention_mask, labels=labels)

    # Assert
    assert 'logits' in outputs
    assert 'loss' in outputs
    assert outputs['logits'].shape == (batch_size, num_labels)
    assert outputs['loss'].shape == ()
