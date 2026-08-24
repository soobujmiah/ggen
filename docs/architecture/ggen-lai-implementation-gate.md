# GGEN ↔ LAI Implementation Gate

**Status:** Planning gate — no implementation authorization
**Date:** 2026-08-24

## Purpose

This document converts the architecture boundary into an agent-executable preparation sequence. A future coding agent must complete the documentation/decision gates before changing production code.

## Gate A — repository boundaries

- GGEN remains an independent Flutter/Dart product.
- LAI remains an independent Kotlin/Android-first AI/runtime product.
- No repository submodule relationship.
- No direct dependency from GGEN core to LAI implementation classes.
- No direct dependency from LAI core/runtime to GGEN UI/document classes.

## Gate B — provider abstraction

Document and then implement a provider-neutral GGEN interface covering:

- provider discovery;
- capability advertisement;
- request creation;
- response handling;
- streaming;
- cancellation;
- structured errors;
- privacy classification;
- authentication references;
- artifact transfer/reference.

The interface must support a provider that is completely unavailable without making GGEN unusable.

## Gate C — LAI adapter

Document and then implement an LAI provider adapter that translates the external capability contract into LAI's existing runtime boundaries.

The adapter must not bypass:

- model validation;
- backend selection;
- scheduler policy;
- tool permission policy;
- audit;
- privacy invariants.

## Gate D — cloud/custom adapters

The architecture must remain capable of adding cloud/custom providers without changing GGEN document or canvas models.

At least one provider-independent conformance test suite should exercise the same contract against fake/local and remote-style providers.

## Gate E — capability semantics

Before implementation, define exact semantics for:

- text generation;
- vision analysis;
- OCR;
- image generation;
- image editing;
- embeddings;
- tool execution;
- agent execution.

For every capability specify inputs, outputs, optional streaming, cancellation, errors, size limits and privacy classification.

## Gate F — transport

Transport is intentionally undecided. Select it only after comparing:

- Android local integration;
- remote LAN use;
- cloud/custom HTTP use;
- streaming;
- authentication;
- cancellation;
- large artifact transfer;
- version negotiation;
- security isolation.

The selected transport must not leak into GGEN's domain model.

## Gate G — UI workspace

The professional workspace shell is a separate milestone from provider integration.

The UI milestone must use `docs/design/professional-workspace-shell.md` as its source specification.

## Gate H — verification

Every implementation milestone must provide:

1. unit tests;
2. integration/contract tests;
3. analyzer/build verification;
4. documentation update;
5. device validation where behavior is device-dependent;
6. explicit evidence boundaries.

## Deferred by design

The following are deliberately not selected yet:

- exact wire protocol;
- exact JSON schema implementation language;
- provider discovery mechanism;
- cloud provider credentials strategy;
- binary artifact transport;
- agent UI implementation;
- automatic provider failover policy.

These are decision records, not omissions.
