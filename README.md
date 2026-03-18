# spotxcolor Package

**LaTeX: Modern Spot Color Support for the `xcolor` package**

This package provides robust spot color (e.g., DIC, PANTONE) support for the `xcolor` package across all major TeX engines. It resolves structural PDF issues found in the legacy `spotcolor` package and provides full spot color output for all engines including `dvipdfmx` (which is not supported by the `colorspace` package).

 * **Supported major drivers:** `pdftex`, `luatex`, `dvipdfmx` (including `ptex`/`uptex`), `xetex`

## Features

- **Native `xcolor` Integration:** Use spot colors exactly like standard colors (`\textcolor{DIC161!50}{text}`, `\pagecolor{DIC161}`). All standard xcolor commands produce true PDF Separation color space operators on all engines.
- **Universal Engine Compatibility:** Fully supports `pdfLaTeX`, `LuaLaTeX`, `XeLaTeX`, and `(u)pLaTeX + dvipdfmx`.
- **Advanced Graphics Support:** Works flawlessly with complex `TikZ` and `PGF` environments. The package patches PGF driver macros and pattern primitives to emit true spot color PDF operators, fully supporting:
  - Fill and stroke separation (independent spot color operators for fill/stroke).
  - Uncolored patterns (`patterns` and `patterns.meta`) with spot color via `[/Pattern [/Separation ...]]` color spaces.
  - Fadings (transparency masks) and blend modes (e.g., multiply).
- **Decorations:** Seamlessly integrates with `colortbl` (zebra-striped tables) and `tcolorbox` (frames, backgrounds, shadows).

### Limitations

- **Shadings (gradients):** PGF generates Shading dictionary objects with a hardcoded `/DeviceRGB` color space. The color values are frozen into the PDF object at creation time, so spotxcolor cannot intercept them.
- **Non-proportional color mixes** (e.g., `DIC161!80!black`): These produce CMYK values that are not a simple scalar multiple of the base spot color, so they correctly fall back to CMYK.

See `spotxcolor.pdf` for a full feature/limitation summary table.

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

% Define DIC 161
% \definespotcolor{<latex-name>}{<pdf-name>}{<cmyk-values>}
\definespotcolor{DIC161s}{DIC 161s*}{0, 0.64, 1, 0}

\begin{document}
\sffamily\bfseries
% All standard xcolor commands produce true spot color output:
\textcolor{DIC161s}{100\% Spot Color}
\textcolor{DIC161s!50}{50\% Tinted Spot Color}
\pagecolor{DIC161!10}

% Low-level command for direct PDF literal injection:
\SpotColor{DIC161s}{1.0}
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
