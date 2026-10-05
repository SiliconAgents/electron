# DOCS

`electron.md` is the source and the thing under version control. The PDF is
generated from it and gitignored.

    make docs          # -> DOCS/electron.pdf

That runs ON THE HOST, unlike the rest of the Makefile: the container image has
no pandoc and no PDF tooling. Nor does `pandoc -o x.pdf` work -- it wants a PDF
engine, there is no LaTeX here, and groff is present but without the ms macros
pandoc's roff route needs. The target goes through HTML and LibreOffice, which
is the path that works and the one that keeps tables and code blocks intact.

`style.css` is the stylesheet it uses; edit that to change how the PDF looks.
