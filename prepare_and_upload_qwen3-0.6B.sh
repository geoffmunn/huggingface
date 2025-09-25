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

MODEL_NAME="Qwen3-0.6B"
HF_REPO="geoffmunn/${MODEL_NAME}"
HF_REPO_URL="https://huggingface.co/${HF_REPO}"

BASE_REPO="Qwen/Qwen3-0.6B"
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
  - chat
  - edge-ai
  - tiny-model
base_model: BASE_REPO
author: geoffmunn
pipeline_tag: text-generation
language:
  - en
  - zh
---

# MODEL_NAME-GGUF

This is a **GGUF-quantized version** of the **[BASE_REPO](https://huggingface.co/BASE_REPO)** language model — a compact **600-million-parameter** LLM designed for **ultra-fast inference on low-resource devices**.

Converted for use with `llama.cpp`, [LM Studio](https://lmstudio.ai), [OpenWebUI](https://openwebui.com), and [GPT4All](https://gpt4all.io), enabling private AI anywhere — even offline.

> ⚠️ **Note**: This is a *very small* model. It will not match larger models (e.g., 4B+) in reasoning, coding, or factual accuracy. However, it shines in **speed, portability, and efficiency**.

## Available Quantizations (from INPUT_PRECISION)

These variants were built from a **INPUT_PRECISION** base model to ensure consistency across quant levels.

| Level     | Quality       | Speed     | Size      | Recommendation |
|----------|--------------|----------|-----------|----------------|
| Q2_K     | Minimal      | ⚡ Fastest | 347 MB   | Use only on severely constrained systems (e.g., Raspberry Pi). Severely degraded output. |
| Q3_K_S   | Low          | ⚡ Fast    | 390 MB   | Barely usable; slight improvement over Q2_K. Avoid unless space-limited. |
| Q3_K_M   | Low-Medium   | ⚡ Fast    | 414 MB   | Usable for simple prompts on older CPUs. Acceptable for basic chat. |
| Q4_K_S   | Medium       | 🚀 Fast    | 471 MB   | Good balance for low-end devices. Recommended for embedded or mobile use. |
| Q4_K_M   | ✅ Practical  | 🚀 Fast    | 484 MB   | Best overall choice for most users. Solid performance on weak hardware. |
| Q5_K_S   | High         | 🐢 Medium  | 544 MB   | Slight quality gain; good for testing or when extra fidelity matters. |
| Q5_K_M   | 🔺 Max Reasoning | 🐢 Medium | 551 MB | Best quality available for this model. Use if you need slightly better logic or coherence. |
| Q6_K     | Near-FP16    | 🐌 Slow    | 623 MB   | Diminishing returns. Only use if full consistency is critical and RAM allows. |
| Q8_0     | Lossless*    | 🐌 Slow    | 805 MB   | Maximum fidelity, but gains are minor due to model size. Ideal for archival or benchmarking. |

> 💡 **Recommendations by Use Case**
>
> - 📱 **Mobile/Embedded/IoT Devices**: `Q4_K_S` or `Q4_K_M`
> - 💻 **Old Laptops or Low-RAM Systems (<4GB RAM)**: `Q4_K_M`
> - 🖥️ **Standard PCs/Macs (General Use)**: `Q5_K_M` (best quality)
> - ⚙️ **Ultra-Fast Inference Needs**: `Q3_K_M` or `Q4_K_S` (lowest latency)
> - 🧩 **Prompt Prototyping or UI Testing**: Any variant – great for fast iteration
> - 🛠️ **Development & Benchmarking**: Test from `Q4_K_M` up to `Q8_0` to assess trade-offs
> - ❌ **Avoid For**: Complex reasoning, math, code generation, fact-heavy tasks

## Why Use a 0.6B Model?

While limited in capability compared to larger models, **Qwen3-0.6B** excels at:
- Running **instantly** on CPUs without GPU
- Fitting into **<2GB RAM**, even when quantized
- Enabling **offline AI on microcontrollers, phones, or edge devices**
- Serving as a **fast baseline** for lightweight NLP tasks (intent detection, short responses)

It’s ideal for:
- Chatbots with simple flows
- On-device assistants
- Educational demos
- Rapid prototyping

## Usage

Load this model using:
- [OpenWebUI](https://openwebui.com) – self-hosted, extensible interface
- [LM Studio](https://lmstudio.ai) – local LLM desktop app
- [GPT4All](https://gpt4all.io) – private, local AI chatbot
- Or directly via \`llama.cpp\`

Each model includes its own `README.md` and `MODELFILE` for optimal configuration.

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
RECOMMENDATIONS["Q2_K"]="Minimal quality; only for extreme memory constraints. Output may be incoherent."
RECOMMENDATIONS["Q3_K_S"]="Low quality; barely usable. Suitable only for keyword extraction or token streaming tests."
RECOMMENDATIONS["Q3_K_M"]="Acceptable for basic interaction on legacy hardware. Simple chat OK."
RECOMMENDATIONS["Q4_K_S"]="Solid mid-low tier. Great for quick replies on mobile or embedded platforms."
RECOMMENDATIONS["Q4_K_M"]="Best speed/quality trade-off. Recommended for general-purpose usage."
RECOMMENDATIONS["Q5_K_S"]="High-quality for a 0.6B model. Slightly slower, better coherence."
RECOMMENDATIONS["Q5_K_M"]="Highest practical quality. Choose this if you want the best possible output."
RECOMMENDATIONS["Q6_K"]="Near-lossless. Minor gains over Q5_K_M. Use only if memory isn't tight."
RECOMMENDATIONS["Q8_0"]="Full precision (lossless). Ideal for reproducibility, research, or archiving."

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
        "Q2_K")   ram="~0.6 GB"; speed="⚡ Fast"; qual="Minimal" ;;
        "Q3_K_S") ram="~0.7 GB"; speed="⚡ Fast"; qual="Low" ;;
        "Q3_K_M") ram="~0.8 GB"; speed="⚡ Fast"; qual="Low-Medium" ;;
        "Q4_K_S") ram="~0.9 GB"; speed="🚀 Fast"; qual="Medium" ;;
        "Q4_K_M") ram="~1.0 GB"; speed="🚀 Fast"; qual="Practical" ;;
        "Q5_K_S") ram="~1.1 GB"; speed="🐢 Medium"; qual="High" ;;
        "Q5_K_M") ram="~1.2 GB"; speed="🐢 Medium"; qual="Max Reasoning" ;;
        "Q6_K")   ram="~1.4 GB"; speed="🐌 Slow"; qual="Near-FP16" ;;
        "Q8_0")   ram="~1.7 GB"; speed="🐌 Slow"; qual="Lossless*" ;;
        *)        ram="~? GB"; speed="❓ Unknown"; qual="Unknown" ;;
    esac

    # Dynamic CLI example based on model capability
    if [[ "$QTYPE" =~ ^(Q5_K_M|Q6_K|Q8_0)$ ]]; then
        PROMPT="Explain what gravity is in one sentence suitable for a child."
        TEMP=0.6
        MODE="general"
    elif [[ "$QTYPE" =~ ^(Q4_K_M|Q5_K_S)$ ]]; then
        PROMPT="Write a short joke about cats."
        TEMP=0.8  # Higher temp for creativity
        MODE="creative"
    else
        PROMPT="Repeat the word 'hello' five times separated by commas."
        TEMP=0.1  # Deterministic for low-quants
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
  - chat
  - edge-ai
  - tiny-model
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

Recommended defaults:

| Parameter | Value |
|---------|-------|
| Temperature | 0.6 |
| Top-P | 0.95 |
| Top-K | 20 |
| Min-P | 0.0 |
| Repeat Penalty | 1.1 |

Stop sequences: \`<|im_end|>\`, \`<|im_start|>\`

> ⚠️ Due to model size, avoid temperatures above 0.9 — outputs become highly unpredictable.

## 💡 Usage Tips

> This model is best suited for lightweight tasks:
>
> ### ✅ Ideal Uses
> - Quick replies and canned responses
> - Intent classification (e.g., “Is this user asking for help?”)
> - UI prototyping and local AI testing
> - Embedded/NPU deployment
>
> ### ❌ Limitations
> - No complex reasoning or multi-step logic
> - Poor math and code generation
> - Limited world knowledge
> - May repeat or hallucinate frequently at higher temps
>
> ---
>
> 🔄 **Fast Iteration Friendly**  
> Perfect for developers building prompt templates or testing UI integrations.
>
> 🔋 **Runs on Almost Anything**  
> Even Raspberry Pi Zero W can run Q2_K with swap enabled.
>
> 📦 **Tiny Footprint**  
> Fits easily on USB drives, microSD cards, or IoT devices.

## 🖥️ CLI Example Using Ollama or TGI Server

Here’s how you can query this model via API using \`curl\` and \`jq\`. Replace the endpoint with your local server (e.g., Ollama, Text Generation Inference).

\`\`\`bash
curl http://localhost:11434/api/generate -s -N -d '{
  "model": "hf.co/geoffmunn/Qwen3-0.6B:${QTYPE}",
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
- The prompt is meaningful yet achievable for a tiny model.
- Temperature tuned appropriately: lower for deterministic output (\`0.1\`), higher for jokes (\`0.8\`).
- Uses \`jq\` to extract clean response.

> 💬 Tip: For ultra-low-latency use, try \`Q3_K_M\` or \`Q4_K_S\` on older laptops.

## Verification

Check integrity:

\`\`\`bash
sha256sum -c ../SHA256SUMS.txt
\`\`\`

## Usage

Compatible with:
- [LM Studio](https://lmstudio.ai) – local AI model runner
- [OpenWebUI](https://openwebui.com) – self-hosted AI interface
- [GPT4All](https://gpt4all.io) – private, offline AI chatbot
- Directly via \`llama.cpp\`

## License

Apache 2.0 – see base model for full terms.
EOF

    echo "✅ Generated per-model card: $DIRNAME/README.md"
done

# -------------------------------
# STEP 5: Generate Shared MODELFILE
# -------------------------------

cat > MODELFILE << 'EOF'
# MODELFILE for Qwen3-0.6B-GGUF
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

# Default sampling
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