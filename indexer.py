import argparse
import os
import sys
from typing import Iterable, List, Set

from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_core.documents import Document
from langchain_openai import OpenAIEmbeddings
from langchain_community.vectorstores import Chroma
from dotenv import load_dotenv


DEFAULT_ALLOWED_EXTENSIONS: Set[str] = {
    ".py",
    ".js",
    ".ts",
    ".tsx",
    ".md",
    ".rst",
    ".json",
    ".yml",
    ".yaml",
    ".toml",
    ".txt",
}

DEFAULT_EXCLUDED_DIRNAMES: Set[str] = {
    ".git",
    ".hg",
    ".svn",
    ".DS_Store",
    "__pycache__",
    ".pytest_cache",
    ".mypy_cache",
    ".ruff_cache",
    ".idea",
    ".vscode",
    ".venv",
    "venv",
    "env",
    "node_modules",
    "dist",
    "build",
    "site-packages",
    "coverage",
}


def iter_file_paths(
    root_dir: str,
    allowed_extensions: Set[str],
    excluded_dirs: Set[str],
) -> Iterable[str]:
    """Yield absolute file paths under root_dir matching allowed extensions and skipping excluded directories."""
    for current_root, dirnames, filenames in os.walk(root_dir):
        # prune excluded directories in-place for efficiency
        dirnames[:] = [d for d in dirnames if d not in excluded_dirs and not d.startswith('.')]
        for filename in filenames:
            _, ext = os.path.splitext(filename)
            if ext.lower() in allowed_extensions:
                abs_path = os.path.abspath(os.path.join(current_root, filename))
                yield abs_path


def load_documents(file_paths: Iterable[str]) -> List[Document]:
    documents: List[Document] = []
    for path in file_paths:
        try:
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                text = f.read()
            if not text.strip():
                continue
            documents.append(Document(page_content=text, metadata={"source": path}))
        except Exception:
            # Skip unreadable files silently for MVP simplicity
            continue
    return documents


def main() -> None:
    load_dotenv()
    parser = argparse.ArgumentParser(description="Index a codebase into a local Chroma vector store")
    parser.add_argument(
        "--source_dir",
        type=str,
        default=os.path.abspath("/workspace"),
        help="Absolute path to the project directory to index",
    )
    parser.add_argument(
        "--persist_dir",
        type=str,
        default=os.path.abspath("/workspace/.chroma"),
        help="Absolute path where Chroma database will be persisted",
    )
    parser.add_argument(
        "--chunk_size",
        type=int,
        default=2000,
        help="Chunk size for RecursiveCharacterTextSplitter",
    )
    parser.add_argument(
        "--chunk_overlap",
        type=int,
        default=200,
        help="Chunk overlap for RecursiveCharacterTextSplitter",
    )
    parser.add_argument(
        "--embedding_model",
        type=str,
        default="text-embedding-3-small",
        help="OpenAI embedding model name",
    )
    args = parser.parse_args()

    source_dir = os.path.abspath(args.source_dir)
    persist_dir = os.path.abspath(args.persist_dir)

    os.makedirs(persist_dir, exist_ok=True)

    file_paths = list(
        iter_file_paths(
            root_dir=source_dir,
            allowed_extensions=DEFAULT_ALLOWED_EXTENSIONS,
            excluded_dirs=DEFAULT_EXCLUDED_DIRNAMES,
        )
    )

    if not file_paths:
        print(f"No files found to index under: {source_dir}")
        return

    print(f"Discovered {len(file_paths)} files. Loading documents…")
    documents = load_documents(file_paths)
    print(f"Loaded {len(documents)} documents. Splitting into chunks…")

    splitter = RecursiveCharacterTextSplitter(
        chunk_size=args.chunk_size, chunk_overlap=args.chunk_overlap
    )
    chunks = splitter.split_documents(documents)
    print(f"Created {len(chunks)} chunks. Computing embeddings and persisting to Chroma…")

    # Ensure OpenAI API key is available
    if not os.environ.get("OPENAI_API_KEY"):
        print("ERROR: OPENAI_API_KEY is not set. Create a .env with OPENAI_API_KEY or export it in your shell.")
        sys.exit(1)

    embeddings = OpenAIEmbeddings(model=args.embedding_model)

    vectorstore = Chroma.from_documents(
        documents=chunks,
        embedding=embeddings,
        persist_directory=persist_dir,
    )
    vectorstore.persist()

    print(
        "Indexing complete."
        f"\n - Source directory: {source_dir}"
        f"\n - Persist directory: {persist_dir}"
        f"\n - Files indexed: {len(file_paths)}"
        f"\n - Chunks stored: {len(chunks)}"
    )


if __name__ == "__main__":
    main()

