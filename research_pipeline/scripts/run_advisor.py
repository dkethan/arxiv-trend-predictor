"""
CLI entrypoint for the Idea Advisor.

Usage:
    python -m research_pipeline.scripts.run_advisor train
    python -m research_pipeline.scripts.run_advisor advise "Title" "Abstract"
"""

from __future__ import annotations

import argparse

from research_pipeline.advisor.idea_advisor import advise_idea, train_domain_classifier


def main() -> None:
    parser = argparse.ArgumentParser(description="Idea Advisor CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("train", help="Train or retrain the domain classifier")

    advise_parser = subparsers.add_parser("advise", help="Get advice for an idea")
    advise_parser.add_argument("title", type=str, help="Title or short description")
    advise_parser.add_argument(
        "abstract",
        type=str,
        nargs="?",
        default="",
        help="Optional abstract or longer description",
    )

    args = parser.parse_args()

    if args.command == "train":
        metrics = train_domain_classifier()
        print("Trained domain classifier.")
        print(f"Accuracy: {metrics['accuracy']:.4f}")
        print(f"Macro F1: {metrics['macro_f1']:.4f}")
    elif args.command == "advise":
        result = advise_idea(args.title, args.abstract)
        print("\n" + result["message"])
        if result.get("alternate_domains"):
            print(
                "\nOther likely domains:",
                [d for d, _ in result["alternate_domains"]],
            )
        print(
            f"\nDomain growth on arXiv: {result['domain_growth_score']} "
            f"— {result['domain_growth_label']}"
        )
        print("Note:", result.get("disclaimer", ""))
        print("Suggested keywords:", result["suggested_keywords"])


if __name__ == "__main__":
    main()

