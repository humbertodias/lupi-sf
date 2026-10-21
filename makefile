
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
STAGE := $(MAKEFILE_DIR).build/src
CURRENT := $(MAKEFILE_DIR)dist/current
LUPI := $(MAKEFILE_DIR)sf.lupi

SDK := hldtux/lupinho-sdk
WEB := $(MAKEFILE_DIR).build/webgame

.PHONY: game/codec lupi web clean

game/codec:
	rm -rf "$(MAKEFILE_DIR)dist" "$(STAGE)"
	mkdir -p "$(STAGE)/states" "$(STAGE)/sfx"
	cp "$(MAKEFILE_DIR)game.lua" "$(STAGE)/game.lua"
	cp "$(MAKEFILE_DIR)src/"*.lua "$(STAGE)/"
	cp "$(MAKEFILE_DIR)src/states/"*.lua "$(STAGE)/states/"
	mkdir -p "$(STAGE)/sfx"
	cp "$(MAKEFILE_DIR)media/sfx/"*.ogg "$(STAGE)/sfx/"
	cd "$(MAKEFILE_DIR)lupi-codec" && lua run.lua "$(STAGE)" "$(MAKEFILE_DIR)dist"

lupi: game/codec
	mkdir -p "$(CURRENT)/sfx" "$(CURRENT)/states"
	@set -e; \
	manifest="$(CURRENT)/lupi_manifest.txt"; \
	for src in "$(MAKEFILE_DIR)media/sfx/"*.ogg; do \
	  name=$$(basename "$$src"); \
	  cp "$$src" "$(CURRENT)/sfx/$$name"; \
	  if ! grep -q "sfx/$$name " "$$manifest"; then \
	    size=$$(wc -c < "$(CURRENT)/sfx/$$name" | tr -d ' '); \
	    printf '%s %s sfx/%s {"type":"audio"}\n' "$$(date +%s)0000" "$$size" "$$name" >> "$$manifest"; \
	  fi; \
	done
	rm -f "$(LUPI)"
	cd "$(CURRENT)" && zip -r -X "$(LUPI)" .
	cd "$(CURRENT)" && find . \( -name '*.lua' -o -name '*.ogg' -o -name 'lupi_manifest.txt' \) -print | zip -0 -X "$(LUPI)" -@
	@echo "Gerado: $(LUPI)"

web: lupi
	rm -rf "$(WEB)"
	mkdir -p "$(WEB)"
	docker run --rm --entrypoint bash \
		-e HOST_UID="$(shell id -u)" \
		-e HOST_GID="$(shell id -g)" \
		-v "$(LUPI):/game.lupi:ro" \
		-v "$(WEB):/out" \
		-v "$(MAKEFILE_DIR)media/web/fullscreen.css:/fullscreen.css:ro" \
		$(SDK) \
		-lc 'set -eo pipefail; source /opt/emsdk/emsdk_env.sh; set -u; make -C /lupinho/lupinho/src web-game GAME_PATH=/game.lupi; cp -a /lupinho/lupinho/dist/webgame/. /out/; cp /fullscreen.css /out/fullscreen.css; sed -i "s|</head>|<link rel=\"stylesheet\" href=\"fullscreen.css\"></head>|" /out/game.html; cp /out/game.html /out/index.html; touch /out/.nojekyll; chown -R "$$HOST_UID:$$HOST_GID" /out'

clean:
	rm -rf dist .build "$(LUPI)"
