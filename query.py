import argparse
import os
import sys
from typing import List

from langchain_openai import OpenAIEmbeddings, ChatOpenAI
from langchain_community.vectorstores import Chroma
from langchain_core.documents import Document
from langchain_core.messages import SystemMessage, HumanMessage
from dotenv import load_dotenv


SYSTEM_PROMPT = (
    "你是一个专业的软件开发助手。请基于以下提供的项目代码上下文来回答用户的问题。"
    "如果上下文中没有足够信息，请明确说明你不知道，并指出可能的文件或位置。"
)


def truncate_context(text: str, max_chars: int = 12000) -> str:
    if len(text) <= max_chars:
        return text
    head = text[: max_chars - 500]
    tail = text[-500:]
    return head + "\n\n... [内容过长，已截断] ...\n\n" + tail


def format_context(docs: List[Document]) -> str:
    parts: List[str] = []
    for idx, d in enumerate(docs, start=1):
        src = d.metadata.get("source", "")
        parts.append(f"[片段 {idx}] 源文件: {src}\n" + d.page_content)
    return "\n\n-----\n\n".join(parts)


def main() -> None:
    load_dotenv()
    parser = argparse.ArgumentParser(description="Query a local Chroma index with an OpenAI chat model")
    parser.add_argument(
        "--persist_dir",
        type=str,
        default=os.path.abspath("/workspace/.chroma"),
        help="Absolute path to the Chroma persist directory",
    )
    parser.add_argument(
        "--question",
        type=str,
        required=True,
        help="User question about the codebase",
    )
    parser.add_argument(
        "--k",
        type=int,
        default=6,
        help="Number of top similar chunks to retrieve",
    )
    parser.add_argument(
        "--embedding_model",
        type=str,
        default="text-embedding-3-small",
        help="OpenAI embedding model name",
    )
    parser.add_argument(
        "--chat_model",
        type=str,
        default=os.environ.get("OPENAI_MODEL", "gpt-4o-mini"),
        help="OpenAI chat model name",
    )
    args = parser.parse_args()

    # Ensure OpenAI API key is available
    if not os.environ.get("OPENAI_API_KEY"):
        print("ERROR: OPENAI_API_KEY is not set. Create a .env with OPENAI_API_KEY or export it in your shell.")
        sys.exit(1)

    # Load vector store and retrieve context
    embeddings = OpenAIEmbeddings(model=args.embedding_model)
    vectorstore = Chroma(persist_directory=os.path.abspath(args.persist_dir), embedding_function=embeddings)

    docs = vectorstore.similarity_search(args.question, k=args.k)

    if not docs:
        print("没有检索到相关上下文。请确认索引已经构建，或调整问题表述。")
        return

    ctx_text = truncate_context(format_context(docs))

    messages = [
        SystemMessage(content=SYSTEM_PROMPT + "\n\n[上下文]\n" + ctx_text),
        HumanMessage(content="[用户问题]\n" + args.question),
    ]

    llm = ChatOpenAI(model=args.chat_model, temperature=0)
    response = llm.invoke(messages)
    print(response.content)


if __name__ == "__main__":
    main()

