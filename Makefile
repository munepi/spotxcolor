SPOTXVER := $(shell awk -F'[{}]' '/ProvidesExplPackage/ {print $$6}' spotxcolor.sty)

# 最終的に生成したい QDF ファイルのリスト
QDF_TARGETS := test-pdftex_$(SPOTXVER).qdf \
               test-luatex_$(SPOTXVER).qdf \
               test-xetex_$(SPOTXVER).qdf \
               test-ptex2pdf_$(SPOTXVER).qdf \
               test-colorspace-pdftex.qdf \
               test-colorspace-luatex.qdf

.PHONY: ctanzip
ctanzip: spotxcolor.zip ## Archive for CTAN upload
spotxcolor.zip: clean spotxcolor.pdf
	git archive --format=tar --prefix=spotxcolor/ HEAD | gtar -x
	## remove unpacked files
	rm -f spotxcolor/.gitignore spotxcolor/Makefile
	## then, now just make archive
	zip -9 -r spotxcolor.zip spotxcolor/*
	rm -rf spotxcolor
	@echo finished

.PHONY: spotxcolor.pdf
spotxcolor.pdf: spotxcolor.tex
	lualatex $<

.PHONY: clean
clean: ## Clean this repository
	rm -rf spotxcolor.zip spotxcolor
	rm -f *.aux *.log *.out *.toc
	rm -f *.qdf test-ptex2pdf* test-colorspace* test_version
	find . -type f -name "*~" -delete

.PHONY: test
test: test_version $(QDF_TARGETS) ## Run test natively in Makefile
	grep -h '^spotxcolor.sty' *.log || true
	@echo "Finished tests for version: $(SPOTXVER)"

test_version: spotxcolor.sty
	awk -F'[{}]' '/ProvidesExplPackage/ {gsub(/-/, "/", $$4); print "Testing:", $$2, $$4, "v"$$6}' $< > $@

test-ptex2pdf.tex: test.tex
	sed -e 's,\documentclass{article},\documentclass[dvipdfmx]{article},' $< > $@

test-colorspace.tex: test.tex
	sed -e 's,\IfFileExists{test_version}{\input{test_version}}\relax,,' \
	    -e 's,\usepackage{spotxcolor},\usepackage{colorspace},' \
	    -e 's,\SpotColor{DIC161s}{1.0},,g' \
	    -e 's,\SpotColor{DIC161s}{0.5},,' \
	    -e 's,\SpotColor{DIC161s}{0.25},,' \
	    $< > $@

test-pdftex.pdf: test.tex test_version spotxcolor.sty
	pdflatex -jobname=test-pdftex $<

test-luatex.pdf: test.tex test_version spotxcolor.sty
	lualatex -jobname=test-luatex $<

test-xetex.pdf: test.tex test_version spotxcolor.sty
	xelatex -jobname=test-xetex $<

test-ptex2pdf.pdf: test-ptex2pdf.tex test_version spotxcolor.sty
	ptex2pdf -l -u $<

test-colorspace-pdftex.pdf: test-colorspace.tex
	pdflatex -jobname=test-colorspace-pdftex $< || true

test-colorspace-luatex.pdf: test-colorspace.tex
	lualatex -jobname=test-colorspace-luatex $< || true

%_$(SPOTXVER).qdf: %.pdf
	qpdf --qdf $< $@

test-colorspace-%.qdf: test-colorspace-%.pdf
	qpdf --qdf $< $@
