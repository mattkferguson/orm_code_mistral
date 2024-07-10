# **ORM_stack_a10_gpu_local_Mistral_versions**

# **ORM Stack to deploy an A10 shape, one GPU and local vLLM Mistral**

## Installation
- **you can use Resource Manager from OCI console to upload the code from here**

## NOTE
- **the code deploys an A10 shape with one GPU Shape**
- **it requires a VCN and a subnet where the VM will be deployed**
- **it uses Oracle Linux image:**
- **for the image it will choose:**
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
  **- it will add a freeform TAG : "GPU_TAG"= "A10-1"**
  **- the boot vol is 250 GB**
  **- the cloudinit will do all the steps needed to download and to start a vLLM Mistral model**
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
- **Few commands to check the progress and GPU resource utilization:**
```
monitor cloud init completion: tail -f /var/log/cloud-init-output.log
monitor single GPU: nvidia-smi dmon -s mu -c 100
```
**If needed:**
- **Start the model with this [Mistral-7B-v0.1 or Mistral-7B-Instruct-v0.2]:**
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
- **Test the model from CLI:**
```
(mistral)$ curl -X 'POST' 'http://0.0.0.0:8000/v1/chat/completions' -H 'accept: application/json' -H 'Content-Type: application/json' -d '{
>     "model": "/home/opc/models/'"$MODEL"'",
>     "messages": [{"role":"user", "content":"Write a small poem."}],
>     "max_tokens": 64
> }'

{"id":"cmpl-0f39a37ad2bf42269f2372d994625ba1","object":"chat.completion","created":1719988309,"model":"/home/opc/models/Mistral-7B-v0.1","choices":[{"index":0,"message":{"role":"assistant","content":" Write aWE header\n\n Struct argued貿5 argued timing argued damals rings ringsnię arguedş система書 Gul郡\n\n called Struct argued貿5 argued timing argued damals rings ringsnię arguedş система書 Gul郡\n\n authorization argued timing timing gradle damals sulle gradle timing sulle timing damals\n authorization argued","tool_calls":[]},"logprobs":null,"finish_reason":"length","stop_reason":null}],"usage":{"prompt_tokens":13,"total_tokens":77,"completion_tokens":64}}(mistral) [opc@a10-gpu ~]$
```
- **Or query with Jupyter notebook:**
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
- **Gradio integration with chatbot feaure to query the model:**
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
- **Start the model with Docker:**
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
- **Query the model working with Docker from CLI:**
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
- **Query the model working with Docker from Jupyter notebook:**
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
**Please keep in mind to allow firewall traffic at least for port 8888 used for Jupyter:**
```
sudo firewall-cmd --zone=public --permanent --add-port 8888/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-all
```
**Please execute the following command to complete the autentication details for oci cli:**
```
oci setup config
```

