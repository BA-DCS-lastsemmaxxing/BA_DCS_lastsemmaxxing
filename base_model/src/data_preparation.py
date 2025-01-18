"""
data_preparation.py

This module handles the data reading, splitting, and tokenization logic.
"""

import pandas as pd
from sklearn.model_selection import train_test_split
from transformers import AutoTokenizer

class DataPreparator:
    """
    DataPreparator is responsible for loading labeled documents,
    splitting into train/val/test, and tokenizing them.
    """

    def __init__(self, model_name: str, max_length: int = 256):
        """
        :param model_name: the HuggingFace model identifier (e.g. 'ipuneetr/finbert-uncased').
        :param max_length: maximum sequence length for tokenization.
        """
        self.tokenizer = AutoTokenizer.from_pretrained(model_name)
        self.max_length = max_length

    def split_data(self, data, label_col='label', text_col='text', test_size=0.2, random_state=42):
        """
        Splits data into train and validation sets.
        """
        df = pd.DataFrame(data)
        train_df, val_df = train_test_split(df, test_size=test_size, random_state=random_state, stratify=df[label_col])
        return train_df, val_df

    def tokenize(self, texts):
        """
        Applies BERT tokenizer to a list of texts.
        """
        return self.tokenizer(
            texts,
            padding=True,
            truncation=True,
            max_length=self.max_length,
            return_tensors='pt'
        )
