# Introduction

<p class="doc-lead">SparkUI is a refined, token-driven ArkTS component library for HarmonyOS — the shadcn-vue experience, native to ArkUI, with an adaptive layout system for phones, foldables, tablets and 2-in-1s.</p>

- **Baseline**: HarmonyOS API 22, ArkUI State Management V2 (`@ComponentV2` / `@Param` / `@Event` / `@Local`).
- **Naming**: every component has an `S` prefix; drop it and you have the shadcn-vue name: `SButton`, `SCard` / `SCardHeader`, `STabsList`…
- **Theming**: colours, radii, spacing, shadows and motion all come from tokens; shadcn / tweakcn theme CSS loads as-is.
- **Responsive**: no breakpoints to learn — components lay themselves out in the space they actually get.

## Principles

| Feature | What it means |
| --- | --- |
| Tokens all the way down | Paste a shadcn / tweakcn theme. oklch, hsl, rgb and hex are converted precisely; switch at runtime. |
| One context, every device | Width / height classes, fold posture and input modality drive component decisions. |
| Beautiful by default | Every part is styled out of the box and still overridable with `AttributeModifier` or component tokens (`tokens` param). |

## Differences from shadcn-vue

ArkTS has a few compile-time rules for custom components; SparkUI renames consistently:

| shadcn prop / idiom | SparkUI | Why |
| --- | --- | --- |
| `size` | `sizing` | may not shadow a universal attribute |
| `align` | `alignment` | same |
| `id` | `inputId` | same |
| `@click` | native `.onClick()` on the component | disabled components swallow the tap internally |
| `v-model` | `checked: this.on!!` / `value: this.v!!` | V2 `!!` two-way binding |
| `<Comp>…</Comp>` | `SComp() { … }` | trailing-closure slot |

Also: a component used with a trailing-closure slot cannot be followed by chained attributes, and the root of an `@Entry` page must be a system container — write pages as `Stack() { SparkProvider() { … } }`.

## About these docs

- Component pages are generated from the gallery app (`gallery/`) and the library sources: examples are the gallery's `DemoBlock` code, API tables come from the `@Param` / `@Event` / `@BuilderParam` declarations.
- Every example has an **approximate web preview** — toggle light/dark, copy the code or edit it in the [playground](/en/playground). The preview cannot reproduce ArkUI rendering 100%; see [Web Previewer](/en/guide/previewer).

Next: [Installation](/en/guide/installation).
