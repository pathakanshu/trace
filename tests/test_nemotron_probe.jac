"""Offline checks for the typed Nemotron probe. MockLLM only: no key, no network."""
import from unittest.mock { patch }
import from jaclang.byllm.lib { MockLLM, MockRawResponse, OutputConversionError }

def mock_replies(replies: list[str]) -> MockLLM {
    return MockLLM(
        model_name="mockllm",
        config={"outputs": [MockRawResponse(content=reply) for reply in replies]}
    );
}

# `jac test` evicts project modules from sys.modules each time it collects
# another file, and byLLM resolves the Probe annotations through sys.modules,
# so the module is imported when the test runs rather than at collection.
# `by llm(...)` also captures the Model object at import, so the test routes
# that object to a MockLLM instead of rebinding the glob; the real call
# parameters (no output retries) stay in the path under test.
def ask(mock: MockLLM, text: str) -> str {
    import from integrations.nemotron { llm, probe, Probe }
    swap = patch.object(llm, "_mock_delegate", mock);
    swap.start();
    try {
        result = probe(text);
    } finally {
        swap.stop();
    }
    assert isinstance(result, Probe);
    return result.label;
}

test "provider JSON becomes a typed Probe" {
    assert ask(mock_replies(['{"label": "YES"}']), "The river flooded the lower bridge.") == "YES";
}

test "reasoning-off switch rides only on requests for the Nemotron model" {
    import from integrations.nemotron { with_reasoning_off, NEMOTRON_MODEL }
    ours = with_reasoning_off({"model": NEMOTRON_MODEL, "extra_body": {"seed": 1}});
    assert ours["extra_body"] == {"seed": 1, "chat_template_kwargs": {"enable_thinking": False}};
    other = {"model": "nvidia_nim/other-model"};
    assert with_reasoning_off(other) == other;
}

test "an out-of-menu label fails once without a corrective retry" {
    mock = mock_replies(['{"label": "MAYBE"}', '{"label": "NO"}']);
    failed = False;
    try {
        ask(mock, "The road is dry.");
    } except OutputConversionError {
        failed = True;
    }
    assert failed;
    assert len(mock.config["outputs"]) == 1;
}
