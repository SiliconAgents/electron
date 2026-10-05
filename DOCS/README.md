# DOCS

`electron.md` is the source; `electron.pdf` is generated from it.

To regenerate after editing the markdown (on the host — the container has no
PDF tooling):

    pandoc -s --metadata title="Electron" --toc --toc-depth=2 \
      -c DOCS/style.css --self-contained DOCS/electron.md -o /tmp/electron.html
    libreoffice --headless --convert-to pdf --outdir /tmp /tmp/electron.html
    cp /tmp/electron.pdf DOCS/electron.pdf

There is no LaTeX on this machine, so the usual `pandoc -o x.pdf` route does
not work; it needs a PDF engine it does not have. The HTML-then-LibreOffice
path is the one that does, and it keeps tables and code blocks intact.
