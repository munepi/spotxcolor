spotxcolor.pdf: spotxcolor.tex
	lualatex spotxcolor

.PHONY: ctanzip
ctanzip: spotxcolor.zip ## Archive for CTAN upload
spotxcolor.zip: clean
	git archive --format=tar --prefix=spotxcolor/ HEAD | gtar -x

	## remove unpacked files
	rm -f spotxcolor/.gitignore spotxcolor/Makefile

	## then, now just make archive
	zip -9 -r spotxcolor.zip spotxcolor/*

	rm -rf spotxcolor
	@echo finished

.PHONY: clean
clean: ## Clean this repository
	rm -rf spotxcolor.zip spotxcolor
	rm -f *.aux *.log *.out *.toc *.pdf
	find . -type f -name "*~" -delete
