# Design: index Vue `<script setup>` symbols (AGL-6)

Upstream tracking: DeusData/codebase-memory-mcp#1410.

## Problem

Symbols declared in a Vue SFC `<script setup>` block never enter the graph.
`internal/cbm/lang_specs.c` gives `CBM_LANG_VUE` an almost entirely
`empty_types` spec, so an SFC emits only a `Module` and a `File` node. The
downstream effects that make graph analysis untrustworthy on Vue repos:

- a TS export consumed **only** from SFCs is reported dead;
- fan-in / rename-impact for such a symbol misses every `.vue` referrer.

Q&A quality is unaffected (grep already covers it), so the fix is about graph
completeness, not answer text.

## Existing seam

`parse_embedded_imports` (internal/cbm/extract_imports.c) already re-parses each
host `<script>` block with an embedded grammar and walks the inner AST — but it
runs **only** the ES import walker (`walk_es_imports`), and it does so over a
byte **slice** re-parse:

```c
const char *sub_src = ctx->source + s;          // slice start
TSTree *sub_tree = ts_parser_parse_string(parser, NULL, sub_src, end - s);
CBMExtractCtx sub_ctx = *ctx;
sub_ctx.source = sub_src;                        // slice-relative coordinates
sub_ctx.root   = ts_tree_root_node(sub_tree);
walk_es_imports(&sub_ctx, sub_ctx.root);         // imports only
```

The embedded language is declared per host in `lang_specs.c`:

```c
static const CBMEmbeddedLangSpec vue_embedded_imports[] = {
    {"script_element", "raw_text", CBM_LANG_JAVASCRIPT}, {0},
};
// svelte_embedded_imports is byte-identical.
```

Two limitations cause AGL-6: (1) only imports are extracted, so defs/calls/
usages in the script never become nodes/edges; (2) the embedded language is
hard-wired to JavaScript, so a `<script setup lang="ts">` block is parsed with
the JS grammar (type-only constructs are lost).

## Approach

Generalize the embedded seam from "imports over a slice" to "the full walker set
over the file, in file coordinates."

### 1. Parse with `ts_parser_set_included_ranges`, not a slice

Instead of copying the script bytes to a new buffer and re-parsing them at offset
0, parse the **original** `ctx->source` with the embedded grammar restricted to
the content node's byte/point range:

```c
TSRange r = {
    .start_point = ts_node_start_point(content),
    .end_point   = ts_node_end_point(content),
    .start_byte  = ts_node_start_byte(content),
    .end_byte    = ts_node_end_byte(content),
};
ts_parser_set_included_ranges(parser, &r, 1);
TSTree *sub_tree = ts_parser_parse_string(parser, NULL, ctx->source, ctx->source_len);
```

Every node in `sub_tree` then reports **file** byte offsets and row/col, so the
emitted nodes/edges land at their true `.vue` positions with zero offset
bookkeeping. `sub_ctx.source` stays `ctx->source` (the whole file).

### 2. Run the full walker set, not just imports

Mirror the preprocessor sub-context precedent (`pp_ctx` in cbm.c ~1399-1455):
build a `CBMExtractCtx` that shares the parent's `arena`, `result`, `project`,
`rel_path`, and `module_qn`, but points at the embedded sub-tree and the embedded
language, then run the standard passes so their nodes/edges accumulate into the
same `result`:

```c
CBMExtractCtx sub = *ctx;
sub.language = block_language;      /* JS or TS — see §3 */
sub.root     = ts_tree_root_node(sub_tree);
cbm_extract_definitions(&sub);
cbm_extract_imports(&sub);          /* JS/TS spec has no nested embedded_imports → no recursion */
cbm_extract_unified(&sub);          /* calls + usages */
```

Because `sub.module_qn` is the `.vue` module QN, the script's symbols are
qualified under the SFC's module, so fan-in / rename-impact naturally list the
`.vue` file.

The generalized routine (`parse_embedded_scripts`) replaces the imports-only
`parse_embedded_imports` **in place**, keeping its existing wiring: it is still
invoked from the host import handlers (`parse_html_imports` for HTML, and the
`VUE`/`SVELTE`/`ASTRO` case of `cbm_extract_imports`), now running the full
walker set instead of just `walk_es_imports`. Each host file reaches it exactly
once, so embedded scripts are walked once by the full set (imports included).
The JS/TS sub-context has no `embedded_imports` of its own, so
`cbm_extract_imports(&sub)` does not recurse. A parser is created per block (the
sniffed language can differ per `<script>`).

### 3. Sniff `lang="ts"`

The `CBMEmbeddedLangSpec.embedded_language` is the default (JavaScript). At
collect time, inspect the enclosing `script_element`'s `start_tag` attributes;
if a `lang`/`type` attribute value is `ts`/`typescript`, use `CBM_LANG_TYPESCRIPT`
(its grammar, `grammar_typescript.c`, is vendored and already in the
`CBM_LANG_TYPESCRIPT` spec). Otherwise keep the spec default. The chosen language
sets both the parser grammar and `sub.language`.

### 4. Svelte parity

`svelte_embedded_imports` has the identical `{script_element, raw_text, JS}`
shape, so it rides the same generalized routine and the same `lang="ts"` sniff
for free. HTML/Astro also share the shape, but they are **not** AGL-6 targets: to
honor "non-Vue results unchanged," the full-walk is gated to Vue and Svelte
(`full_walk = language ∈ {VUE, SVELTE}`), and HTML/Astro keep the historical
imports-only behavior (`walk_es_imports` over the same included-ranges parse), so
their extraction is byte-for-byte what it was.

## Out of scope

- **Template → handler edges** (`@click="fn"`, `:prop="expr"`): a separate tier.
  Script-side defs/imports/calls/usages satisfy every AGL-6 criterion; template
  binding resolution is not attempted here.
- No change to the `CBM_LANG_VUE`/`CBM_LANG_SVELTE` type arrays themselves — the
  SFC still contributes its `Module`/`File`; the script symbols now come from the
  embedded pass.

## Test plan

Extraction (`tests/test_extraction.c`) and pipeline (`tests/test_pipeline.c`):

1. `<script setup>` symbols (a `function`/`const` def, an `import`, a call) emit
   graph nodes and import/call edges at correct `.vue` file positions.
2. `lang="ts"` block: a TS-only construct (e.g. a typed export) is extracted
   (JS-grammar parse would drop or mis-shape it).
3. A TS export referenced **only** from a `<script setup>` SFC is not flagged
   dead, and its fan-in lists the referencing `.vue` file.
4. Svelte `<script lang="ts">` gets the same treatment.
5. Non-Vue/Svelte results unchanged (a plain JS/TS file's node/edge counts are
   identical before/after); a 212-SFC-scale index completes cleanly.

Verification uses node counts and `trace_path`, **not** `check_index_coverage`
— a `.vue` file records no coverage gap for missing symbols (no `parse_partial`),
so coverage reads clean both before and after and cannot detect the fix.
