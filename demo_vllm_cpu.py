import os
from typing import List

from transformers import AutoTokenizer
from vllm import LLM, SamplingParams


def main() -> None:
    model_id: str = os.getenv("VLLM_MODEL", "TinyLlama/TinyLlama-1.1B-Chat-v1.0")

    # Chat models require chat templating; build prompts via the model's template
    tokenizer = AutoTokenizer.from_pretrained(model_id, use_fast=True)

    def apply_chat(user_text: str) -> str:
        messages = [
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": user_text},
        ]
        return tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True,
        )

    prompts: List[str] = [
        apply_chat("Write a friendly one-paragraph introduction to vLLM."),
        apply_chat("List 5 creative uses for a small language model running on CPU."),
    ]

    sampling_params = SamplingParams(
        temperature=0.7,
        top_p=0.9,
        max_tokens=128,
        presence_penalty=0.0,
        frequency_penalty=0.0,
    )

    # vLLM auto-detects CPU on macOS; no explicit device param
    llm = LLM(model=model_id, dtype="float32")

    print(f"\nLoading model: {model_id} (CPU, dtype=float32)\n")
    outputs = llm.generate(prompts, sampling_params)

    for i, output in enumerate(outputs):
        prompt = prompts[i]
        generated_text = output.outputs[0].text if output.outputs else ""
        print("=" * 80)
        print(f"Prompt {i + 1}:")
        print(prompt)
        print("-" * 80)
        print("Completion:")
        print(generated_text.strip())
        print()


if __name__ == "__main__":
    main()


