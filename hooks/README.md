# Hooks

`azvm-resize --pre-hook NAME --post-hook NAME` runs `hooks/NAME` before and after the resize. Rules, enforced by the tool:

- The hook is a **file in this directory**. It must be executable and its name must be a plain file name (no `/`, no leading dot). The tool never runs a shell string from a flag.
- It receives `VM`, `RG`, `TARGET`, `CURRENT` and `PHASE` (`pre` or `post`) as environment variables, and nothing else from the caller.
- A **pre** hook that fails aborts before anything is resized. A **post** hook that fails is reported loudly but does not undo the resize.
- Files ending in `.example` are templates. Copy one, remove the suffix, read it, `chmod +x` it. Reading it is the review.

The templates stop and start a service over ssh and check mounts afterward. Edit the host and unit names for your VM.
