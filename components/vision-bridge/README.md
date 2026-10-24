# vision-bridge (not ported to 0.2.x)

The 1.x vision-bridge worked by patching two Host packages:

- `@deepseek-ai/dsh-host-apiproxy` — drop the “model does not support images” rejection;
- `@deepseek-ai/dsh-llm-pi-ai` — project image blocks to a text placeholder carrying the local path.

Both targets changed in DSH 0.2 and the patches are **not** applied by the
installer. Keep them only as a reference for the 0.1.x behaviour.

For 0.2.x, prefer a supported route instead:

- use a model configuration with image input, or
- configure a vision MCP server and let the agent call its vision tool on a
  local image path.

If you want to port this component, the replacement seam is the LLM adapter's
image projection plus a prompt-admission hook; do not edit installed packages.
