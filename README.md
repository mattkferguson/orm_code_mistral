# Deploying ORM Stack for A10 GPU with Local vLLM Mistral
In this guide, we'll walk through the steps required to deploy an Oracle Cloud Infrastructure (OCI) Resource Manager (ORM) stack that provisions an A10 shape instance with one GPU. The setup also includes configuring the instance to run a local vLLM Mistral model for natural language processing tasks.

## Installation
To begin, you can utilize OCI's Resource Manager from the console to upload and execute the deployment code. Ensure you have access to an OCI Virtual Cloud Network (VCN) and a subnet where the VM will be deployed.

## Requirements
- **Instance Type**: A10 shape with one GPU.
- **Operating System**: Oracle Linux.
- **Image Selection**: The deployment script selects the latest Oracle Linux image with GPU support.
- 
  ```
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"

  filter {
    name   = "launch_mode"
    values = ["NATIVE"]
  }
  filter {
    name = "display_name"
    values = ["\\w*GPU\\w*"]
    regex = true
  }
  ```
- **Tags: Adds a freeform tag GPU_TAG = "A10-1"**
- **Boot Volume Size: 250 GB.**
- **Initialization: Uses cloud-init to download and configure the vLLM Mistral model(s).**
## Cloud-init Configuration 
- *The cloud-init script installs necessary dependencies, installes Docker, downloads and starts the vLLM Mistral model(s).*
```
dnf install -y dnf-utils zip unzip
dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
dnf remove -y runc
dnf install -y docker-ce --nobest
systemctl enable docker.service
dnf install -y nvidia-container-toolkit
systemctl start docker.service
...
```
## Monitoring the system
- *Track cloud-init completion and  GPU resource usage with these commands (if needed):*
- **Monitor cloud-init completion:** tail -f /var/log/cloud-init-output.log
- **Monitor GPU utilization:** nvidia-smi dmon -s mu -c 100
## Starting the vLLM model
- **Deploy and interact with the vLLM Mistral model using Python.**
- *Adjust the parameters only if needed:*
```
python -O -u -m vllm.entrypoints.openai.api_server \
    --host 0.0.0.0 \
    --model "/home/opc/models/${MODEL}" \
    --tokenizer hf-internal-testing/llama-tokenizer \
    --max-model-len 16384 \
    --enforce-eager \
    --gpu-memory-utilization 0.8 \
    --max-num-seqs 2 \
    >> "${MODEL}.log" 2>&1 &
```
## Testing the model integration
- **Test the model from CLI once cloud-init has completed:**
```
curl -X 'POST' 'http://0.0.0.0:8000/v1/chat/completions' \
-H 'accept: application/json' \
-H 'Content-Type: application/json' \
-d '{
    "model": "/home/opc/models/'"$MODEL"'",
    "messages": [{"role":"user", "content":"Write a small poem."}],
    "max_tokens": 64
}'
```
- **Test the model started locally with Jupyter notebook (Please open port 8888):**
```
import requests
import json
import os

# Retrieve the MODEL environment variable
model = os.environ.get('MODEL')

url = 'http://0.0.0.0:8000/v1/chat/completions'
headers = {
    'accept': 'application/json',
    'Content-Type': 'application/json',
}

data = {
    "model": f"/home/opc/models/{model}",
    "messages": [{"role": "user", "content": "Write a short conclusion."}],
    "max_tokens": 64
}

response = requests.post(url, headers=headers, json=data)

if response.status_code == 200:
    result = response.json()
    # Pretty print the response for better readability
    formatted_response = json.dumps(result, indent=4)
    print("Response:", formatted_response)
else:
    print("Request failed with status code:", response.status_code)
    print("Response:", response.text)
```
- **Gradio integration with chatbot feaure to query the model started locally:**
```
import requests
import gradio as gr
import os

def interact_with_model(prompt):
    model = os.getenv("MODEL")  # Retrieve the MODEL environment variable within the function
    url = 'http://0.0.0.0:8000/v1/chat/completions'
    headers = {
        'accept': 'application/json',
        'Content-Type': 'application/json',
    }

    data = {
        "model": f"/home/opc/models/{model}",
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 64
    }

    response = requests.post(url, headers=headers, json=data)

    if response.status_code == 200:
        result = response.json()
        completion_text = result["choices"][0]["message"]["content"].strip()  # Extract the generated text
        return completion_text
    else:
        return {"error": f"Request failed with status code {response.status_code}"}

# Example Gradio interface
iface = gr.Interface(
    fn=interact_with_model,
    inputs=gr.Textbox(lines=2, placeholder="Write a prompt..."),
    outputs=gr.Textbox(type="text", placeholder="Response..."),
    title="Mistral 7B Chat Interface",
    description="Interact with the Mistral 7B model deployed locally via Gradio.",
    live=True
)

# Launch the Gradio interface
iface.launch(share=True)
```
- **Docker deployment:**
- *Alternatively, deploy the model using Docker from external source:*
```
docker run --gpus all \
    -v ~/.cache/huggingface:/root/.cache/huggingface \
    --env "HUGGING_FACE_HUB_TOKEN=$ACCESS_TOKEN" \
    -p 8000:8000 \
    --ipc=host \
    --restart always \
    vllm/vllm-openai:latest \
    --model mistralai/$MODEL \
    --max-model-len 16384
```
- **Query the model working with Docker from extrnal source and using CLI:**
```
curl -X 'POST' 'http://0.0.0.0:8000/v1/chat/completions' \
-H 'accept: application/json' \
-H 'Content-Type: application/json' \
-d '{
  "model": "mistralai/'"$MODEL"'",
  "messages": [{"role": "user", "content": "Write a small poem."}],
  "max_tokens": 64
}'
```
- **Query the model working with Docker from external source and Jupyter notebook:**
```
import requests
import json
import os

# Retrieve the MODEL environment variable
model = os.environ.get('MODEL')

url = 'http://0.0.0.0:8000/v1/chat/completions'
headers = {
    'accept': 'application/json',
    'Content-Type': 'application/json',
}

data = {
    "model": f"mistralai/{model}",
    "messages": [{"role": "user", "content": "Write a short conclusion."}],
    "max_tokens": 64
}

response = requests.post(url, headers=headers, json=data)

if response.status_code == 200:
    result = response.json()
    # Pretty print the response for better readability
    formatted_response = json.dumps(result, indent=4)
    print("Response:", formatted_response)
else:
    print("Request failed with status code:", response.status_code)
    print("Response:", response.text)
```
- **Query the model working with Docker from external source and using Jupyter notebook with Gradio chat:**
```
import requests
import gradio as gr
import os

# Function to interact with the model via API
def interact_with_model(prompt):
    url = 'http://0.0.0.0:8000/v1/chat/completions'
    headers = {
        "accept": "application/json",
        "Content-Type": "application/json",
    }

    # Retrieve the MODEL environment variable
    model = os.environ.get('MODEL')

    data = {
        "model": f"mistralai/{model}",
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 64
    }

    response = requests.post(url, headers=headers, json=data)

    if response.status_code == 200:
        result = response.json()
        completion_text = result["choices"][0]["message"]["content"].strip()  # Extract the generated text
        return completion_text
    else:
        return {"error": f"Request failed with status code {response.status_code}"}

# Example Gradio interface
iface = gr.Interface(
    fn=interact_with_model,
    inputs=gr.Textbox(lines=2, placeholder="Write a prompt..."),
    outputs=gr.Textbox(type="text", placeholder="Response..."),
    title="Model Interface",  # Set a title for your Gradio interface
    description="Interact with the model deployed via Gradio.",  # Set a description
    live=True
)

# Launch the Gradio interface
iface.launch(share=True)
```
- *Alternatively, you can deploy the model using Docker and the model files extracted locally:*
```
docker run --gpus all \
-v /home/opc/models/$MODEL/:/mnt/model/ \
--env "HUGGING_FACE_HUB_TOKEN=$TOKEN_ACCESS" \
-p 8000:8000 \
--env "TRANSFORMERS_OFFLINE=1" \
--env "HF_DATASET_OFFLINE=1" \
--ipc=host vllm/vllm-openai:latest \
--model="/mnt/model/" \
--max-model-len 16384 \
--tensor-parallel-size 2
```
- **Query the model working with Docker and the model files extracted locally using CLI:**
```
curl -X 'POST' 'http://0.0.0.0:8000/v1/chat/completions' -H 'accept: application/json' -H 'Content-Type: application/json' -d '{
>     "model": "/mnt/model/",
>     "messages": [{"role": "user", "content": "Write a humorous limerick about the wonders of GPU computing."}],
>      "max_tokens": 64,
>     "temperature": 0.7,
>      "top_p": 0.9
>  }'

```
- **Query the model working with Docker and the model files extracted locally using Jupyter notebook:**
```
import requests
import json
import os

url = "http://0.0.0.0:8000/v1/chat/completions"
headers = {
    "accept": "application/json",
    "Content-Type": "application/json",
}

# Assuming `MODEL` is an environment variable set appropriately
model = f"/mnt/model/"  # Adjust this based on your specific model path or name

data = {
    "model": model,
    "messages": [{"role": "user", "content": "Write a humorous limerick about the wonders of GPU computing."}],
    "max_tokens": 64,
    "temperature": 0.7,
    "top_p": 0.9
}

response = requests.post(url, headers=headers, json=data)

if response.status_code == 200:
    result = response.json()
    # Extract the generated text from the response
    completion_text = result["choices"][0]["message"]["content"].strip()
    print("Generated Text:", completion_text)
else:
    print("Request failed with status code:", response.status_code)
    print("Response:", response.text)
```
- **Query the model working with Docker and the model files extracted locally using Jupyter notebook and Gradio chat:**
```
import requests
import gradio as gr
import os

# Function to interact with the model via API
def interact_with_model(prompt):
    url = 'http://0.0.0.0:8000/v1/chat/completions'  # Update the URL to match the correct endpoint
    headers = {
        "accept": "application/json",
        "Content-Type": "application/json",
    }

    # Assuming `MODEL` is an environment variable set appropriately
    model = "/mnt/model/"  # Adjust this based on your specific model path or name

    data = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 64,
        "temperature": 0.7,
        "top_p": 0.9
    }

    response = requests.post(url, headers=headers, json=data)

    if response.status_code == 200:
        result = response.json()
        completion_text = result["choices"][0]["message"]["content"].strip()
        return completion_text
    else:
        return {"error": f"Request failed with status code {response.status_code}"}

# Example Gradio interface
iface = gr.Interface(
    fn=interact_with_model,
    inputs=gr.Textbox(lines=2, placeholder="Write a humorous limerick about the wonders of GPU computing."),
    outputs=gr.Textbox(type="text", placeholder="Response..."),
    title="Model Interface",  # Set your desired title here
    description="Interact with the model deployed locally via Gradio.",
    live=True
)

# Launch the Gradio interface
iface.launch(share=True)
```
**Firewall commands to open port 8888 for Jupyter:**
```
sudo firewall-cmd --zone=public --permanent --add-port 8888/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-all
```
