# ===========================================
# GGUF Quantization, Metadata & Auto-Upload
# For Qwen3 Models - PowerShell Version
# Geoff Munn / 2025
# Compatible: Qwen3-0.6B, 1.7B, 4B, 8B, 14B
# ===========================================

$ErrorActionPreference = "Stop"

# -------------------------------
# CONFIGURE THESE VALUES
# -------------------------------

$INPUT_PRECISION = "f16"
$QUANTS = @("Q2_K", "Q3_K_S", "Q3_K_M", "Q4_K_S", "Q4_K_M", "Q5_K_S", "Q5_K_M", "Q6_K", "Q8_0")

# 🔧 EDIT THIS TO SELECT YOUR MODEL
$MODEL_NAME = "Qwen3-14B"  # Options: Qwen3-0.6B, Qwen3-1.7B, Qwen3-4B, Qwen3-8B, Qwen3-14B
$BASE_REPO = "Qwen/$MODEL_NAME"
$HF_REPO = "geoffmunn/$MODEL_NAME"
$HF_REPO_URL = "https://huggingface.co/$HF_REPO"

$LICENSE = "apache-2.0"
$OUTPUT_DIR = "./dist"
$QUANTIZE_BIN = "./build/bin/llama-quantize.exe"  # Or llama-quantize on WSL/Mac/Linux

$COMMIT_MSG = "Add quantized models with per-model cards, MODELFILE, CLI examples, and auto-upload"

# -------------------------------
# DERIVE INPUT & OUTPUT NAMES
# -------------------------------

$INPUT_MODEL = "$PWD/${MODEL_NAME}-${INPUT_PRECISION}.gguf"

if (-not (Test-Path $INPUT_MODEL)) {
    Write-Host "❌ Error: Input model '$INPUT_MODEL' not found!" -ForegroundColor Red
    $ALT_PATH = "..\$INPUT_MODEL"
    if (Test-Path $ALT_PATH) {
        Write-Host "✅ Found ../$INPUT_MODEL — using that." -ForegroundColor Green
        $INPUT_MODEL = $ALT_PATH
    } else {
        Write-Host "❌ Also checked ../$INPUT_MODEL — not found." -ForegroundColor Red
        exit 1
    }
}

New-Item -ItemType Directory -Path $OUTPUT_DIR -ErrorAction SilentlyContinue | Out-Null
Set-Location $OUTPUT_DIR

Write-Host "✅ Starting GGUF preparation..." -ForegroundColor Green
Write-Host "   Input: $INPUT_MODEL"
Write-Host "   Output dir: $(Get-Location)"
Write-Host "   Source precision: $INPUT_PRECISION"
Write-Host "   Target quants: $($QUANTS -join ', ')"

# -------------------------------
# STEP 1: Quantize Models
# -------------------------------

foreach ($QTYPE in $QUANTS) {
    $OUTPUT_FILE = "${MODEL_NAME}-${INPUT_PRECISION}:${QTYPE}.gguf"
    
    if (Test-Path $OUTPUT_FILE) {
        Write-Host "💡 $OUTPUT_FILE already exists, skipping..." -ForegroundColor Yellow
        continue
    }

    Write-Host "📦 Quantizing ${INPUT_PRECISION} → $QTYPE → $OUTPUT_FILE" -ForegroundColor Cyan
    & "..\$QUANTIZE_BIN" $INPUT_MODEL $OUTPUT_FILE $QTYPE

    if ($LASTEXITCODE -ne 0) {
        Write-Host "   ❌ Failed to quantize to $QTYPE" -ForegroundColor Red
        exit 1
    }

    # Validate GGUF magic
    $MAGIC = Get-Content -Encoding Byte -TotalCount 4 $OUTPUT_FILE -ErrorAction Stop
    $MAGIC_HEX = ([System.BitConverter]::ToString($MAGIC)).Replace("-", "")
    if ($MAGIC_HEX -ne "47475546") {  # "GGUF" in ASCII hex
        Write-Host "💥 ERROR: $OUTPUT_FILE is not a valid GGUF file (invalid magic)" -ForegroundColor Red
        exit 1
    }

    $SIZE = (Get-Item $OUTPUT_FILE).Length
    if ($SIZE -eq 0) {
        Write-Host "💥 ERROR: $OUTPUT_FILE is empty" -ForegroundColor Red
        exit 1
    }

    Write-Host "   ✅ Success: $OUTPUT_FILE created and validated" -ForegroundColor Green
}

Write-Host ""

# -------------------------------
# STEP 2: Generate SHA256SUMS.txt
# -------------------------------

