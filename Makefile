.PHONY: build run clean dmg

build:
	@chmod +x build.sh && ./build.sh

run: build
	@open /Applications/ClamKeep.app

dmg: build
	@chmod +x dmg.sh && ./dmg.sh

clean:
	@rm -rf build
	@rm -f Resources/AppIcon.icns
	@rm -f Resources/icon_1024x1024.png
	@echo "Очистка завершена"
