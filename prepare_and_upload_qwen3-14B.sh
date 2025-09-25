#!/bin/bash

# ===========================================
# GGUF Quantization, Metadata & Auto-Upload
# With Per-Model Cards + MODELFILE + HF Upload
# Geoff Munn / 2025
# ===========================================

set -e  # Exit on any error

# -------------------------------
# CONFIGURE THESE VALUES
# -------------------------------

INPUT_PRECISION="f16"
QUANTS=("Q2_K" "Q3_K_S" "Q3_K_M" "Q4_K_S" "Q4_K_M" "Q5_K_S" "Q5_K_M" "Q6_K" "Q8_0")

MODEL_NAME="Qwen3-8B"
HF_REPO="geoffmunn/${MODEL_NAME}"
HF_REPO_URL="https://huggingface.co/${HF_REPO}"

BASE_REPO="Qwen/Qwen3-8B"
LICENSE="apache-2.0"
OUTPUT_DIR="./dist"

QUANTIZE_BIN="./build/bin/llama-quantize"
COMMIT_MSG="Add Q2–Q8_0 quantized models with per-model cards, MODELFILE, CLI examples, and auto-upload"

# -------------------------------
# DERIVE INPUT & OUTPUT NAMES
# -------------------------------

INPUT_MODEL="${PWD}/${MODEL_NAME}-${INPUT_PRECISION}.gguf"

if [ ! -f "$INPUT_MODEL" ]; then
    echo "❌ Error: Input model '$INPUT_MODEL' not found!"
    if [ -f "../$INPUT_MODEL" ]; then
        echo "✅ Found ../$INPUT_MODEL — using that."
        INPUT_MODEL="../$INPUT_MODEL"
    else
        echo "❌ Also checked ../$INPUT_MODEL — not found."
        exit 1
    fi
fi

mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

echo "✅ Starting GGUF preparation..."
echo "   Input: $INPUT_MODEL"
echo "   Output dir: $(pwd)"
echo "   Source precision: $INPUT_PRECISION"
echo "   Target quants: ${QUANTS[*]}"

# -------------------------------
# STEP 1: Quantize Models
# -------------------------------

for QTYPE in "${QUANTS[@]}"; do
    OUTPUT_FILE="${MODEL_NAME}-${INPUT_PRECISION}:${QTYPE}.gguf"
    
    if [ -f "$OUTPUT_FILE" ]; then
        echo "💡 $OUTPUT_FILE already exists, skipping..."
        continue
    fi

    echo "📦 Quantizing ${INPUT_PRECISION} → $QTYPE → $OUTPUT_FILE"
    "../$QUANTIZE_BIN" "$INPUT_MODEL" "$OUTPUT_FILE" "$QTYPE"

    if [ $? -ne 0 ]; then
        echo "   ❌ Failed to quantize to $QTYPE"
        exit 1
    fi

    # Validate output is a real GGUF file
    if [ ! -s "$OUTPUT_FILE" ] || ! head -c 4 "$OUTPUT_FILE" | grep -q "GGUF"; then
        echo "💥 ERROR: $OUTPUT_FILE is not a valid GGUF file (invalid magic or empty)"
        exit 1
    fi
    echo "   ✅ Success: $OUTPUT_FILE created and validated"
done

echo

# -------------------------------
# STEP 2: Generate SHA256SUMS.txt
# -------------------------------

echo "🔐 Generating SHA256SUMS.txt..."
sha256sum *.gguf > SHA256SUMS.txt
echo "✅ SHA256 checksums:"
cat SHA256SUMS.txt
echo

# -------------------------------
# STEP 3: Generate Main README.md (Hub Index)
# -------------------------------

cat > README.md << 'EOF'
---
license: apache-2.0
tags:
  - gguf
  - qwen
  - llama.cpp
  - quantized
  - text-generation
  - reasoning
  - agent
  - chat
  - multilingual
base_model: BASE_REPO
author: geoffmunn
pipeline_tag: text-generation
language:
  - en
  - zh
  - es
  - fr
  - de
  - ru
  - ar
  - ja
  - ko
  - hi
