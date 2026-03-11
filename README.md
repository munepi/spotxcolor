# spotxcolor Package

**LaTeX: Modern Spot Color Support for the `xcolor` package**

This package provides robust spot color (e.g., DIC, PANTONE) support for the `xcolor` package across all major TeX engines. It resolves structural PDF issues found in the legacy `spotcolor` package and provides an explicit fallback mechanism for `dvipdfmx` (which is not fully supported by the `colorspace` package).

 * **Supported major drivers:** `pdftex`, `luatex`, `dvipdfmx` (including `ptex`/`uptex`), `xetex`

## Requirements

 * A modern [TeX Live](https://www.tug.org/texlive/) environment (requires an up-to-date `expl3`/`l3kernel`)
 * `xcolor` and `iftex` packages

## Installation

Copy `spotxcolor.sty` to your local TeX tree:
`$TEXMF/tex/latex/spotxcolor/`

## Usage

Load the `spotxcolor` package. It will automatically load `xcolor` and detect your engine driver.

```latex
\usepackage{spotxcolor}

% \definespotcolor{<latex-name>}{<pdf-name>}{<cmyk-values>}
\definespotcolor{DIC161}{DIC 161s*}{0, 0.64, 1, 0}

\begin{document}
\sffamily\bfseries
% Native xcolor interface (CMYK fallback safely applied in dvipdfmx)
\textcolor{DIC161}{This is DIC 161}

% Explicit spot color interface (Force true spot color in dvipdfmx)
\SpotColor{DIC161}{1.0}
This is 100% DIC 161
\end{document}
```

### Note for `(u)pLaTeX` users
If you compile your document with `platex` or `uplatex` and generate a PDF via `dvipdfmx`, you **must** specify the `dvipdfmx` driver option globally in your document class (e.g., `\documentclass[dvipdfmx]{article}`). Otherwise, modern `expl3` and `xcolor` will default to the `dvips` driver, and the spot colors will not be generated correctly.

## Backward Compatibility
You can easily reuse your existing code and color dictionaries written for the legacy `spotcolor` package. Commands like `\AddSpotColor`, `\NewSpotColorSpace`, and `\SetPageColorSpace` are perfectly emulated.

## License

This package is licensed under the terms of the MIT License.

--------------------

Munehiro Yamamoto
[https://github.com/munepi](https://github.com/munepi)
