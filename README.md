## Codebase Q&A MVP (LangChain + Chroma + OpenAI)

### Prerequisites
- Python 3.10+
- Set `OPENAI_API_KEY` via `.env` or your shell

1) Copy the example env and edit your key:
```bash
cp .env.example .env
```
2) Or export in your shell:
```bash
export OPENAI_API_KEY=sk-...  # use your real key
```

### Install
```bash
pip install -r requirements.txt
```

### Build the index
```bash
python indexer.py \
  --source_dir /workspace \
  --persist_dir /workspace/.chroma \
  --chunk_size 2000 \
  --chunk_overlap 200 \
  --embedding_model text-embedding-3-small
```

### Ask questions
```bash
python query.py \
  --persist_dir /workspace/.chroma \
  --question "用户认证流程是如何实现的？" \
  --k 6 \
  --chat_model gpt-4o-mini
```

### Notes
- The indexer excludes common noisy folders like `node_modules`, `.venv`, and `__pycache__`.
- Supported file types by default: `.py`, `.js`, `.ts`, `.tsx`, `.md`, `.rst`, `.json`, `.yml`, `.yaml`, `.toml`, `.txt`.
- Adjust parameters as needed via CLI flags.

