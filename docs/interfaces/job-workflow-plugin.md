# Jobs, workflows, and plugins

## Job runtime

Every heavy operation is a job with stable ID, typed input receipt, resource estimate, progress phases, cancellation token, checkpoint policy, partial-output policy, evidence, and terminal state. Writes use transactional staging and atomic commit where supported.

States: queued, admitted, running, pausing, paused, cancelling, cancelled, completed, partially completed, failed, recovery required.

## Workflow

Versioned DAG of typed nodes/ports. Validator rejects cycles (unless an explicit bounded loop node), incompatible types, unavailable capabilities, unbounded fan-out, missing permissions, and unsafe cloud transfers. Runtime records each node result/provenance and supports checkpoint/resume.

AI may propose a workflow, but user reviews nodes, data transfers, cost, and authority before activation.

## Plugins

Manifest declares API version, plugin identity/signature/provenance, capabilities, permissions, resource limits, entry points, and settings schema. Default deny. No plugin gets filesystem/network/AI/credential/native authority unless explicitly granted. Unsupported plugin versions fail closed.
