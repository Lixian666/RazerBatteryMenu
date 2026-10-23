.PHONY: test build dmg preview clean

test:
	bash scripts/test.sh

build:
	bash scripts/build.sh

dmg: build
	bash scripts/package-dmg.sh

preview: build
	./dist/RazerBatteryMenu.app/Contents/MacOS/RazerBatteryMenu --render-previews ./screenshots

clean:
	rm -rf .build dist
