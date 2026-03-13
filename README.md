# spotxcolor Package

**LaTeX: Modern Spot Color Support for the `xcolor` package**

This package provides robust spot color (e.g., DIC, PANTONE) support for the `xcolor` package across all major TeX engines. It resolves structural PDF issues found in the legacy `spotcolor` package and provides an explicit fallback mechanism for `dvipdfmx` (which is not fully supported by the `colorspace` package).

 * **Supported major drivers:** `pdftex`, `luatex`, `dvipdfmx` (including `ptex`/`uptex`), `xetex`

## Features

- **Native `xcolor` Integration:** Use spot colors exactly like standard colors (`\textcolor{DIC161!50}{text}`, `\pagecolor{DIC161}`).
- **Universal Engine Compatibility:** Fully supports `pdfLaTeX`, `LuaLaTeX`, `XeLaTeX`, and `(u)pLaTeX + dvipdfmx`.
- **Advanced Graphics Support:** Works flawlessly with complex `TikZ` and `PGF` environments. The package patches PGF internally to ensure print safety, fully supporting:
  - Fill and stroke separation.
  - Uncolored patterns and modern `patterns.meta` (safely forced to CMYK instead of PGF's hardcoded RGB).
  - Fadings (transparency masks) and shadings (gradients).
  - Blend modes (e.g., multiply).
- **Decorations:** Seamlessly integrates with `colortbl` (zebra-striped tables) and `tcolorbox` (frames, backgrounds, shadows).

## Requirements

 * A modern [TeX Live](https://www.tug.org/texlive/) environment (requires an up-to-date `expl3`/`l3kernel`)
 * `xcolor` and `iftex` packages

<!-- Because we need `\tl_replace_all:Nnx` in `expl3`, spotxcolor v0.14 currently supports TeX Live 2023 frozen up to TeX Live 2026 current. -->

## Installation

Copy `spotxcolor.sty` to your local TeX tree:
`$TEXMF/tex/latex/spotxcolor/`

## Usage

Load the `spotxcolor` package. It will automatically load `xcolor` and detect your engine driver.

```latex
\usepackage{spotxcolor}

% Define DIC 161
% \definespotcolor{<latex-name>}{<pdf-name>}{<cmyk-values>}
\definespotcolor{DIC161}{DIC 161s*}{0, 0.64, 1, 0}

\begin{document}
\sffamily\bfseries
% Native xcolor interface (CMYK fallback safely applied in dvipdfmx)
\textcolor{DIC161}{100\% Spot Color}
\textcolor{DIC161!50}{50\% Tinted Spot Color}

% Explicit spot color interface (Force true spot color in dvipdfmx)
\SpotColor{DIC161}{1.0}
This is 100% DIC 161.
\end{document}
```

### Note for `(u)pLaTeX` users
If you compile your document with `platex` or `uplatex` and generate a PDF via `dvipdfmx`, you **must** specify the `dvipdfmx` driver option globally in your document class (e.g., `\documentclass[dvipdfmx]{article}`). Otherwise, modern `expl3` and `xcolor` will default to the `dvips` driver, and the spot colors will not be generated correctly.

## Backward Compatibility
You can easily reuse your existing code and color dictionaries written for the legacy `spotcolor` package. Commands like `\AddSpotColor`, `\NewSpotColorSpace`, and `\SetPageColorSpace` are perfectly emulated.

## License

This package is licensed under the conditions of the LaTeX Project Public License, either version 1.3c of this license or any later version.

--------------------

Munehiro Yamamoto
[https://github.com/munepi](https://github.com/munepi)
