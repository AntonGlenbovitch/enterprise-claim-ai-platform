"""Utility module for selecting an LLM based on task type."""


def select_model(task_type):
    """Return the model name to use for a given task type.

    Args:
        task_type: A string describing the type of task.

    Returns:
        The selected model name as one of: "Claude", "Llama", or "local model".
    """
    normalized_task = (task_type or "").strip().lower()

    model_by_task = {
        "reasoning": "Claude",
        "analysis": "Claude",
        "summarization": "Llama",
        "classification": "Llama",
    }

    return model_by_task.get(normalized_task, "local model")
