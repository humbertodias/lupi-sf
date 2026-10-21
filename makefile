
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
STAGE := $(MAKEFILE_DIR).build/src
CURRENT := $(MAKEFILE_DIR)dist/current
LUPI := $(MAKEFILE_DIR)sf.lupi

SDK := hldtux/lupinho-sdk
WEB := $(MAKEFILE_DIR).build/webgame

# Pacotes de sprite do mesmo jeito que o Reencor: Ryu e Ken saem planos
# (02_Ryu, 11_Ken). Os efeitos ja trazem hitsparks e fireballs, e ficam
# dentro de "22_Ingame Effects".
# nowak.ca e o host do README. justnopoint.com entrega o mesmo zip quando
# nowak.ca nao responde.

.PHONY: assets clean-assets sprites defs game/codec lupi web clean
.DELETE_ON_ERROR:

ASSETS_DIR := Assets/images
CACHE_DIR  := .cache/sprites

RYU_ZIP     := $(CACHE_DIR)/02_Ryu.zip
KEN_ZIP     := $(CACHE_DIR)/11_Ken.zip
EFFECTS_ZIP := $(CACHE_DIR)/22_Ingame_Effects.zip

RYU_DIR     := $(ASSETS_DIR)/02_Ryu
KEN_DIR     := $(ASSETS_DIR)/11_Ken
EFFECTS_DIR := $(ASSETS_DIR)/22_Ingame Effects

assets: $(RYU_DIR)/.stamp $(KEN_DIR)/.stamp $(ASSETS_DIR)/22_Ingame\ Effects/.stamp
	@echo "Sprites em $(ASSETS_DIR)"

$(CACHE_DIR):
	mkdir -p $@

$(RYU_ZIP): URLS := https://www.nowak.ca/zweifuss/all/02_Ryu.zip https://www.justnopoint.com/zweifuss/all/02_Ryu.zip
$(KEN_ZIP): URLS := https://www.nowak.ca/zweifuss/all/11_Ken.zip https://www.justnopoint.com/zweifuss/all/11_Ken.zip
$(EFFECTS_ZIP): URLS := https://www.nowak.ca/zweifuss/all/22_Ingame%20Effects.zip https://www.justnopoint.com/zweifuss/all/22_Ingame%20Effects.zip

$(RYU_ZIP) $(KEN_ZIP) $(EFFECTS_ZIP): | $(CACHE_DIR)
	@set -e; \
	rm -f "$@.partial"; \
	ok=0; \
	for url in $(URLS); do \
		echo "Downloading $$url"; \
		if curl -fL --connect-timeout 8 --max-time 180 \
			-o "$@.partial" "$$url"; then \
			ok=1; \
			break; \
		fi; \
		echo "Failed: $$url"; \
		rm -f "$@.partial"; \
	done; \
	test "$$ok" = 1; \
	mv "$@.partial" "$@"

$(RYU_DIR)/.stamp: $(RYU_ZIP)
	mkdir -p $(RYU_DIR)
	unzip -q -o $< -d $(RYU_DIR)
	test -f $(RYU_DIR)/03286.png
	touch $@

$(KEN_DIR)/.stamp: $(KEN_ZIP)
	mkdir -p $(KEN_DIR)
	unzip -q -o $< -d $(KEN_DIR)
	test -f $(KEN_DIR)/14657.png
	touch $@

$(ASSETS_DIR)/22_Ingame\ Effects/.stamp: $(EFFECTS_ZIP)
	mkdir -p "$(EFFECTS_DIR)"
	unzip -q -o $< -d "$(EFFECTS_DIR)"
	test -f "$(EFFECTS_DIR)/hitsparks/29846.png"
	test -f "$(EFFECTS_DIR)/fireballs/30648.png"
	touch "$@"

clean-assets:
	rm -rf $(RYU_DIR) $(KEN_DIR) "$(EFFECTS_DIR)" $(CACHE_DIR)

sprites:
	python3 "$(MAKEFILE_DIR)tools/pack_sprites.py"
	python3 "$(MAKEFILE_DIR)tools/build_defs.py"

defs:
	python3 "$(MAKEFILE_DIR)tools/build_defs.py"

game/codec: defs
	rm -rf "$(MAKEFILE_DIR)dist" "$(STAGE)"
	mkdir -p "$(STAGE)/states" "$(STAGE)/sfx"
	cp "$(MAKEFILE_DIR)game.lua" "$(STAGE)/game.lua"
	cp "$(MAKEFILE_DIR)src/"*.lua "$(STAGE)/"
	cp "$(MAKEFILE_DIR)src/states/"*.lua "$(STAGE)/states/"
	if [ -d "$(MAKEFILE_DIR)media/img" ]; then cp -R "$(MAKEFILE_DIR)media/img" "$(STAGE)/img"; fi
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
	cd "$(CURRENT)" && find . -type f -print | zip -0 -X "$(LUPI)" -@
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
