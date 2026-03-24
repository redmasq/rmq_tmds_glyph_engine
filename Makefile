SHELL := /usr/bin/bash

PROJECT_FILE ?= $(CURDIR)/platform/gowin/boards/tang-nano-20k/tang-nano-20k.gprj
BITSTREAM_FILE ?= $(CURDIR)/platform/gowin/boards/tang-nano-20k/impl/pnr/tang-nano-20k.fs
TANG_PRIMER_PROJECT_FILE ?= $(CURDIR)/platform/gowin/boards/tang-primer-20k/tang-primer-20k.gprj
TANG_PRIMER_BITSTREAM_FILE ?= $(CURDIR)/platform/gowin/boards/tang-primer-20k/impl/pnr/tang-primer-20k.fs
BLINKY_PROJECT_FILE ?= $(CURDIR)/bringup/blinky-tang-nano-20k/blinky-tang-nano-20k.gprj
BLINKY_BITSTREAM_FILE ?= $(CURDIR)/bringup/blinky-tang-nano-20k/impl/pnr/blinky.fs
BLINKY_TANG_PRIMER_PROJECT_FILE ?= $(CURDIR)/bringup/blinky-tang-primer-20k/blinky-tang-primer-20k.gprj
BLINKY_TANG_PRIMER_BITSTREAM_FILE ?= $(CURDIR)/bringup/blinky-tang-primer-20k/impl/pnr/blinky-tang-primer-20k.fs
GOWIN_BUILD_ARGS ?=
GOWIN_PROGRAM_ARGS ?=
RUN_PROCESS ?= all
DEVICE ?= GW2AR-18C
TANG_PRIMER_DEVICE ?= GW2A-18C

.PHONY: help lint \
	gowin-build gowin-open \
	gowin-program gowin-program-cli gowin-scan-cables gowin-scan-device \
	tang-nano-tmds-open tang-nano-tmds-build tang-nano-tmds-program tang-nano-tmds-program-cli tang-nano-tmds-program-sram tang-nano-tmds-program-flash tang-nano-tmds-deploy-sram tang-nano-tmds-deploy-flash \
	tang-primer-tmds-open tang-primer-tmds-build tang-primer-tmds-program tang-primer-tmds-program-cli tang-primer-tmds-program-sram tang-primer-tmds-program-flash tang-primer-tmds-deploy-sram tang-primer-tmds-deploy-flash \
	tmds-open tmds-build tmds-program tmds-program-cli tmds-program-sram tmds-program-flash tmds-deploy-sram tmds-deploy-flash \
	tang-primer-open tang-primer-build tang-primer-program tang-primer-program-cli tang-primer-program-sram tang-primer-program-flash tang-primer-deploy-sram tang-primer-deploy-flash \
	tang-nano-blinky-open tang-nano-blinky-build tang-nano-blinky-program-sram tang-nano-blinky-program-flash tang-nano-blinky-deploy-sram tang-nano-blinky-deploy-flash \
	tang-primer-blinky-open tang-primer-blinky-build tang-primer-blinky-program-sram tang-primer-blinky-program-flash tang-primer-blinky-deploy-sram tang-primer-blinky-deploy-flash \
	blinky-open blinky-build blinky-program-sram blinky-program-flash blinky-deploy-sram blinky-deploy-flash \
	blinky-primer-open blinky-primer-build blinky-primer-program-sram blinky-primer-program-flash blinky-primer-deploy-sram blinky-primer-deploy-flash

help:
	@printf '%s\n' \
	  'Targets:' \
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
	  '  make tang-nano-blinky-build Build the Tang Nano 20K blinky smoke test' \
	  '  make tang-nano-blinky-program-sram Program the Tang Nano 20K blinky bitstream into SRAM' \
	  '  make tang-primer-blinky-build Build the Tang Primer Dock blinky smoke test' \
	  '  make tang-primer-blinky-program-sram Program the Tang Primer Dock blinky bitstream into SRAM' \
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
	  '  make tang-nano-blinky-deploy-sram Build and then program Tang Nano 20K blinky.fs into SRAM' \
	  '  make tang-nano-blinky-deploy-flash Build and then program Tang Nano 20K blinky.fs into external flash' \
	  '  make blinky-build      Compatibility alias for make tang-nano-blinky-build' \
	  '  make blinky-primer-build Compatibility alias for make tang-primer-blinky-build' \
	  '' \
	  'Useful variables:' \
	  '  PROJECT_FILE=<path>    Override the .gprj path' \
	  '  BITSTREAM_FILE=<path>  Override the .fs path used by your own CLI args' \
	  '  DEVICE=<part>          Override the programmer device, default GW2AR-18C' \
	  '  TANG_PRIMER_DEVICE=<part> Override the Tang Primer programmer device, default GW2A-18C' \
	  '  RUN_PROCESS=all|syn|pnr Select the Gowin batch process for build targets' \
	  '  GOWIN_ROOT=<path>      Override the Windows Gowin install root' \
	  '  GOWIN_BUILD_ARGS=...   Extra args passed to gw_sh.exe' \
	  '  GOWIN_PROGRAM_ARGS=... Extra args passed to programmer_cli.exe'

lint:
	./scripts/lint_verilator.sh

tang-nano-tmds-build:
	./scripts/build_gowin.sh --project "$(PROJECT_FILE)" --process "$(RUN_PROCESS)" -- $(GOWIN_BUILD_ARGS)

tang-nano-tmds-open:
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

tang-primer-tmds-build:
	./scripts/build_gowin.sh --project "$(TANG_PRIMER_PROJECT_FILE)" --process "$(RUN_PROCESS)" -- $(GOWIN_BUILD_ARGS)

tang-primer-tmds-open:
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
