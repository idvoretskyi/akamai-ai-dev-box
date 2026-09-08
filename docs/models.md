# Models And OpenCode

## Reference Model

The initial reference is `qwen3:8b`, expected as Q4_K_M with approximately 5.2 GB of weights. It is a smoke-test and integration reference, **not a claim of the best coding model**, reliable autonomous tool use, or measured performance on this GPU.

Model downloads are explicit and are not part of bootstrap. After the server is ready, run these commands on the GPU box from the repository root:

```bash
ollama pull qwen3:8b
ollama show qwen3:8b
ollama create dev-coder -f examples/models/Modelfile
ollama show dev-coder
```

The [Modelfile](../examples/models/Modelfile) sets `num_ctx 16384` and `num_predict 4096`. OpenCode uses the alias `dev-coder`, so changing the reference requires deliberately recreating that alias and reviewing the matching configuration limits. Context includes prompt, tool results, conversation, and generated output; 16,384 is not an input allowance plus another 4,096 output tokens.

Tags are mutable. Before relying on an evaluation, record the full digest, quantization, pull date, Ollama version, Modelfile, and model license in your own evaluation record. Inspect local metadata:

```bash
curl --fail --silent --show-error http://127.0.0.1:11434/api/tags | jq '.models[] | {name, digest, size, details}'
ollama show qwen3:8b --license
ollama show dev-coder --modelfile
```

Check the [upstream Ollama model entry](https://ollama.com/library/qwen3:8b) and the actual downloaded license. The repository's MIT license does not license model weights. Do not assume a future pull of the same tag reproduces an earlier model or download size.

## Resource Budget

The baseline permits one parallel inference request and one loaded model, with a 16,384-token context. Ollama runs under a systemd budget of `MemoryMax=10G` and `CPUQuota=200%`, with `OLLAMA_NUM_PARALLEL=1` and `OLLAMA_MAX_LOADED_MODELS=1`. This leaves some of the 16 GiB host RAM and four vCPUs for development; it does not reserve an exact amount for other processes or guarantee successful loading.

`MemoryMax` limits host memory, not the GPU's 20 GB VRAM. Weights, KV cache, runtime buffers, and other GPU users all affect fit. CPU quota limits CPU time to approximately two cores; it is not CPU affinity. Requests can queue, and OpenCode's small-model work shares the same local model and service budget.

Do not increase concurrency or context merely because weight size looks small. Check `ollama ps`, `nvidia-smi`, system memory, and service logs during a real workload first. Larger models, CPU offload, and simultaneous heavy builds may make the box unresponsive or cause OOM failures. No throughput or latency benchmark is promised.

## Select An Example

Run OpenCode on the GPU box so `127.0.0.1` refers to the same host as Ollama. From the repository root, choose one:

```bash
OPENCODE_CONFIG="$PWD/examples/opencode/local-only.json" opencode
```

```bash
OPENCODE_CONFIG="$PWD/examples/opencode/hybrid.json" opencode
```

- [Local-only](../examples/opencode/local-only.json) allows only the `ollama` model provider.
- [Hybrid](../examples/opencode/hybrid.json) allows `ollama` and `github-copilot`, while keeping the default main and small models local.
- Both use `@ai-sdk/openai-compatible` at `http://127.0.0.1:11434/v1`, with model ID `dev-coder`, context limit 16,384, and output limit 4,096.
- Both disable sharing and automatic OpenCode updates, and set `permission.edit` and `permission.bash` to `ask`.

These are opt-in examples, not automatically installed user configuration. `OPENCODE_CONFIG` adds a config source and **merges** it with existing configuration. Project or other higher-precedence settings can override it; inherited agents can select different models, and inherited plugins or MCP servers remain relevant. Review your effective setup before using private code. Quit and restart OpenCode after changing a config file or the selected config path. A running process does not reload it.

The [published schema](https://opencode.ai/config.json) names the capability flag `tool_call`, which the examples set to `true`. This advertises capability to OpenCode; it is not proof of end-to-end tool-call reliability. The published schema is live rather than version-pinned, and its external model catalog may flag custom local model IDs in generic validators. The custom provider declaration and the pinned runtime must also be checked; do not substitute a hosted model merely to satisfy catalog autocomplete.

## Optional Copilot

Start with the hybrid example, use `/connect` to authenticate with GitHub Copilot, and use `/models` to select a model actually available to your account and supported by that OpenCode release. No particular frontier model is guaranteed. GitHub CLI login is separate from OpenCode provider authentication; no authentication store is copied by this project.

Your subscription, organization policy, data handling terms, premium requests, and usage limits apply. Switching providers inside an existing session may send earlier messages, code, and tool output to the hosted provider. Start a new session with reviewed context when changing trust boundaries; this does not undo any data already sent. See [security](security.md#local-does-not-mean-isolated).

## Runtime Evaluation

Only on a separately approved deployed GPU box, after creating `dev-coder`:

```bash
bash scripts/smoke-test.sh dev-coder
```

Keep infrastructure readiness, model generation, and OpenCode tool-use evaluation separate. After the smoke check, try a disposable repository with a small, non-sensitive task; inspect a proposed edit and shell command before approving them. Record model digest, versions, context settings, GPU utilization, failures, and elapsed time. A simple generated answer does not establish correct agentic coding behavior.
