# Native UI And Golden Artifacts

## Purpose

Use this workflow for C/C++ changes that affect native UI, terminal rendering, image/video output, fonts, CAD/game scenes, charts, maps, OpenGL/Vulkan/Metal/DirectX surfaces, Skia/Cairo/Qt/GTK/wx/SDL/imgui rendering, printer/PDF output, or any artifact where "looks right" is part of correctness.

## Golden Scope

Before editing, define the render matrix:

- Viewport/window sizes and aspect ratios.
- DPI or scale factors.
- Font stack, font rendering backend, locale, and text direction.
- Color mode, theme, gamma/color profile, transparency, and antialiasing settings.
- CPU/GPU backend, driver/platform, and software-rendering fallback when available.
- Input state: focus, hover, selection, caret, animation frame, seed, time, and loaded assets.

If any value is nondeterministic, freeze it or record that the golden is weaker evidence.

## Capture Workflow

1. Capture a baseline artifact before the change when the existing behavior matters.
2. Capture the same scene after the change with the same seed, time, viewport, scale, fonts, and platform.
3. Compare with the project-approved tool. Good options include exact pixel diff for deterministic output, perceptual diff for antialiasing-tolerant UI, text snapshot for terminal output, and geometry/layout assertions for CAD or scene graphs.
4. Inspect failures manually. Anti-aliased edge noise is different from clipped text, overdraw, broken z-order, missing glyphs, off-by-one layout, color regression, or frame jitter.
5. Store accepted artifacts only in the project-approved test/golden location. Do not leave ad hoc captures in random temporary paths.

## Acceptance Rules

- Text must not clip, overlap, wrap unintentionally, or disappear at any supported scale.
- Interactive states must have captured coverage when touched: disabled, hover, active, focus, selected, error, loading, and high-contrast where supported.
- Animation/video evidence must include the representative frame or frame range, not just the first frame.
- Terminal UI evidence must include terminal size, color mode, locale, and whether ANSI escape sequences are normalized.
- A threshold is a contract. Keep it narrow and explain why it is safe.

## Report Template

Include this in the gate report:

```text
Golden artifacts:
- Surface:
- Matrix:
- Baseline:
- Candidate:
- Diff command:
- Threshold:
- Result:
- Manual inspection notes:
- Accepted artifact path:
```

Do not claim "pixel perfect" unless the captured matrix covers the user-visible contract.
