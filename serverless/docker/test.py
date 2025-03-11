import json, boto3
from botocore.config import Config
MODEL_ID_LLAMA = "arn:aws:bedrock:us-west-2:874280117166:inference-profile/us.meta.llama3-3-70b-instruct-v1:0"

config = Config(read_timeout=1000)
bedrock_client = boto3.client(
    "bedrock-runtime",
    region_name="us-west-2",
    config=config
)
response = bedrock_client.invoke_model(
            modelId=MODEL_ID_LLAMA,
            body=json.dumps({
                "prompt": "tell me a story",
                "max_gen_len": 512,
                "temperature": 0,
            }),
            contentType="application/json"
        )

print(response)