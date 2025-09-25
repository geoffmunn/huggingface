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

MODEL_NAME="Qwen3-4B"
HF_REPO="geoffmunn/${MODEL_NAME}"
HF_REPO_URL="https://huggingface.co/${HF_REPO}"

BASE_REPO="Qwen/Qwen3-4B"
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

This is a **GGUF-quantized version** of the **[BASE_REPO](https://huggingface.co/BASE_REPO)** language model — a powerful **4-billion-parameter** LLM from Alibaba's Qwen series, designed for **strong reasoning, agentic workflows, and multilingual fluency** on consumer-grade hardware.

Converted for use with `llama.cpp`, [LM Studio](https://lmstudio.ai), [OpenWebUI](https://openwebui.com), [GPT4All](https://gpt4all.io), and more.

> 💡 **Key Features of Qwen3-4B**:
> - 🤔 Supports **thinking mode** (`<think>...<think>`) for math, coding, logic.
> - 🔁 Dynamically switch via `/think` and `/no_think` in conversation.
> - 🧰 Agent-ready: integrates seamlessly with tools via Qwen-Agent or MCP.
> - 🌍 Fluent in 100+ languages including Chinese, English, Arabic, Japanese, Spanish.
> - ⚙️ Balances performance and size — runs well on laptops with 16GB RAM.

## Available Quantizations (from INPUT_PRECISION)

These variants were built from a **INPUT_PRECISION** base model to ensure consistency across quant levels.

| Level     | Quality       | Speed     | Size      | Recommendation |
|----------|--------------|----------|-----------|----------------|
| Q2_K     | Very Low     | ⚡ Fastest | 1.9 GB   | Only on weak devices; avoid for reasoning. |
| Q3_K_S   | Low          | ⚡ Fast    | 2.2 GB   | Minimal viability; basic completion only. |
| Q3_K_M   | Low-Medium   | ⚡ Fast    | 2.4 GB   | Acceptable for simple chat on older systems. |
| Q4_K_S   | Medium       | 🚀 Fast    | 2.7 GB   | Good balance for low-end laptops or Mac Minis. |
| Q4_K_M   | ✅ Balanced   | 🚀 Fast    | 2.9 GB   | Best overall for general use on average hardware. |
| Q5_K_S   | High         | 🐢 Medium  | 3.3 GB   | Better reasoning; slightly faster than Q5_K_M. |
| Q5_K_M   | ✅✅ High     | 🐢 Medium  | 3.4 GB   | Top pick for coding, logic, and deeper interactions. |
| Q6_K     | 🔥 Near-FP16 | 🐌 Slow    | 3.9 GB   | Excellent fidelity; great for RAG and retrieval. |
| Q8_0     | 🏆 Lossless*  | 🐌 Slow    | 5.1 GB   | Maximum accuracy; recommended when precision matters most. |

> 💡 **Recommendations by Use Case**
>
> - 💻 **Low-end CPU / Old Laptop**: `Q4_K_M`
> - 🖥️ **Standard Laptop (Intel i5/M1 Mac)**: `Q5_K_M` (optimal balance)
> - 🧠 **Reasoning, Coding, Math**: `Q5_K_M` or `Q6_K`
> - 🔍 **RAG, Retrieval, Precision Tasks**: `Q6_K` or `Q8_0`
> - 📦 **Storage-Constrained Devices**: `Q4_K_S` or `Q4_K_M`
> - 🛠️ **Development & Testing**: Test from `Q4_K_M` up to `Q8_0` for robustness.

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
RECOMMENDATIONS["Q2_K"]="Only on very weak hardware; poor reasoning. Avoid if possible."
RECOMMENDATIONS["Q3_K_S"]="Minimal viable for simple tasks. Avoid for reasoning."
RECOMMENDATIONS["Q3_K_M"]="Acceptable for basic chat on older CPUs."
RECOMMENDATIONS["Q4_K_S"]="Good for low-end devices; decent performance."
RECOMMENDATIONS["Q4_K_M"]="Best speed/quality balance for most users. Ideal for laptops & general use."
RECOMMENDATIONS["Q5_K_S"]="Great for reasoning; slightly faster than Q5_K_M."
RECOMMENDATIONS["Q5_K_M"]="Top choice for reasoning & coding. Recommended for desktops & strong laptops."
RECOMMENDATIONS["Q6_K"]="Excellent fidelity; ideal for RAG, complex logic. Use if RAM allows."
RECOMMENDATIONS["Q8_0"]="Highest quality without FP16; perfect for accuracy-critical tasks."

for QTYPE in "${QUANTS[@]}"; do
    MODEL_FILE="${MODEL_NAME}-${INPUT_PRECISION}:${QTYPE}.gguf"
    
    if [ ! -f "$MODEL_FILE" ]; then
        echo "⚠️ Skipping card for $MODEL_FILE — not found"
        continue
    fi

    DIRNAME="${MODEL_NAME}-${QTYPE}"
    mkdir -p "$DIRNAME"

    FILE_SIZE=$(ls -lh "$MODEL_FILE" | awk '{print $5}')

    # Estimate RAM and performance
    case "$QTYPE" in
        "Q2_K")   ram="~2.1 GB"; speed="⚡ Fast"; qual="Very Low" ;;
        "Q3_K_S") ram="~2.4 GB"; speed="⚡ Fast"; qual="Low" ;;
        "Q3_K_M") ram="~2.6 GB"; speed="⚡ Fast"; qual="Low-Medium" ;;
        "Q4_K_S") ram="~2.9 GB"; speed="🚀 Fast"; qual="Medium" ;;
        "Q4_K_M") ram="~3.1 GB"; speed="🚀 Fast"; qual="Balanced" ;;
        "Q5_K_S") ram="~3.5 GB"; speed="🐢 Medium"; qual="High" ;;
        "Q5_K_M") ram="~3.6 GB"; speed="🐢 Medium"; qual="High+" ;;
        "Q6_K")   ram="~4.2 GB"; speed="🐌 Slow"; qual="Near-FP16" ;;
        "Q8_0")   ram="~5.4 GB"; speed="🐌 Slow"; qual="Lossless*" ;;
        *)        ram="~? GB"; speed="❓ Unknown"; qual="Unknown" ;;
    esac

    # Dynamic CLI example based on model capability
    if [[ "$QTYPE" =~ ^(Q5_K_M|Q6_K|Q8_0)$ ]]; then
        PROMPT="Explain how quantum entanglement works in simple terms, suitable for a high school student."
        TEMP=0.5
        MODE="thinking"
    elif [[ "$QTYPE" =~ ^(Q4_K_M|Q5_K_S)$ ]]; then
        PROMPT="Write a short haiku about a mountain at sunrise."
        TEMP=0.8
        MODE="creative"
    else
        PROMPT="Define what a computer is in one sentence."
        TEMP=0.3
        MODE="basic"
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
  "model": "hf.co/geoffmunn/Qwen3-4B:${QTYPE}",
  "prompt": "Respond exactly as follows: ${PROMPT}",
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
- Temperature is tuned appropriately: lower for factual responses (\`0.5\`), higher for creative ones (\`0.8\`).
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
# MODELFILE for Qwen3-4B-GGUF
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