Write-Host "🔐 Generating SHA256SUMS.txt..." -ForegroundColor Cyan

$sha256 = New-Object System.Security.Cryptography.SHA256Managed
$hashes = @()

Get-ChildItem "*.gguf" | ForEach-Object {
    $file = $_.FullName
    $stream = [System.IO.File]::OpenRead($file)
    $hashBytes = $sha256.ComputeHash($stream)
    $hashString = [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()
    $stream.Close()
    $hashes += "$hashString  $($_.Name)"
}

$hashes | Out-File -FilePath "SHA256SUMS.txt" -Encoding UTF8
Write-Host "✅ SHA256 checksums:" -ForegroundColor Green
Get-Content "SHA256SUMS.txt" | ForEach-Object { Write-Host "   $_" }

Write-Host ""

# -------------------------------
# STEP 3: Generate Main README.md (Hub Index)
# -------------------------------

$README_CONTENT = @"
---
license: $LICENSE
tags:
  - gguf
  - qwen
  - llama.cpp
  - quantized
  - text-generation
$(if ($MODEL_NAME -like "*0.6B*") { '  - edge-ai', '  - tiny-model' } else { '  - reasoning', '  - agent', '  - multilingual' })
base_model: $BASE_REPO
author: geoffmunn
pipeline_tag: text-generation
language:
  - en
  - zh
$(if ($MODEL_NAME -notlike "*0.6B*") { '  - es', '  - fr', '  - de', '  - ru', '  - ar', '  - ja', '  - ko', '  - hi' })
---

# $MODEL_NAME-GGUF

This is a **GGUF-quantized version** of the **[$BASE_REPO](https://huggingface.co/$BASE_REPO)** language model — a $(switch($MODEL_NAME){
    "Qwen3-0.6B" { "compact **600-million-parameter** LLM designed for ultra-fast inference on low-resource devices." }
    "Qwen3-1.7B" { "**1.7-billion-parameter** LLM balancing efficiency and capability." }
    "Qwen3-4B" { "**4-billion-parameter** LLM for strong local reasoning and multilingual fluency." }
    "Qwen3-8B" { "**8-billion-parameter** LLM with advanced reasoning, agentic behavior, and tool integration." }
    "Qwen3-14B" { "**14-billion-parameter** LLM with deep reasoning, research-grade accuracy, and autonomous workflows." }
}) Converted for use with \`llama.cpp\`, [LM Studio](https://lmstudio.ai), [OpenWebUI](https://openwebui.com), [GPT4All](https://gpt4all.io), and more.

> 💡 This model supports **thinking mode**: use `/think` or set `enable_thinking=True` for step-by-step logic.

## Available Quantizations (from $INPUT_PRECISION)

| Level     | Quality       | Speed     | Size      | Recommendation |
|----------|--------------|----------|-----------|----------------|
$(Get-QuantTableRows $MODEL_NAME)
> 💡 **Recommendations by Use Case**
>
$(Get-UseCaseTips $MODEL_NAME)

## Usage

Load this model using:
- [OpenWebUI](https://openwebui.com) – self-hosted AI interface with RAG & tools
- [LM Studio](https://lmstudio.ai) – desktop app with GPU support
- [GPT4All](https://gpt4all.io) – private, offline AI chatbot
- Or directly via \`llama.cpp\`

Each quantized model includes its own \`README.md\` and shares a common \`MODELFILE\`.

## Author

👤 Geoff Munn (@geoffmunn)  
🔗 [Hugging Face Profile](https://huggingface.co/geoffmunn)

## Disclaimer

This is a community conversion for local inference. Not affiliated with Alibaba Cloud or the Qwen team.
"@

# Helper functions for dynamic content
function Get-QuantTableRows {
    param([string]$Model)
    $sizes = @{
        "Qwen3-0.6B" = @{ Q2_K="347 MB"; Q3_K_S="390 MB"; Q3_K_M="414 MB"; Q4_K_S="471 MB"; Q4_K_M="484 MB"; Q5_K_S="544 MB"; Q5_K_M="551 MB"; Q6_K="623 MB"; Q8_0="805 MB" }
        "Qwen3-1.7B" = @{ Q2_K="880 MB"; Q3_K_S="1.0 GB"; Q3_K_M="1.07 GB"; Q4_K_S="1.24 GB"; Q4_K_M="1.28 GB"; Q5_K_S="1.44 GB"; Q5_K_M="1.47 GB"; Q6_K="1.67 GB"; Q8_0="2.17 GB" }
        "Qwen3-4B"  = @{ Q2_K="1.9 GB"; Q3_K_S="2.2 GB"; Q3_K_M="2.4 GB"; Q4_K_S="2.7 GB"; Q4_K_M="2.9 GB"; Q5_K_S="3.3 GB"; Q5_K_M="3.4 GB"; Q6_K="3.9 GB"; Q8_0="5.1 GB" }
        "Qwen3-8B"  = @{ Q2_K="2.7 GB"; Q3_K_S="3.1 GB"; Q3_K_M="3.3 GB"; Q4_K_S="3.8 GB"; Q4_K_M="4.0 GB"; Q5_K_S="4.5 GB"; Q5_K_M="4.6 GB"; Q6_K="5.2 GB"; Q8_0="6.8 GB" }
        "Qwen3-14B" = @{ Q2_K="8.5 GB"; Q3_K_S="9.7 GB"; Q3_K_M="10.2 GB"; Q4_K_S="11.8 GB"; Q4_K_M="12.3 GB"; Q5_K_S="13.8 GB"; Q5_K_M="14.1 GB"; Q6_K="16.0 GB"; Q8_0="21.0 GB" }
    }

    $recs = @{
        Q2_K     = "Only on severely memory-constrained systems."
        Q3_K_S   = "Minimal viability; avoid unless space-limited."
        Q3_K_M   = "Acceptable for basic interaction."
        Q4_K_S   = "Good balance for mobile/embedded platforms."
        Q4_K_M   = "Best overall choice for most users."
        Q5_K_S   = "Slight quality gain; good for testing."
        Q5_K_M   = "Best quality available. Recommended."
        Q6_K     = "Diminishing returns. Only if RAM allows."
        Q8_0     = "Maximum fidelity. Ideal for archival."
    }

    foreach ($q in $QUANTS) {
        $size = $sizes[$Model][$q]
        $qual = switch ($q) {
            "Q2_K"   { "Minimal" }
            "Q3_*"   { "Low" }
            "Q4_*"   { "Medium" }
            "Q5_*"   { "High" }
            "Q6_K"   { "Near-FP16" }
            "Q8_0"   { "Lossless*" }
            default { "?" }
        } -replace "Q3_\*", "Low-Medium" -replace "Q4_\*", "Practical" -replace "Q5_\*", "Max Reasoning"

        $speed = if ($q -match "^Q[234]") { "⚡ Fast" } elseif ($q -match "^Q5") { "🐢 Medium" } else { "🐌 Slow" }

        "| $q | $qual | $speed | $size | $($recs[$q]) |"
    }
}

function Get-UseCaseTips {
    param([string]$Model)
    $tips = switch ($Model) {
        "Qwen3-0.6B" {
            "- 📱 **Mobile/Embedded/IoT Devices**: `Q4_K_S` or `Q4_K_M`"
            "- 💻 **Old Laptops (<4GB RAM)**: `Q4_K_M`"
            "- ⚙️ **Ultra-Fast Inference Needs**: `Q3_K_M` or `Q4_K_S`"
            "- ❌ **Avoid For**: Complex reasoning, math, code"
        }
        default {
            "- 💻 **Standard Laptop (i5/M1 Mac)**: `Q5_K_M` (optimal quality)"
            "- 🧠 **Reasoning, Coding, Math**: `Q5_K_M` or `Q6_K`"
            "- 🔍 **RAG, Retrieval, Precision Tasks**: `Q6_K` or `Q8_0`"
            "- 🤖 **Agent & Tool Integration**: `Q5_K_M`"
            "- 🛠️ **Development & Testing**: Test from `Q4_K_M` up to `Q8_0`"
        }
    }
    ($tips | ForEach-Object { "  > - $_" }) -join "`n"
}