---

# MODEL_NAME-GGUF

This is a **GGUF-quantized version** of the **[BASE_REPO](https://huggingface.co/BASE_REPO)** language model — an **8-billion-parameter** LLM from Alibaba's Qwen series, designed for **advanced reasoning, agentic behavior, and multilingual tasks**.

Converted for use with `llama.cpp` and compatible tools like OpenWebUI, LM Studio, GPT4All, and more.

> 💡 **Key Features of Qwen3-8B**:
> - 🤔 **Thinking Mode**: Use `enable_thinking=True` or `/think` for step-by-step logic, math, and code.
> - ⚡ **Non-Thinking Mode**: Use `/no_think` for fast, lightweight dialogue.
> - 🧰 **Agent Capable**: Integrates with tools via MCP, APIs, and plugins.
> - 🌍 **Multilingual Support**: Fluent in 100+ languages including Chinese, English, Spanish, Arabic, Japanese, etc.

## Available Quantizations (from INPUT_PRECISION)

These variants were built from a **INPUT_PRECISION** base model to ensure consistency across quant levels.

| Level     | Quality       | Speed     | Size      | Recommendation |
|----------|--------------|----------|-----------|----------------|
| Q2_K     | Very Low     | ⚡ Fastest | 3.28 GB   | Only on severely memory-constrained systems (<6GB RAM). Avoid for reasoning. |
| Q3_K_S   | Low          | ⚡ Fast    | 3.77 GB   | Minimal viability; basic completion only. Not recommended. |
| Q3_K_M   | Low-Medium   | ⚡ Fast    | 4.12 GB   | Acceptable for simple chat on older systems. No complex logic. |
| Q4_K_S   | Medium       | 🚀 Fast    | 4.8 GB   | Good balance for low-end laptops or embedded platforms. |
| Q4_K_M   | ✅ Balanced   | 🚀 Fast    | 5.85 GB   | Best overall for general use on average hardware. Great speed/quality trade-off. |
| Q5_K_S   | High         | 🐢 Medium  | 5.72 GB   | Better reasoning; slightly faster than Q5_K_M. Ideal for coding. |
| Q5_K_M   | ✅✅ High     | 🐢 Medium  | 5.85 GB   | Top pick for deep interactions, logic, and tool use. Recommended for desktops. |
| Q6_K     | 🔥 Near-FP16 | 🐌 Slow    | 6.73 GB   | Excellent fidelity; ideal for RAG, retrieval, and accuracy-critical tasks. |
| Q8_0     | 🏆 Lossless*  | 🐌 Slow    | 8.71 GB   | Maximum accuracy; best for research, benchmarking, or archival. |

> 💡 **Recommendations by Use Case**
>
> - 💻 **Low-end CPU / Old Laptop**: `Q4_K_M` (best balance under pressure)
> - 🖥️ **Standard/Mid-tier Laptop (i5/i7/M1/M2)**: `Q5_K_M` (optimal quality)
> - 🧠 **Reasoning, Coding, Math**: `Q5_K_M` or `Q6_K` (use thinking mode!)
> - 🤖 **Agent & Tool Integration**: `Q5_K_M` — handles JSON, function calls well
> - 🔍 **RAG, Retrieval, Precision Tasks**: `Q6_K` or `Q8_0`
> - 📦 **Storage-Constrained Devices**: `Q4_K_S` or `Q4_K_M`
> - 🛠️ **Development & Testing**: Test from `Q4_K_M` up to `Q8_0` to assess trade-offs

## Usage

Load this model using:
- [OpenWebUI](https://openwebui.com) – self-hosted AI interface with RAG & tools
- [LM Studio](https://lmstudio.ai) – desktop app with GPU support and chat templates
- [GPT4All](https://gpt4all.io) – private, local AI chatbot (offline-first)
- Or directly via \`llama.cpp\`

Each quantized model includes its own `README.md` and shares a common `MODELFILE` for optimal configuration.

## Author

👤 Geoff Munn (@geoffmunn)  
🔗 [Hugging Face Profile](https://huggingface.co/geoffmunn)

## Disclaimer

This is a community conversion for local inference. Not affiliated with Alibaba Cloud or the Qwen team.
EOF

sed -i "s|MODEL_NAME|$MODEL_NAME|g" README.md
sed -i "s|BASE_REPO|$BASE_REPO|g" README.md
sed -i "s|LICENSE|$LICENSE|g" README.md
sed -i "s|INPUT_PRECISION|$INPUT_PRECISION|g" README.md

echo "✅ Main README.md (hub index) generated!"

# -------------------------------
# STEP 4: Generate Per-Model README Cards
# -------------------------------

declare -A RECOMMENDATIONS
RECOMMENDATIONS["Q2_K"]="Only on very weak hardware; poor reasoning. Avoid if possible. Not suitable for thinking mode."
RECOMMENDATIONS["Q3_K_S"]="Minimal viable for simple tasks. Avoid for reasoning or multilingual use."
RECOMMENDATIONS["Q3_K_M"]="Acceptable for basic chat on older CPUs. Do not expect coherent logic."
RECOMMENDATIONS["Q4_K_S"]="Good for low-end devices; decent performance. Suitable for mobile/embedded."
RECOMMENDATIONS["Q4_K_M"]="Best speed/quality balance for most users. Ideal for laptops & general use."
RECOMMENDATIONS["Q5_K_S"]="Great for reasoning; slightly faster than Q5_K_M. Recommended for coding."
RECOMMENDATIONS["Q5_K_M"]="Top choice for reasoning & coding. Recommended for desktops & strong laptops."
RECOMMENDATIONS["Q6_K"]="Excellent fidelity; ideal for RAG, complex logic. Use if RAM allows."
RECOMMENDATIONS["Q8_0"]="Highest quality without FP16; perfect for accuracy-critical tasks, benchmarks."

for QTYPE in "${QUANTS[@]}"; do
    MODEL_FILE="${MODEL_NAME}-${INPUT_PRECISION}:${QTYPE}.gguf"
    
    if [ ! -f "$MODEL_FILE" ]; then
        echo "⚠️ Skipping card for $MODEL_FILE — not found"
        continue
    fi

    # Create subfolder per model
    DIRNAME="${MODEL_NAME}-${QTYPE}"
    mkdir -p "$DIRNAME"

    FILE_SIZE=$(ls -lh "$MODEL_FILE" | awk '{print $5}')

    # Estimate RAM and performance
    case "$QTYPE" in
        "Q2_K")   ram="~3.0 GB"; speed="⚡ Fast"; qual="Very Low" ;;
        "Q3_K_S") ram="~3.4 GB"; speed="⚡ Fast"; qual="Low" ;;
        "Q3_K_M") ram="~3.6 GB"; speed="⚡ Fast"; qual="Low-Medium" ;;
        "Q4_K_S") ram="~4.1 GB"; speed="🚀 Fast"; qual="Medium" ;;
        "Q4_K_M") ram="~4.3 GB"; speed="🚀 Fast"; qual="Balanced" ;;
        "Q5_K_S") ram="~4.8 GB"; speed="🐢 Medium"; qual="High" ;;
        "Q5_K_M") ram="~4.9 GB"; speed="🐢 Medium"; qual="High+" ;;
        "Q6_K")   ram="~5.5 GB"; speed="🐌 Slow"; qual="Near-FP16" ;;
        "Q8_0")   ram="~7.1 GB"; speed="🐌 Slow"; qual="Lossless*" ;;
        *)        ram="~? GB"; speed="❓ Unknown"; qual="Unknown" ;;
    esac

    # Dynamic CLI example based on model capability
    if [[ "$QTYPE" =~ ^(Q5_K_M|Q6_K|Q8_0)$ ]]; then
        PROMPT="Explain why the sky appears blue during the day but red at sunrise and sunset, using physics principles like Rayleigh scattering."
        TEMP=0.4  # Lower temp for scientific explanation
        MODE="thinking"
    elif [[ "$QTYPE" =~ ^(Q4_K_M|Q5_K_S)$ ]]; then
        PROMPT="Write a short haiku about autumn leaves falling gently in a quiet forest."
        TEMP=0.7  # Higher temp for creativity
        MODE="non-thinking"
    else
        PROMPT="Summarize what a neural network is in one sentence."
        TEMP=0.5
        MODE="general"
    fi

    cat > "$DIRNAME/README.md" << EOF
---
license: apache-2.0
tags:
  - gguf
  - qwen
  - llama.cpp
  - quantized
  - text-generation
  - reasoning
  - agent
  - chat
  - multilingual
base_model: $BASE_REPO
author: geoffmunn
---

# ${MODEL_NAME}-${QTYPE}

Quantized version of [${BASE_REPO}](https://huggingface.co/${BASE_REPO}) at **${QTYPE}** level, derived from **${INPUT_PRECISION}** base weights.

## Model Info

- **Format**: GGUF (for llama.cpp and compatible runtimes)
- **Size**: ${FILE_SIZE}
- **Precision**: ${QTYPE}
- **Base Model**: [${BASE_REPO}](https://huggingface.co/${BASE_REPO})
- **Conversion Tool**: [llama.cpp](https://github.com/ggerganov/llama.cpp)

## Quality & Performance

| Metric | Value |
|-------|-------|
| **Quality** | ${qual} |
| **Speed** | ${speed} |
| **RAM Required** | ${ram} |
| **Recommendation** | ${RECOMMENDATIONS[$QTYPE]} |

## Prompt Template (ChatML)

This model uses the **ChatML** format used by Qwen:

\`\`\`text
<|im_start|>system
You are a helpful assistant.<|im_end|>
<|im_start|>user
{prompt}<|im_end|>
<|im_start|>assistant
\`\`\`

Set this in your app (LM Studio, OpenWebUI, etc.) for best results.

## Generation Parameters

### Thinking Mode (Recommended for Logic)
Use when solving math, coding, or logical problems.

| Parameter | Value |
|---------|-------|
| Temperature | 0.6 |
| Top-P | 0.95 |
| Top-K | 20 |
| Min-P | 0.0 |
| Repeat Penalty | 1.1 |

> ❗ DO NOT use greedy decoding — it causes infinite loops.

Enable via:
- \`enable_thinking=True\` in tokenizer
- Or add \`/think\` in user input during conversation

### Non-Thinking Mode (Fast Dialogue)
For casual chat and quick replies.

| Parameter | Value |
|---------|-------|
| Temperature | 0.7 |
| Top-P | 0.8 |
| Top-K | 20 |
| Min-P | 0.0 |
| Repeat Penalty | 1.1 |

Enable via:
- \`enable_thinking=False\`
- Or add \`/no_think\` in prompt

Stop sequences: \`<|im_end|>\`, \`<|im_start|>\`

## 💡 Usage Tips

> This model supports two operational modes:
>
> ### 🔍 Thinking Mode (Recommended for Logic)
> Activate with \`enable_thinking=True\` or append \`/think\` in prompt.
>
> - Ideal for: math, coding, planning, analysis
> - Use sampling: \`temp=0.6\`, \`top_p=0.95\`, \`top_k=20\`
> - Avoid greedy decoding
>
> ### ⚡ Non-Thinking Mode (Fast Chat)
> Use \`enable_thinking=False\` or \`/no_think\`.
>
> - Best for: casual conversation, quick answers
> - Sampling: \`temp=0.7\`, \`top_p=0.8\`
>
> ---
>
> 🔄 **Switch Dynamically**  
> In multi-turn chats, the last \`/think\` or \`/no_think\` directive takes precedence.
>
> 🔁 **Avoid Repetition**  
> Set \`presence_penalty=1.5\` if stuck in loops.
>
> 📏 **Use Full Context**  
> Allow up to 32,768 output tokens for complex tasks.
>
> 🧰 **Agent Ready**  
> Works with Qwen-Agent, MCP servers, and custom tools.

## 🖥️ CLI Example Using Ollama or TGI Server

Here’s how you can query this model via API using \`curl\` and \`jq\`. Replace the endpoint with your local server (e.g., Ollama, Text Generation Inference).

\`\`\`bash
curl http://localhost:11434/api/generate -s -N -d '{
  "model": "hf.co/geoffmunn/Qwen3-8B:${QTYPE}",
  "prompt": "Repeat the following instruction exactly as given: ${PROMPT}",
  "temperature": ${TEMP},
  "top_p": 0.95,
  "top_k": 20,
  "min_p": 0.0,
  "repeat_penalty": 1.1,
  "stream": false
}' | jq -r '.response'
\`\`\`

🎯 **Why this works well**:
- The prompt is meaningful and demonstrates either **reasoning**, **creativity**, or **clarity** depending on quant level.
- Temperature is tuned appropriately: lower for factual responses (\`0.4\`), higher for creative ones (\`0.7\`).
- Uses \`jq\` to extract clean output.

> 💬 Tip: For interactive streaming, set \`"stream": true\` and process line-by-line.

## Verification

Check integrity:

\`\`\`bash
sha256sum -c ../SHA256SUMS.txt
\`\`\`

## Usage

Compatible with:
- [LM Studio](https://lmstudio.ai) – local AI model runner with GPU acceleration
- [OpenWebUI](https://openwebui.com) – self-hosted AI platform with RAG and tools
- [GPT4All](https://gpt4all.io) – private, offline AI chatbot
- Directly via \`llama.cpp\`

Supports dynamic switching between thinking modes via \`/think\` and \`/no_think\` in multi-turn conversations.

## License

Apache 2.0 – see base model for full terms.
EOF

    echo "✅ Generated per-model card: $DIRNAME/README.md"
done

# -------------------------------
# STEP 5: Generate Shared MODELFILE
# -------------------------------

cat > MODELFILE << 'EOF'
# MODELFILE for Qwen3-8B-GGUF
# Used by LM Studio, OpenWebUI, GPT4All, etc.

context_length: 32768
embedding: false
f16: cpu

# Chat template using ChatML (used by Qwen)
prompt_template: >-
           <|im_start|>system
        You are a helpful assistant.<|im_end|>
           <|im_start|>user
        {prompt}<|im_end|>
           <|im_start|>assistant

# Stop sequences help end generation cleanly
stop: "<|im_end|>"
stop: "<|im_start|>"

# Default sampling (optimized for thinking mode)
temperature: 0.6
top_p: 0.95
top_k: 20
min_p: 0.0
repeat_penalty: 1.1
EOF

sed -i "s|Qwen3-1.7B|$MODEL_NAME|" MODELFILE

echo "✅ Shared MODELFILE generated!"

# -------------------------------
# STEP 6a: Ensure HF Repo Exists
# -------------------------------

echo "🔍 Ensuring Hugging Face repo exists: $HF_REPO"

if ! command -v huggingface-cli &> /dev/null; then
    echo "📦 Installing huggingface_hub..."
    pip install huggingface_hub --quiet
fi

python3 -c "
from huggingface_hub import create_repo
repo_id = '$HF_REPO'
try:
    create_repo(repo_id, repo_type='model', private=False, exist_ok=True)
    print(f'✅ Repository {repo_id} is ready.')
except Exception as e:
    print(f'❌ Failed to create repo: {e}')
    exit(1)
"

# -------------------------------
# STEP 6b: Upload to Hugging Face
# -------------------------------

echo "📤 Final files to upload:"
find . -type f -name "*.gguf" -o -name "README.md" -o -name "MODELFILE" -o -name "SHA256SUMS.txt" | xargs ls -lh

read -p "👉 Continue with upload? [Y/n] " -r
echo

if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "⏭️ Skipped upload. Files ready in $OUTPUT_DIR"
    exit 0
fi

echo "🚀 Uploading all files to $HF_REPO_URL"
hf upload \
  "$HF_REPO" \
  . \
  --repo-type=model \
  --commit-message "$COMMIT_MSG"

echo
echo "🎉 Success! Your model has been uploaded."
echo "🌐 View it at: $HF_REPO_URL"