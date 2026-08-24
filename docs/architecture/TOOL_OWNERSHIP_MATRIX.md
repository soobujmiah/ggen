# GGEN ↔ LAI Tool Ownership Matrix

## Principle

Ownership follows responsibility, not implementation language or where a prototype happens to live.

### GGEN owns

- project artifacts
- canvas and editing state
- creative tools
- document semantics
- templates and layout
- assets and exports
- workflow authoring
- AI-assisted creative UX

### LAI owns

- inference/runtime execution
- model lifecycle
- accelerator backends
- AI scheduling
- agent authority
- Android automation
- OCR/model execution
- RAG/memory runtime
- privileged tools
- execution evidence and AI-runtime diagnostics

## Shared-looking tools

| Tool/function | Canonical owner | Consumer | Contract |
|---|---|---|---|
| OCR | LAI runtime | GGEN editor | `ocr.extract` |
| Image generation | Provider/runtime | GGEN studio | `image.generate` |
| Image edit/inpaint | Provider/runtime | GGEN studio | `image.edit` |
| Text generation | LAI/cloud | GGEN | `text.generate` |
| Embedding | LAI/cloud | GGEN/RAG consumers | `embedding.create` |
| Agent | LAI | GGEN workflow/creative actions | `agent.run` |
| Device automation | LAI | GGEN only through explicit tools | `tool.execute` |
| Workflow | GGEN authoring | LAI optional executor | versioned workflow contract |
| Diagnostics | Each product locally | cross-provider evidence | normalized evidence schema |

## Duplicate implementation policy

If both repositories contain similar functionality:

1. Preserve the implementation that owns the domain semantics.
2. Avoid copying code merely to remove a dependency.
3. If a capability is runtime infrastructure, prefer LAI.
4. If a capability manipulates GGEN artifacts, prefer GGEN.
5. Extract a stable protocol only when real cross-product reuse exists.
6. Do not create a shared monorepo/package solely to share small utility code.

## Agent rule

Before moving, deleting, duplicating or rewriting a tool, the agent must identify:

- current owner
- target owner
- consumer list
- migration path
- compatibility impact
- tests/evidence
- rollback path

No silent ownership migration is allowed.
