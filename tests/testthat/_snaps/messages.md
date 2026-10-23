# argument and handle errors read well

    Code
      pdf_page_text(pdf, pages = 3)
    Condition
      Error in `pdf_page_text()`:
      ! `pages` must be page numbers between 1 and 1, the page count.

---

    Code
      pdf_page_text(pdf)
    Condition
      Error in `pdf_page_text()`:
      ! The PDF file is closed.

# errors from pdfio read well

    Code
      pdf_open(charToRaw("not a pdf at all"))
    Condition
      Error in `pdf_open()`:
      ! Cannot open the PDF file: Unable to open the PDF file.

---

    Code
      pdf_open(fixture("encrypted-rc4-128-pw.pdf"), password = "wrong")
    Condition
      Error in `pdf_open()`:
      ! Cannot open the PDF file: Unable to unlock PDF file.

---

    Code
      pdf_open("no-such-file.pdf")
    Condition
      Error in `pdf_open()`:
      ! Cannot open the PDF file: 'no-such-file.pdf' does not exist.

# limit errors read well

    Code
      pdf_open(minimal_pdf(), max_size = 10)
    Condition
      Error in `pdf_open()`:
      ! The input is larger than `max_size` (10 bytes).

---

    Code
      pdf_stream(pdf, 4)
    Condition
      Error in `pdf_stream()`:
      ! Cannot read the stream of object 4: the stream is larger than `max_stream` (1000 bytes).

---

    Code
      text_of(minimal_pdf(text = strrep("x", 200)), max_stream = 100)
    Condition
      Error in `pdf_page_text()`:
      ! Cannot extract the text: the page's streams, forms and fonts come to more than `max_stream` (100 bytes).

---

    Code
      text_of(deep, max_depth = 1)
    Condition
      Error in `pdf_page_text()`:
      ! Cannot extract the text: the value nests deeper than `max_depth` (1).

---

    Code
      text_of(cycle)
    Condition
      Error in `pdf_page_text()`:
      ! Cannot extract the text: a form XObject draws itself.

# unsupported input and writer errors read well

    Code
      pdf_image(pdf, jpeg, as = "native")
    Condition
      Error in `pdf_image()`:
      ! Only 8-bit RGB or grey images that zupdf can decode convert to a nativeRaster; use `as = "raw"`.

---

    Code
      pdf_font(w, not_font)
    Condition
      Error in `pdf_font()`:
      ! Cannot load the font: Invalid font file.

---

    Code
      pdf_page_new(w)
    Condition
      Error in `pdf_page_new()`:
      ! The writer is closed: pdf_save() has been called.

