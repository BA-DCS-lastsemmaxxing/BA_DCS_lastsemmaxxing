"""
model.py

Defines a simple BERT-based classification model using Hugging Face Transformers.
"""

import torch
import torch.nn as nn
from transformers import AutoModel

class BertClassifier(nn.Module):
    """
    A simple classification model on top of a BERT base.
    """

    def __init__(self, model_name: str, num_labels: int):
        """
        :param model_name: The name of the pretrained model (FinBERT, LegalBERT, etc.).
        :param num_labels: The number of topics (labels).
        """
        super().__init__()
        self.bert = AutoModel.from_pretrained(model_name)
        self.dropout = nn.Dropout(p=0.3)
        self.classifier = nn.Linear(self.bert.config.hidden_size, num_labels)

    def forward(self, input_ids, attention_mask=None, labels=None):
        """
        Forward pass of the model.
        """
        outputs = self.bert(input_ids=input_ids, attention_mask=attention_mask)
        pooled_output = outputs.pooler_output  # shape: (batch_size, hidden_size)
        pooled_output = self.dropout(pooled_output)
        logits = self.classifier(pooled_output)

        output_dict = {"logits": logits}

        if labels is not None:
            loss_fn = nn.CrossEntropyLoss()
            loss = loss_fn(logits, labels)
            output_dict["loss"] = loss

        return output_dict
