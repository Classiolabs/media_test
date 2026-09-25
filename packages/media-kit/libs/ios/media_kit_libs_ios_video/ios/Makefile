# Uses the local AES-ECB libmpv build in prebuilt/ (no download).
all: Frameworks/.symlinks

PREBUILT := $(firstword $(wildcard prebuilt/*.tar.gz))

SED=sed
SED_INPLACE_FLAG := $(shell ${SED} --version 2>&1 | grep -q 'GNU' && echo "" || echo "''")

Frameworks/.extracted: $(PREBUILT)
	@test -n "$(PREBUILT)" || (echo "ERROR: put the libmpv tar.gz in prebuilt/" && exit 1)
	mkdir -p Frameworks
	rm -rf Frameworks/*.xcframework
	tar -xzf $(PREBUILT) --strip-components 1 -C Frameworks
	touch Frameworks/.extracted

Frameworks/.symlinks: Frameworks/.extracted
	rm -rf Frameworks/.symlinks
	mkdir -p Frameworks/.symlinks/mpv
	${SED} -i ${SED_INPLACE_FLAG} 's/\\r$$//g' create_framework_symlinks.sh
	sh create_framework_symlinks.sh Frameworks/Mpv.xcframework Frameworks/.symlinks/mpv

.PHONY: clean
clean:
	rm -rf Frameworks
