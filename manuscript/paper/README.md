# Manuscript source

`main.tex` is the canonical cTSEMO manuscript source mirrored in this
standalone repository. Its external figures are referenced directly from the
curated artifact directories, avoiding duplicate image copies.

Compile from this directory:

```powershell
latexmk -pdf main.tex
```

The publisher-style journal, DOI, date, and copyright placeholders are
intentional pre-publication metadata. LaTeX build products and `main.pdf` are
ignored by Git.