$README_CONTENT | Out-File -FilePath "README.md" -Encoding UTF8
Write-Host "✅ Main README.md (hub index) generated!" -ForegroundColor Green


# -------------------------------
# STEP 4: Generate Per-Model README Cards
# -------------------------------

$RECOMMENDATIONS = @{
    "Q2_K"   = "Minimal quality; only for extreme memory constraints."
    "Q3_K_S" = "Low quality; barely usable. Avoid unless space-limited."
    "Q3_K_M" = "Acceptable for basic interaction on legacy hardware."
    "Q4_K_S" = "Solid mid-low tier. Great for quick replies on mobile or embedded."
    "Q4_K_M" = "Best speed/quality trade-off. Recommended for general-purpose usage."
    "Q5_K_S" = "High-quality for this model. Slight improvement over Q4_K_M."
    "Q5_K_M" = "Highest practical quality. Choose this if you need better logic."
    "Q6_K"   = "Near-lossless. Minor gains. Use only if RAM allows."
    "Q8_0"   = "Maximum fidelity, but gains are minor. Ideal for benchmarking."
}

$RAM_ESTIMATES = @{
    "Qwen3-0.6B" = @{ Q2_K="~0.6 GB"; Q3_K_S="~0.7 GB"; Q3_K_M="~0.8 GB"; Q4_K_S="~0.9 GB"; Q4_K_M="~1.0 GB"; Q5_K_S="~1.1 GB"; Q5_K_M="~1.2 GB"; Q6_K="~1.4 GB"; Q8_0="~1.7 GB" }
    "Qwen3-1.7B" = @{ Q2_K="~0.9 GB"; Q3_K_S="~1.1 GB"; Q3_K_M="~1.3 GB"; Q4_K_S="~1.4 GB"; Q4_K_M="~1.5 GB"; Q5_K_S="~1.6 GB"; Q5_K_M="~1.7 GB"; Q6_K="~2.0 GB"; Q8_0="~2.3 GB" }
    "Qwen3-4B"  = @{ Q2_K="~2.1 GB"; Q3_K_S="~2.4 GB"; Q3_K_M="~2.6 GB"; Q4_K_S="~2.9 GB"; Q4_K_M="~3.1 GB"; Q5_K_S="~3.5 GB"; Q5_K_M="~3.6 GB"; Q6_K="~4.2 GB"; Q8_0="~5.4 GB" }
    "Qwen3-8B"  = @{ Q2_K="~3.0 GB"; Q3_K_S="~3.4 GB"; Q3_K_M="~3.6 GB"; Q4_K_S="~4.1 GB"; Q4_K_M="~4.3 GB"; Q5_K_S="~4.8 GB"; Q5_K_M="~4.9 GB"; Q6_K="~5.5 GB"; Q8_0="~7.1 GB" }
    "Qwen3-14B" = @{ Q2_K="~9.0 GB"; Q3_K_S="~10.2 GB"; Q3_K_M="~10.7 GB"; Q4_K_S="~12.3 GB"; Q4_K_M="~12.8 GB"; Q5_K_S="~14.3 GB"; Q5_K_M="~14.6 GB"; Q6_K="~16.5 GB"; Q8_0="~21.5 GB" }
}

