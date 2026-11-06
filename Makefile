.PHONY: build run clean dmg

build:
	@chmod +x build.sh && ./build.sh

run: build
	@open /Applications/ClamKeep.app

dmg: build
	@chmod +x dmg.sh && ./dmg.sh

clean:
	@rm -rf build
	@echo "Очистка завершена"
