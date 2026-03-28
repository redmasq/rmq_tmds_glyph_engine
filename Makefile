SHELL := /usr/bin/bash
BUILD_SYSTEM ?= $(CURDIR)/build_system/build-system.sh
BUILD_SYSTEM_PROJECT_PATH ?= .
BUILD_SYSTEM_ARGS ?=

PROJECT_FILE ?= $(CURDIR)/platform/gowin/boards/tang-nano-20k/tang-nano-20k.gprj
BITSTREAM_FILE ?= $(CURDIR)/platform/gowin/boards/tang-nano-20k/impl/pnr/tang-nano-20k.fs
TANG_PRIMER_PROJECT_FILE ?= $(CURDIR)/platform/gowin/boards/tang-primer-20k/tang-primer-20k.gprj
TANG_PRIMER_BITSTREAM_FILE ?= $(CURDIR)/platform/gowin/boards/tang-primer-20k/impl/pnr/tang-primer-20k.fs
BLINKY_PROJECT_FILE ?= $(CURDIR)/bringup/blinky-tang-nano-20k/blinky-tang-nano-20k.gprj
BLINKY_BITSTREAM_FILE ?= $(CURDIR)/bringup/blinky-tang-nano-20k/impl/pnr/blinky.fs
BLINKY_TANG_PRIMER_PROJECT_FILE ?= $(CURDIR)/bringup/blinky-tang-primer-20k/blinky-tang-primer-20k.gprj
BLINKY_TANG_PRIMER_BITSTREAM_FILE ?= $(CURDIR)/bringup/blinky-tang-primer-20k/impl/pnr/blinky-tang-primer-20k.fs
BLINKY_PUHZI_PART ?= xc7a200tfbg484-2
BLINKY_PUHZI_TOP ?= top
BLINKY_PUHZI_NAME ?= blinky-puhzi-pa200-fl-kfb
BLINKY_PUHZI_IMPL_DIR ?= $(CURDIR)/bringup/blinky-puhzi-pa200-fl-kfb/impl
BLINKY_PUHZI_SOURCE_FILE ?= $(CURDIR)/bringup/blinky-puhzi-pa200-fl-kfb/src/blinky.v
BLINKY_PUHZI_XDC_FILE ?= $(CURDIR)/bringup/blinky-puhzi-pa200-fl-kfb/src/blinky.xdc
BLINKY_PUHZI_BITSTREAM_FILE ?= $(BLINKY_PUHZI_IMPL_DIR)/$(BLINKY_PUHZI_NAME).bit
PUHZI_TMDS_PART ?= xc7a200tfbg484-2
PUHZI_TMDS_TOP ?= top
PUHZI_TMDS_NAME ?= puhzi-pa200-fl-kfb
PUHZI_TMDS_IMPL_DIR ?= $(CURDIR)/platform/artix/boards/puhzi-pa200-fl-kfb/impl
PUHZI_TMDS_XDC_FILE ?= $(CURDIR)/platform/artix/boards/puhzi-pa200-fl-kfb/puhzi-pa200-fl-kfb.xdc
PUHZI_TMDS_BITSTREAM_FILE ?= $(PUHZI_TMDS_IMPL_DIR)/$(PUHZI_TMDS_NAME).bit
VIDEO_MODE ?= 480p
PUHZI_VIDEO_MODE ?= $(VIDEO_MODE)
PUZHI_VIDEO_MODE ?= $(PUHZI_VIDEO_MODE)
GOWIN_VIDEO_MODE ?= $(VIDEO_MODE)
ARTIX_FONT_ROM_SOURCE_FILE ?= $(CURDIR)/platform/artix/generated/artix_cp437_font_rom.v
GOWIN_FONT_ROM_SOURCE_FILE ?= $(CURDIR)/platform/gowin/gowin_prom_cp437_8x16/gowin_prom_cp437_8x16.v
GOWIN_VIDEO_MODE_CONFIG_FILE ?= $(CURDIR)/platform/gowin/generated/video_mode_config.vh
TANG_NANO_SDC_FILE ?= $(CURDIR)/platform/gowin/boards/tang-nano-20k/tang-nano-20k.sdc
TANG_PRIMER_SDC_FILE ?= $(CURDIR)/platform/gowin/boards/tang-primer-20k/tang-primer-20k.sdc
FONT_ROM_GEN_SCRIPT ?= $(CURDIR)/scripts/gen_font_module.py
CP437_GRAPH_SOURCE_FILE ?= $(CURDIR)/third_party/pcface/out/moderndos-8x16/graph.txt
CP437_GRAPH_SOURCE_NOTE ?= PC Face moderndos-8x16 graph.txt (https://github.com/susam/pcface/tree/main/out/moderndos-8x16)
PUHZI_TMDS_MODE_DEFINE := $(if $(filter 720p,$(PUZHI_VIDEO_MODE)),VIDEO_MODE_720P,)
PUHZI_TMDS_VIVADO_DEFINES := USE_ARTIX_GENERATED_FONT_ROM $(PUHZI_TMDS_MODE_DEFINE)
GOWIN_BUILD_ARGS ?=
GOWIN_PROGRAM_ARGS ?=
RUN_PROCESS ?= all
DEVICE ?= GW2AR-18C
TANG_PRIMER_DEVICE ?= GW2A-18C

.PHONY: help lint config menuconfig projectmenu \
	gowin-build gowin-open \
	gowin-program gowin-program-cli gowin-scan-cables gowin-scan-device \
	tang-nano-tmds-open tang-nano-tmds-build tang-nano-tmds-program tang-nano-tmds-program-cli tang-nano-tmds-program-sram tang-nano-tmds-program-flash tang-nano-tmds-deploy-sram tang-nano-tmds-deploy-flash \
	tang-primer-tmds-open tang-primer-tmds-build tang-primer-tmds-program tang-primer-tmds-program-cli tang-primer-tmds-program-sram tang-primer-tmds-program-flash tang-primer-tmds-deploy-sram tang-primer-tmds-deploy-flash \
	puhzi-tmds-open puhzi-tmds-build puhzi-tmds-program puhzi-tmds-deploy \
	tmds-open tmds-build tmds-program tmds-program-cli tmds-program-sram tmds-program-flash tmds-deploy-sram tmds-deploy-flash \
	tang-primer-open tang-primer-build tang-primer-program tang-primer-program-cli tang-primer-program-sram tang-primer-program-flash tang-primer-deploy-sram tang-primer-deploy-flash \
	tang-nano-blinky-open tang-nano-blinky-build tang-nano-blinky-program-sram tang-nano-blinky-program-flash tang-nano-blinky-deploy-sram tang-nano-blinky-deploy-flash \
	tang-primer-blinky-open tang-primer-blinky-build tang-primer-blinky-program-sram tang-primer-blinky-program-flash tang-primer-blinky-deploy-sram tang-primer-blinky-deploy-flash \
	puhzi-blinky-open puhzi-blinky-build puhzi-blinky-program puhzi-blinky-deploy \
	blinky-open blinky-build blinky-program-sram blinky-program-flash blinky-deploy-sram blinky-deploy-flash \
	blinky-primer-open blinky-primer-build blinky-primer-program-sram blinky-primer-program-flash blinky-primer-deploy-sram blinky-primer-deploy-flash \
	FORCE

resources/cp437_8x16.mem resources/cp437_8x16.mi: $(CP437_GRAPH_SOURCE_FILE) $(FONT_ROM_GEN_SCRIPT)
	python3 "$(FONT_ROM_GEN_SCRIPT)" --graph-input "$(CP437_GRAPH_SOURCE_FILE)" \
	  --mem-output "$(CURDIR)/resources/cp437_8x16.mem" \
	  --mi-output "$(CURDIR)/resources/cp437_8x16.mi" \
	  --source-note "$(CP437_GRAPH_SOURCE_NOTE)"

$(ARTIX_FONT_ROM_SOURCE_FILE): resources/cp437_8x16.mem $(FONT_ROM_GEN_SCRIPT)
	python3 "$(FONT_ROM_GEN_SCRIPT)" --format artix --input "$(CURDIR)/resources/cp437_8x16.mem" --output "$(ARTIX_FONT_ROM_SOURCE_FILE)" --module-name artix_cp437_font_rom

$(GOWIN_FONT_ROM_SOURCE_FILE): resources/cp437_8x16.mem $(FONT_ROM_GEN_SCRIPT)
	python3 "$(FONT_ROM_GEN_SCRIPT)" --format gowin --input "$(CURDIR)/resources/cp437_8x16.mem" --output "$(GOWIN_FONT_ROM_SOURCE_FILE)" --module-name Gowin_pROM_cp437_8x16

$(GOWIN_VIDEO_MODE_CONFIG_FILE): FORCE
	@mkdir -p "$(dir $@)"
	@if [ "$(GOWIN_VIDEO_MODE)" = "720p" ]; then \
		printf '\140define VIDEO_MODE_720P\n\140define VIDEO_MODE 1\n' > "$@"; \
	else \
		printf '\140define VIDEO_MODE 0\n' > "$@"; \
	fi

$(TANG_NANO_SDC_FILE): FORCE
	@if [ "$(GOWIN_VIDEO_MODE)" = "720p" ]; then \
		printf '%s\n%s\n%s\n' \
		  'create_clock -name clk_in -period 37.037 [get_ports {clk}]' \
		  'create_clock -name hdmi_clk_5x -period 2.694 [get_pins {hdmi_pll/u_pll/rpll_inst/CLKOUT}]' \
		  'create_clock -name hdmi_clk -period 13.468 [get_pins {u_clkdiv5/CLKOUT}]' > "$@"; \
	else \
		printf '%s\n%s\n%s\n' \
		  'create_clock -name clk_in -period 37.037 [get_ports {clk}]' \
		  'create_clock -name hdmi_clk_5x -period 7.407 [get_pins {hdmi_pll/u_pll/rpll_inst/CLKOUT}]' \
		  'create_clock -name hdmi_clk -period 37.037 [get_pins {u_clkdiv5/CLKOUT}]' > "$@"; \
	fi

$(TANG_PRIMER_SDC_FILE): FORCE
	@if [ "$(GOWIN_VIDEO_MODE)" = "720p" ]; then \
		printf '%s\n%s\n%s\n' \
		  'create_clock -name clk_in -period 37.037 [get_ports {clk}]' \
		  'create_clock -name hdmi_clk_5x -period 2.694 [get_pins {hdmi_pll/u_pll/rpll_inst/CLKOUT}]' \
		  'create_clock -name hdmi_clk -period 13.468 [get_pins {u_clkdiv5/CLKOUT}]' > "$@"; \
	else \
		printf '%s\n%s\n%s\n' \
		  'create_clock -name clk_in -period 37.037 [get_ports {clk}]' \
		  'create_clock -name hdmi_clk_5x -period 7.407 [get_pins {hdmi_pll/u_pll/rpll_inst/CLKOUT}]' \
		  'create_clock -name hdmi_clk -period 37.037 [get_pins {u_clkdiv5/CLKOUT}]' > "$@"; \
	fi

help:
	@printf '%s\n' \
	  'Targets:' \
	  '  make config            Run the prompt-style build-system configuration flow' \
	  '  make menuconfig        Open the build-system Textual configuration menu' \
	  '  make projectmenu       Open the build-system Textual project menu' \
	  '  make lint              Run Verilator lint with Gowin primitive stubs' \
	  '  make tang-nano-tmds-build Build the Tang Nano 20K TMDS project in Gowin batch mode' \
	  '  make tang-nano-tmds-open  Open the Tang Nano 20K TMDS project in Gowin IDE on Windows' \
	  '  make tang-nano-tmds-program-sram Program the Tang Nano 20K TMDS bitstream into SRAM' \
	  '  make tang-nano-tmds-program-flash Program the Tang Nano 20K TMDS bitstream into external flash' \
	  '  make tang-nano-tmds-deploy-sram  Build and then program the Tang Nano 20K TMDS bitstream into SRAM' \
	  '  make tang-nano-tmds-deploy-flash Build and then program the Tang Nano 20K TMDS bitstream into external flash' \
	  '  make tang-primer-tmds-build Build the Tang Primer TMDS project in Gowin batch mode' \
	  '  make tang-primer-tmds-open  Open the Tang Primer TMDS project in Gowin IDE on Windows' \
	  '  make tmds-build        Compatibility alias for make tang-nano-tmds-build' \
	  '  make tang-primer-build Compatibility alias for make tang-primer-tmds-build' \
	  '  make resources/cp437_8x16.mem Regenerate CP437 font assets from third_party/pcface' \
	  '  make tang-nano-blinky-build Build the Tang Nano 20K blinky smoke test' \
	  '  make tang-nano-blinky-program-sram Program the Tang Nano 20K blinky bitstream into SRAM' \
	  '  make tang-primer-blinky-build Build the Tang Primer Dock blinky smoke test' \
	  '  make tang-primer-blinky-program-sram Program the Tang Primer Dock blinky bitstream into SRAM' \
	  '  make puhzi-tmds-build  Build the Puhzi PA200-FL-KFB TMDS project with Vivado batch flow' \
	  '  make puhzi-tmds-open   Open the Puhzi PA200-FL-KFB TMDS project in Vivado Tcl GUI mode' \
	  '  make puhzi-tmds-program Program the Puhzi PA200-FL-KFB TMDS bitstream over JTAG with Vivado' \
	  '  make gowin-build       Alias for make tmds-build' \
	  '  make gowin-open        Alias for make tmds-open' \
	  '  make gowin-program     Open Gowin Programmer GUI on Windows' \
	  '  make gowin-program-cli Invoke programmer_cli.exe with GOWIN_PROGRAM_ARGS' \
	  '  make gowin-scan-cables List available Gowin download cables' \
	  '  make gowin-scan-device Scan chain/devices for DEVICE' \
	  '  make tang-nano-blinky-open Open the Tang Nano 20K bringup blinky project' \
	  '  make tang-nano-blinky-build Invoke Gowin batch shell for Tang Nano 20K bringup blinky' \
	  '  make tang-nano-blinky-program-sram Program Tang Nano 20K blinky.fs into SRAM' \
	  '  make tang-nano-blinky-program-flash Program Tang Nano 20K blinky.fs into external flash' \
	  '  make tang-primer-blinky-open Open the Tang Primer Dock blinky project' \
	  '  make tang-primer-blinky-build Invoke Gowin batch shell for Tang Primer Dock blinky' \
	  '  make tang-primer-blinky-program-sram Program Tang Primer Dock blinky.fs into SRAM' \
	  '  make tang-primer-blinky-program-flash Program Tang Primer Dock blinky.fs into flash' \
	  '  make puhzi-blinky-open  Open the Puhzi PA200-FL-KFB blinky project in Vivado Tcl GUI mode' \
	  '  make puhzi-blinky-build Build the Puhzi PA200-FL-KFB blinky bitstream with Vivado batch flow' \
	  '  make puhzi-blinky-program Program the Puhzi PA200-FL-KFB blinky bitstream over JTAG with Vivado' \
	  '  make tang-nano-blinky-deploy-sram Build and then program Tang Nano 20K blinky.fs into SRAM' \
	  '  make tang-nano-blinky-deploy-flash Build and then program Tang Nano 20K blinky.fs into external flash' \
	  '  make puhzi-blinky-deploy Build and then program the Puhzi blinky bitstream over JTAG' \
	  '  make blinky-build      Compatibility alias for make tang-nano-blinky-build' \
	  '  make blinky-primer-build Compatibility alias for make tang-primer-blinky-build' \
	  '' \
	  'Useful variables:' \
	  '  PROJECT_FILE=<path>    Override the .gprj path' \
	  '  BITSTREAM_FILE=<path>  Override the .fs path used by your own CLI args' \
	  '  DEVICE=<part>          Override the programmer device, default GW2AR-18C' \
	  '  TANG_PRIMER_DEVICE=<part> Override the Tang Primer programmer device, default GW2A-18C' \
	  '  VIVADO_ROOT=<path>     Override the Windows Vivado install root, default /mnt/y/AMDDesignTools/2025.2/Vivado' \
	  '  VIDEO_MODE=480p|720p   Select the TMDS video mode across vendors, default 480p' \
	  '  PUHZI_VIDEO_MODE=480p|720p Compatibility alias for Artix TMDS mode selection' \
	  '  PUZHI_VIDEO_MODE=480p|720p Compatibility alias for the common Puhzi spelling variant' \
	  '  ARTIX_FONT_ROM_SOURCE_FILE=<path> Override the generated Artix CP437 font ROM wrapper path' \
	  '  RUN_PROCESS=all|syn|pnr Select the Gowin batch process for build targets' \
	  '  GOWIN_ROOT=<path>      Override the Windows Gowin install root' \
	  '  GOWIN_BUILD_ARGS=...   Extra args passed to gw_sh.exe' \
	  '  GOWIN_PROGRAM_ARGS=... Extra args passed to programmer_cli.exe' \
	  '  BUILD_SYSTEM_PROJECT_PATH=<path> Pass -p to the build-system config/project menus' \
	  '  BUILD_SYSTEM_ARGS=...  Extra args passed to the build-system launcher'

config:
	"$(BUILD_SYSTEM)" config $(BUILD_SYSTEM_ARGS)

menuconfig:
	"$(BUILD_SYSTEM)" -p "$(BUILD_SYSTEM_PROJECT_PATH)" menuconfig $(BUILD_SYSTEM_ARGS)

projectmenu:
	"$(BUILD_SYSTEM)" -p "$(BUILD_SYSTEM_PROJECT_PATH)" projectmenu $(BUILD_SYSTEM_ARGS)

lint:
	./scripts/lint_verilator.sh

tang-nano-tmds-build: $(GOWIN_FONT_ROM_SOURCE_FILE) $(GOWIN_VIDEO_MODE_CONFIG_FILE) $(TANG_NANO_SDC_FILE)
	./scripts/build_gowin.sh --project "$(PROJECT_FILE)" --process "$(RUN_PROCESS)" -- $(GOWIN_BUILD_ARGS)

tang-nano-tmds-open: $(GOWIN_FONT_ROM_SOURCE_FILE) $(GOWIN_VIDEO_MODE_CONFIG_FILE) $(TANG_NANO_SDC_FILE)
	./scripts/build_gowin.sh --gui --project "$(PROJECT_FILE)"

tang-nano-tmds-program:
	./scripts/program_gowin.sh --gui --bitstream "$(BITSTREAM_FILE)"

tang-nano-tmds-program-cli:
	./scripts/program_gowin.sh --cli --bitstream "$(BITSTREAM_FILE)" -- $(GOWIN_PROGRAM_ARGS)

tang-nano-tmds-program-sram:
	./scripts/program_gowin.sh --sram --device "$(DEVICE)" --bitstream "$(BITSTREAM_FILE)"

tang-nano-tmds-program-flash:
	./scripts/program_gowin.sh --flash --device "$(DEVICE)" --bitstream "$(BITSTREAM_FILE)"

tang-nano-tmds-deploy-sram: tang-nano-tmds-build
	./scripts/program_gowin.sh --sram --device "$(DEVICE)" --bitstream "$(BITSTREAM_FILE)"

tang-nano-tmds-deploy-flash: tang-nano-tmds-build
	./scripts/program_gowin.sh --flash --device "$(DEVICE)" --bitstream "$(BITSTREAM_FILE)"

tang-primer-tmds-build: $(GOWIN_FONT_ROM_SOURCE_FILE) $(GOWIN_VIDEO_MODE_CONFIG_FILE) $(TANG_PRIMER_SDC_FILE)
	./scripts/build_gowin.sh --project "$(TANG_PRIMER_PROJECT_FILE)" --process "$(RUN_PROCESS)" -- $(GOWIN_BUILD_ARGS)

tang-primer-tmds-open: $(GOWIN_FONT_ROM_SOURCE_FILE) $(GOWIN_VIDEO_MODE_CONFIG_FILE) $(TANG_PRIMER_SDC_FILE)
	./scripts/build_gowin.sh --gui --project "$(TANG_PRIMER_PROJECT_FILE)"

tang-primer-tmds-program:
	./scripts/program_gowin.sh --gui --bitstream "$(TANG_PRIMER_BITSTREAM_FILE)"

tang-primer-tmds-program-cli:
	./scripts/program_gowin.sh --cli --bitstream "$(TANG_PRIMER_BITSTREAM_FILE)" -- $(GOWIN_PROGRAM_ARGS)

tang-primer-tmds-program-sram:
	./scripts/program_gowin.sh --sram --device "$(TANG_PRIMER_DEVICE)" --bitstream "$(TANG_PRIMER_BITSTREAM_FILE)"

tang-primer-tmds-program-flash:
	./scripts/program_gowin.sh --flash --device "$(TANG_PRIMER_DEVICE)" --bitstream "$(TANG_PRIMER_BITSTREAM_FILE)"

tang-primer-tmds-deploy-sram: tang-primer-tmds-build
	./scripts/program_gowin.sh --sram --device "$(TANG_PRIMER_DEVICE)" --bitstream "$(TANG_PRIMER_BITSTREAM_FILE)"

tang-primer-tmds-deploy-flash: tang-primer-tmds-build
	./scripts/program_gowin.sh --flash --device "$(TANG_PRIMER_DEVICE)" --bitstream "$(TANG_PRIMER_BITSTREAM_FILE)"

tmds-open: tang-nano-tmds-open

tmds-build: tang-nano-tmds-build

tmds-program: tang-nano-tmds-program

tmds-program-cli: tang-nano-tmds-program-cli

tmds-program-sram: tang-nano-tmds-program-sram

tmds-program-flash: tang-nano-tmds-program-flash

tmds-deploy-sram: tang-nano-tmds-deploy-sram

tmds-deploy-flash: tang-nano-tmds-deploy-flash

tang-primer-open: tang-primer-tmds-open

tang-primer-build: tang-primer-tmds-build

tang-primer-program: tang-primer-tmds-program

tang-primer-program-cli: tang-primer-tmds-program-cli

tang-primer-program-sram: tang-primer-tmds-program-sram

tang-primer-program-flash: tang-primer-tmds-program-flash

tang-primer-deploy-sram: tang-primer-tmds-deploy-sram

tang-primer-deploy-flash: tang-primer-tmds-deploy-flash

gowin-build:
	$(MAKE) tmds-build RUN_PROCESS="$(RUN_PROCESS)" GOWIN_BUILD_ARGS='$(GOWIN_BUILD_ARGS)' PROJECT_FILE="$(PROJECT_FILE)"

gowin-open:
	$(MAKE) tmds-open PROJECT_FILE="$(PROJECT_FILE)"

gowin-program:
	$(MAKE) tmds-program BITSTREAM_FILE="$(BITSTREAM_FILE)"

gowin-program-cli:
	$(MAKE) tmds-program-cli BITSTREAM_FILE="$(BITSTREAM_FILE)" GOWIN_PROGRAM_ARGS='$(GOWIN_PROGRAM_ARGS)'

gowin-scan-cables:
	./scripts/program_gowin.sh --scan-cables --device "$(DEVICE)" --bitstream "$(BITSTREAM_FILE)"

gowin-scan-device:
	./scripts/program_gowin.sh --scan-device --device "$(DEVICE)" --bitstream "$(BITSTREAM_FILE)"

tang-nano-blinky-open:
	./scripts/build_gowin.sh --gui --project "$(BLINKY_PROJECT_FILE)"

tang-nano-blinky-build:
	./scripts/build_gowin.sh --project "$(BLINKY_PROJECT_FILE)" --process "$(RUN_PROCESS)"

tang-nano-blinky-program-sram:
	./scripts/program_gowin.sh --sram --device "$(DEVICE)" --bitstream "$(BLINKY_BITSTREAM_FILE)"

tang-nano-blinky-program-flash:
	./scripts/program_gowin.sh --flash --device "$(DEVICE)" --bitstream "$(BLINKY_BITSTREAM_FILE)"

tang-nano-blinky-deploy-sram: tang-nano-blinky-build
	./scripts/program_gowin.sh --sram --device "$(DEVICE)" --bitstream "$(BLINKY_BITSTREAM_FILE)"

tang-nano-blinky-deploy-flash: tang-nano-blinky-build
	./scripts/program_gowin.sh --flash --device "$(DEVICE)" --bitstream "$(BLINKY_BITSTREAM_FILE)"

tang-primer-blinky-open:
	./scripts/build_gowin.sh --gui --project "$(BLINKY_TANG_PRIMER_PROJECT_FILE)"

tang-primer-blinky-build:
	./scripts/build_gowin.sh --project "$(BLINKY_TANG_PRIMER_PROJECT_FILE)" --process "$(RUN_PROCESS)"

tang-primer-blinky-program-sram:
	./scripts/program_gowin.sh --sram --device "$(TANG_PRIMER_DEVICE)" --bitstream "$(BLINKY_TANG_PRIMER_BITSTREAM_FILE)"

tang-primer-blinky-program-flash:
	./scripts/program_gowin.sh --flash --device "$(TANG_PRIMER_DEVICE)" --bitstream "$(BLINKY_TANG_PRIMER_BITSTREAM_FILE)"

tang-primer-blinky-deploy-sram: tang-primer-blinky-build
	./scripts/program_gowin.sh --sram --device "$(TANG_PRIMER_DEVICE)" --bitstream "$(BLINKY_TANG_PRIMER_BITSTREAM_FILE)"

tang-primer-blinky-deploy-flash: tang-primer-blinky-build
	./scripts/program_gowin.sh --flash --device "$(TANG_PRIMER_DEVICE)" --bitstream "$(BLINKY_TANG_PRIMER_BITSTREAM_FILE)"

puhzi-blinky-open:
	./scripts/build_vivado.sh --gui --name "$(BLINKY_PUHZI_NAME)" --out-dir "$(BLINKY_PUHZI_IMPL_DIR)" --top "$(BLINKY_PUHZI_TOP)" --part "$(BLINKY_PUHZI_PART)" --source "$(BLINKY_PUHZI_SOURCE_FILE)" --xdc "$(BLINKY_PUHZI_XDC_FILE)"

puhzi-blinky-build:
	./scripts/build_vivado.sh --name "$(BLINKY_PUHZI_NAME)" --out-dir "$(BLINKY_PUHZI_IMPL_DIR)" --top "$(BLINKY_PUHZI_TOP)" --part "$(BLINKY_PUHZI_PART)" --source "$(BLINKY_PUHZI_SOURCE_FILE)" --xdc "$(BLINKY_PUHZI_XDC_FILE)"

puhzi-blinky-program:
	./scripts/program_vivado.sh --bitstream "$(BLINKY_PUHZI_BITSTREAM_FILE)"

puhzi-blinky-deploy: puhzi-blinky-build
	./scripts/program_vivado.sh --bitstream "$(BLINKY_PUHZI_BITSTREAM_FILE)"

puhzi-tmds-open: $(ARTIX_FONT_ROM_SOURCE_FILE)
	./scripts/build_vivado.sh --gui --name "$(PUHZI_TMDS_NAME)" --out-dir "$(PUHZI_TMDS_IMPL_DIR)" --top "$(PUHZI_TMDS_TOP)" --part "$(PUHZI_TMDS_PART)" \
		--source "$(CURDIR)/platform/artix/boards/puhzi-pa200-fl-kfb/top.v" \
		--source "$(CURDIR)/platform/artix/artix_video_pll.v" \
		--source "$(CURDIR)/platform/artix/artix_hdmi_phy.v" \
		--source "$(CURDIR)/platform/artix/artix_serializer_10to1.v" \
		--source "$(CURDIR)/platform/artix/pll/artix_pll_480p.v" \
		--source "$(CURDIR)/platform/artix/pll/artix_mmcm_720p.v" \
		--source "$(ARTIX_FONT_ROM_SOURCE_FILE)" \
		--source "$(CURDIR)/core/cp437_font_rom.v" \
		--source "$(CURDIR)/core/display_signal.v" \
		--source "$(CURDIR)/core/text_cell_bram.v" \
		--source "$(CURDIR)/core/text_init_writer.v" \
		--source "$(CURDIR)/core/text_mode_source.v" \
		--source "$(CURDIR)/core/text_plane.v" \
		--source "$(CURDIR)/core/text_snapshot_loader.v" \
		--source "$(CURDIR)/core/tmds_encoder.v" \
		--source "$(CURDIR)/core/vga16_palette.v" \
		--xdc "$(PUHZI_TMDS_XDC_FILE)" \
		$(foreach def,$(PUHZI_TMDS_VIVADO_DEFINES),--define $(def))

puhzi-tmds-build: $(ARTIX_FONT_ROM_SOURCE_FILE)
	./scripts/build_vivado.sh --name "$(PUHZI_TMDS_NAME)" --out-dir "$(PUHZI_TMDS_IMPL_DIR)" --top "$(PUHZI_TMDS_TOP)" --part "$(PUHZI_TMDS_PART)" \
		--source "$(CURDIR)/platform/artix/boards/puhzi-pa200-fl-kfb/top.v" \
		--source "$(CURDIR)/platform/artix/artix_video_pll.v" \
		--source "$(CURDIR)/platform/artix/artix_hdmi_phy.v" \
		--source "$(CURDIR)/platform/artix/artix_serializer_10to1.v" \
		--source "$(CURDIR)/platform/artix/pll/artix_pll_480p.v" \
		--source "$(CURDIR)/platform/artix/pll/artix_mmcm_720p.v" \
		--source "$(ARTIX_FONT_ROM_SOURCE_FILE)" \
		--source "$(CURDIR)/core/cp437_font_rom.v" \
		--source "$(CURDIR)/core/display_signal.v" \
		--source "$(CURDIR)/core/text_cell_bram.v" \
		--source "$(CURDIR)/core/text_init_writer.v" \
		--source "$(CURDIR)/core/text_mode_source.v" \
		--source "$(CURDIR)/core/text_plane.v" \
		--source "$(CURDIR)/core/text_snapshot_loader.v" \
		--source "$(CURDIR)/core/tmds_encoder.v" \
		--source "$(CURDIR)/core/vga16_palette.v" \
		--xdc "$(PUHZI_TMDS_XDC_FILE)" \
		$(foreach def,$(PUHZI_TMDS_VIVADO_DEFINES),--define $(def))

puhzi-tmds-program:
	./scripts/program_vivado.sh --bitstream "$(PUHZI_TMDS_BITSTREAM_FILE)"

puhzi-tmds-deploy: puhzi-tmds-build
	./scripts/program_vivado.sh --bitstream "$(PUHZI_TMDS_BITSTREAM_FILE)"

blinky-open: tang-nano-blinky-open

blinky-build: tang-nano-blinky-build

blinky-program-sram: tang-nano-blinky-program-sram

blinky-program-flash: tang-nano-blinky-program-flash

blinky-deploy-sram: tang-nano-blinky-deploy-sram

blinky-deploy-flash: tang-nano-blinky-deploy-flash

blinky-primer-open: tang-primer-blinky-open

blinky-primer-build: tang-primer-blinky-build

blinky-primer-program-sram: tang-primer-blinky-program-sram

blinky-primer-program-flash: tang-primer-blinky-program-flash

blinky-primer-deploy-sram: tang-primer-blinky-deploy-sram

blinky-primer-deploy-flash: tang-primer-blinky-deploy-flash