foreach ($QTYPE in $QUANTS) {
    $MODEL_FILE = "${MODEL_NAME}-${INPUT_PRECISION}:${QTYPE}.gguf"
    if (-not (Test-Path $MODEL_FILE)) {
        Write-Host "⚠️ Skipping card for $MODEL_FILE — not found" -ForegroundColor Yellow
        continue
    }

    $DIRNAME = "${MODEL_NAME}-${QTYPE}"
    New-Item -ItemType Directory -Path $DIRNAME -ErrorAction SilentlyContinue | Out-Null

    $FILE_SIZE = (Get-Item $MODEL_FILE).Length
    $UNIT = if ($FILE_SIZE -gt 1TB) { "TB"; $VAL = "{0:N2}" -f ($FILE_SIZE / 1TB) }
            elseif ($FILE_SIZE -gt 1GB) { "GB"; $VAL = "{0:N2}" -f ($FILE_SIZE / 1GB) }
            elseif ($FILE_SIZE -gt 1MB) { "MB"; $VAL = "{0:N2}" -f ($FILE_SIZE / 1MB) }
            else { "KB"; $VAL = "{0:N2}" -f ($FILE_SIZE / 1KB) }
    $DISPLAY_SIZE = "$VAL $UNIT"

    $RAM = $RAM_ESTIMATES[$MODEL_NAME][$QTYPE]
    $SPEED = if ($QTYPE -match "^Q[234]") { "⚡ Fast" } elseif ($QTYPE -match "^Q5") { "🐢 Medium" } else { "🐌 Slow" }
    $QUAL = switch ($QTYPE) {
        "Q2_K"   { "Minimal" }
        "Q3_*"   { "Low-Medium" }
        "Q4_*"   { "Practical" }
        "Q5_*"   { "Max Reasoning" }
        "Q6_K"   { "Near-FP16" }
        "Q8_0"   { "Lossless*" }
    }

    # Dynamic prompt based on quant level
    if ($QTYPE -in @("Q5_K_M", "Q6_K", "Q8_0")) {
        $PROMPT = "Explain how photosynthesis converts sunlight into chemical energy in plants."
        $TEMP = 0.5
    } elseif ($QTYPE -in @("Q4_K_M", "Q5_K_S")) {
        $PROMPT = "Write a haiku about autumn leaves falling gently in a quiet forest."
        $TEMP = 0.7
    } else {
        $PROMPT = "Summarize what a neural network is in one sentence."
        $TEMP = 0.3
    }

    $CARD = @"
---
license: apache-2.0
tags:
  - gguf
  - qwen
  - llama.cpp
  - quantized
  - text-generation
  - chat
$(if ($MODEL_NAME -notlike "*0.6B*") { '  - reasoning', '  - agent', '  - multilingual' })
base_model: $BASE_REPO
author: geoffmunn
---

# ${MODEL_NAME}-${QTYPE}

Quantized version of [$BASE_REPO](https://huggingface.co/$BASE_REPO) at **$QTYPE** level, derived from **$INPUT_PRECISION** base weights.

## Model Info

- **Format**: GGUF (for llama.cpp and compatible runtimes)
- **Size**: $DISPLAY_SIZE
- **Precision**: $QTYPE
- **Base Model**: [$BASE_REPO](https://huggingface.co/$BASE_REPO)
- **Conversion Tool**: [llama.cpp](https://github.com/ggerganov/llama.cpp)

## Quality & Performance

| Metric | Value |
|-------|-------|
| **Quality** | $QUAL |
| **Speed** | $SPEED |
| **RAM Required** | $RAM |
| **Recommendation** | $($RECOMMENDATIONS[$QTYPE]) |

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

## 🖥️ CLI Example Using Ollama or TGI Server

Here’s how you can query this model via API using \`curl\` and \`jq\`. Replace the endpoint with your local server.

\`\`\`bash
curl http://localhost:11434/api/generate -s -N -d '{
  "model": "hf.co/geoffmunn/$MODEL_NAME:${QTYPE}",
  "prompt": "Respond exactly as follows: $PROMPT",
  "temperature": $TEMP,
  "top_p": 0.95,
  "top_k": 20,
  "min_p": 0.0,
  "repeat_penalty": 1.1,
  "stream": false
}' | jq -r '.response'
\`\`\`

🎯 **Why this works well**:
- The prompt is meaningful and achievable for this model size.
- Temperature tuned appropriately: lower for factual (\`0.5\`), higher for creative (\`0.7\`).
- Uses \`jq\` to extract clean output.

## Verification

Check integrity:

\`\`\`bash
certutil -hashfile '${MODEL_NAME}-${INPUT_PRECISION}:$QTYPE.gguf' SHA256
# Compare with values in SHA256SUMS.txt
\`\`\`

## Usage

Compatible with:
- [LM Studio](https://lmstudio.ai) – local AI model runner
- [OpenWebUI](https://openwebui.com) – self-hosted AI interface
- [GPT4All](https://gpt4all.io) – private, offline AI chatbot
- Directly via \`llama.cpp\`

## License

Apache 2.0 – see base model for full terms.
"@

    $CARD | Out-File -FilePath "$DIRNAME/README.md" -Encoding UTF8
    Write-Host "✅ Generated per-model card: $DIRNAME/README.md" -ForegroundColor Green
}


# -------------------------------
# STEP 5: Generate Shared MODELFILE
# -------------------------------

$MODELFILE_CONTENT = @"
# MODELFILE for $($MODEL_NAME)-GGUF
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
"@

$MODELFILE_CONTENT | Out-File -FilePath "MODELFILE" -Encoding UTF8
Write-Host "✅ Shared MODELFILE generated!" -ForegroundColor Green


# -------------------------------
# STEP 6a: Ensure HF Repo Exists
# -------------------------------

Write-Host "🔍 Ensuring Hugging Face repo exists: $HF_REPO" -ForegroundColor Cyan

if (-not (Get-Command huggingface-cli -ErrorAction SilentlyContinue)) {
    Write-Host "📦 Installing huggingface_hub..." -ForegroundColor Yellow
    pip install huggingface_hub --quiet
}

python -c "
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

Write-Host "📤 Final files to upload:" -ForegroundColor Cyan
Get-ChildItem *.gguf, README.md, MODELFILE, SHA256SUMS.txt | Select-Object Name, Length | Format-Table

$reply = Read-Host "👉 Continue with upload? [Y/n]"
if ($reply -match '^[Nn]$') {
    Write-Host "⏭️ Skipped upload. Files ready in $OUTPUT_DIR" -ForegroundColor Yellow
    exit 0
}

Write-Host "🚀 Uploading all files to $HF_REPO_URL" -ForegroundColor Green
hf upload `
  "$HF_REPO" `
  . `
  --repo-type=model `
  --commit-message "$COMMIT_MSG"

Write-Host ""
Write-Host "🎉 Success! Your model has been uploaded." -ForegroundColor Green
Write-Host "🌐 View it at: $HF_REPO_URL"