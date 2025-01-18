"""
test_data_preparation.py

Unit tests for data_preparation.py
"""

import pytest
from src.data_preparation import DataPreparator

def test_data_preparation_split_data():
    # Arrange
    data = [
        {"text": "Doc 1 text", "label": "Technology"},
        {"text": "Doc 2 text", "label": "Financial"},
        {"text": "Doc 3 text", "label": "Technology"},
        {"text": "Doc 4 text", "label": "Financial"},
    ]
    prep = DataPreparator(model_name='ipuneetr/finbert-uncased')

    # Act
    train_df, val_df = prep.split_data(data, label_col='label')

    # Assert
    # We expect 3 data in train and 1 in val (80/20 split for 4 samples).
    assert len(train_df) == 3
    assert len(val_df) == 1
    # Check that the columns exist
    assert 'text' in train_df.columns
    assert 'label' in train_df.columns

def test_data_preparation_tokenize():
    # Arrange
    data = [
        "Document text about finance.",
        "Document text about technology."
    ]
    prep = DataPreparator(model_name='ipuneetr/finbert-uncased')

    # Act
    tokenized = prep.tokenize(data)

    # Assert
    assert 'input_ids' in tokenized
    assert 'attention_mask' in tokenized
    # The batch size should match the number of documents
    assert tokenized['input_ids'].shape[0] == 2
