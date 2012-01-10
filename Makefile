all: build upload

clean:
	rm -rf _build

build:
	run-rstblog build

serve:
	run-rstblog serve

upload:
	rsync -a _build/ immersedcode.org:/var/www/immersedcode.org/
	@echo "Done..."
