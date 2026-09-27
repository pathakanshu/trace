"""Small server-only Jev client. No SDK or extra service.

The operational ledger survives demo resets. It is not an evidence database.
Reserve the full published 64k request ceiling before sending, then reconcile
only validated usage. Unknown outcomes keep the reservation. One local process
at a time may spend; flock also protects multiple workers on this same host.
"""
import os;
import json;
import math;
import fcntl;
import from urllib.request { Request, urlopen }

glob JEV_MODEL: str = "jev-1.13.0";
glob RATE: float = 0.042 / 1000000;
glob RESERVATION: float = 64000 * RATE;

def post_jev(body: bytes, key: str) -> dict {
    request = Request("https://api.typesafe.ai/v1/systemone", data=body,
        headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"}, method="POST");
    response = urlopen(request, timeout=5);
    try {
        raw = response.read(65537);
        if len(raw) > 65536 { raise ValueError("Response too large"); }
        return json.loads(raw);
    } finally {
        response.close();
    }
}

def validate_answers(response: dict, questions: dict[str, any]) -> dict {
    if response.get("model") != JEV_MODEL { raise ValueError("Unexpected model"); }
    answers: dict[str, any] = response.get("answers", {});
    if set(answers.keys()) != set(questions.keys()) { raise ValueError("Incomplete answers"); }
    for name in questions {
        answer: dict[str, any] = answers[name];
        choices: dict[str, any] = questions[name]["criteria"];
        if answer.get("type") != "choice" or answer.get("choice") not in choices {
            raise ValueError("Invalid choice");
        }
        probabilities: dict[str, float] = answer.get("probabilities", {});
        if set(probabilities.keys()) != set(choices.keys()) { raise ValueError("Invalid distribution"); }
        numbers = list(probabilities.values()) + [answer.get("confidence", -1)];
        for value in numbers {
            if isinstance(value, bool) or not isinstance(value, (int, float)) {
                raise ValueError("Invalid probability type");
            }
            if not math.isfinite(value) or value < 0 or value > 1 { raise ValueError("Invalid probability"); }
        }
        if abs(sum(probabilities.values()) - 1) > 0.01 { raise ValueError("Invalid probability sum"); }
        if probabilities[answer["choice"]] < max(probabilities.values()) { raise ValueError("Invalid winner"); }
    }
    tokens = response.get("usage", {}).get("input_tokens", 0);
    if isinstance(tokens, bool) or not isinstance(tokens, int) or tokens < 1 or tokens > 64000 {
        raise ValueError("Invalid usage");
    }
    return answers;
}

# transport and ledger_path are internal test seams, never exposed as RPC inputs.
def evaluate(state: dict, questions: dict, transport: any = None, ledger_path: str = "") -> dict {
    if os.environ.get("TRACE_JEV_ENABLED", "") != "1" {
        return {"status": "UNAVAILABLE", "message": "Jev is disabled. The sourced reports remain available."};
    }
    key = os.environ.get("TYPESAFE_API_KEY", "");
    if not key { return {"status": "UNAVAILABLE", "message": "Configure TYPESAFE_API_KEY on the server."}; }
    try {
        limit = float(os.environ.get("TRACE_JEV_BUDGET_USD", "1"));
        if not math.isfinite(limit) or limit <= 0 or limit > 8 { raise ValueError("Invalid allowance"); }
        body = json.dumps({"model": JEV_MODEL, "state": state, "questions": questions}, ensure_ascii=False).encode();
        if len(body) > 12000 { return {"status": "PARTIAL", "message": "Evidence exceeds the small-request limit; review the full source."}; }
        path = ledger_path or ".trace-local/jev-spending.json";
        os.makedirs(os.path.dirname(path), exist_ok=True);
        existed = os.path.exists(path);
        with open(path, "a+") as ledger {
            # Nonblocking: concurrent requests abstain instead of forming a paid queue.
            fcntl.flock(ledger.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB);
            ledger.seek(0);
            raw = ledger.read();
            if existed and not raw { raise ValueError("Empty existing ledger; reconcile manually"); }
            data: dict[str, any] = json.loads(raw) if raw else {"reserved_usd": 0.0, "attempts": 0};
            spent = data["reserved_usd"];
            if not isinstance(spent, (int, float)) or not math.isfinite(spent) or spent < 0 {
                raise ValueError("Invalid ledger");
            }
            if spent + RESERVATION > limit {
                return {"status": "BUDGET_LIMIT", "message": "Investigation allowance reached. No request sent."};
            }
            data["reserved_usd"] = spent + RESERVATION;
            data["attempts"] += 1;
            save_ledger(ledger, data);
            # No automatic retries. Every explicit retry must reserve again.
            try {
                response = transport(body, key) if transport else post_jev(body, key);
                answers = validate_answers(response, questions);
            } except Exception {
                return {"status": "FAILED", "message": "Jev request failed or returned invalid output. No finding was accepted."};
            }
            charged = int(response["usage"]["input_tokens"]) * RATE;
            data["reserved_usd"] = spent + charged;
            save_ledger(ledger, data);
            return {"status": "LIVE", "model": JEV_MODEL, "answers": answers,
                "input_tokens": response["usage"]["input_tokens"], "estimated_usd": charged};
        }
    } except Exception {
        return {"status": "UNAVAILABLE", "message": "Spending guard unavailable or busy. No unguarded request will be sent."};
    }
}

def save_ledger(ledger: any, data: dict) -> None {
    ledger.seek(0);
    ledger.truncate();
    ledger.write(json.dumps(data));
    ledger.flush();
    os.fsync(ledger.fileno());
}
