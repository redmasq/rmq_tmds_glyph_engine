SHELL := /usr/bin/bash

PROJECT_FILE ?= $(CURDIR)/platform/gowin/boards/tang-nano-20k/tang-nano-20k.gprj
BITSTREAM_FILE ?= $(CURDIR)/platform/gowin/boards/tang-nano-20k/impl/pnr/tang-nano-20k.fs
BLINKY_PROJECT_FILE ?= $(CURDIR)/bringup/blinky/blinky.gprj
BLINKY_BITSTREAM_FILE ?= $(CURDIR)/bringup/blinky/impl/pnr/blinky.fs
GOWIN_BUILD_ARGS ?=
GOWIN_PROGRAM_ARGS ?=
RUN_PROCESS ?= all
DEVICE ?= GW2AR-18C

.PHONY: help lint \
	gowin-build gowin-open gowin-probe gowin-run-probe \
	gowin-program gowin-program-cli gowin-program-probe gowin-scan-cables gowin-scan-device \
	tmds-open tmds-build tmds-probe tmds-run-probe tmds-program tmds-program-cli tmds-program-sram tmds-program-flash tmds-deploy-sram tmds-deploy-flash \
	blinky-open blinky-build blinky-probe blinky-run-probe blinky-program-sram blinky-program-flash blinky-deploy-sram blinky-deploy-flash

help:
	@printf '%s\n' \
	  'Targets:' \
	  '  make lint              Run Verilator lint with Gowin primitive stubs' \
	  '  make tmds-build        Build the main TMDS project in Gowin batch mode' \
	  '  make tmds-open         Open the main TMDS project in Gowin IDE on Windows' \
	  '  make tmds-program-sram Program the main TMDS bitstream into SRAM' \
	  '  make tmds-program-flash Program the main TMDS bitstream into external flash' \
	  '  make tmds-deploy-sram  Build and then program the main TMDS bitstream into SRAM' \
	  '  make tmds-deploy-flash Build and then program the main TMDS bitstream into external flash' \
	  '  make gowin-build       Alias for make tmds-build' \
	  '  make gowin-open        Alias for make tmds-open' \
	  '  make gowin-probe       Probe the gw_sh Tcl environment and print commands' \
	  '  make gowin-run-probe   Open project in gw_sh and probe run command behavior' \
	  '  make gowin-program     Open Gowin Programmer GUI on Windows' \
	  '  make gowin-program-cli Invoke programmer_cli.exe with GOWIN_PROGRAM_ARGS' \
	  '  make gowin-program-probe Print programmer_cli.exe help text' \
	  '  make gowin-scan-cables List available Gowin download cables' \
	  '  make gowin-scan-device Scan chain/devices for DEVICE' \
	  '  make blinky-open       Open the standalone bringup blinky project' \
	  '  make blinky-build      Invoke Gowin batch shell for bringup blinky' \
	  '  make blinky-probe      Probe the gw_sh Tcl environment on blinky' \
	  '  make blinky-run-probe  Open blinky in gw_sh and probe run behavior' \
	  '  make blinky-program-sram Program blinky.fs into SRAM' \
	  '  make blinky-program-flash Program blinky.fs into external flash' \
	  '  make blinky-deploy-sram Build and then program blinky.fs into SRAM' \
	  '  make blinky-deploy-flash Build and then program blinky.fs into external flash' \
	  '' \
	  'Useful variables:' \
	  '  PROJECT_FILE=<path>    Override the .gprj path' \
	  '  BITSTREAM_FILE=<path>  Override the .fs path used by your own CLI args' \
	  '  DEVICE=<part>          Override the programmer device, default GW2AR-18C' \
	  '  RUN_PROCESS=all|syn|pnr Select the Gowin batch process for build targets' \
	  '  GOWIN_ROOT=<path>      Override the Windows Gowin install root' \
	  '  GOWIN_BUILD_ARGS=...   Extra args passed to gw_sh.exe' \
	  '  GOWIN_PROGRAM_ARGS=... Extra args passed to programmer_cli.exe'

lint:
	./scripts/lint_verilator.sh

tmds-build:
	./scripts/build_gowin.sh --project "$(PROJECT_FILE)" --process "$(RUN_PROCESS)" -- $(GOWIN_BUILD_ARGS)

tmds-open:
	./scripts/build_gowin.sh --gui --project "$(PROJECT_FILE)"

tmds-probe:
	./scripts/build_gowin.sh --probe --project "$(PROJECT_FILE)"

tmds-run-probe:
	./scripts/build_gowin.sh --probe-run --project "$(PROJECT_FILE)"

tmds-program:
	./scripts/program_gowin.sh --gui --bitstream "$(BITSTREAM_FILE)"

tmds-program-cli:
	./scripts/program_gowin.sh --cli --bitstream "$(BITSTREAM_FILE)" -- $(GOWIN_PROGRAM_ARGS)

tmds-program-sram:
	./scripts/program_gowin.sh --sram --device "$(DEVICE)" --bitstream "$(BITSTREAM_FILE)"

tmds-program-flash:
	./scripts/program_gowin.sh --flash --device "$(DEVICE)" --bitstream "$(BITSTREAM_FILE)"

tmds-deploy-sram: tmds-build
	./scripts/program_gowin.sh --sram --device "$(DEVICE)" --bitstream "$(BITSTREAM_FILE)"

tmds-deploy-flash: tmds-build
	./scripts/program_gowin.sh --flash --device "$(DEVICE)" --bitstream "$(BITSTREAM_FILE)"

gowin-build:
	$(MAKE) tmds-build RUN_PROCESS="$(RUN_PROCESS)" GOWIN_BUILD_ARGS='$(GOWIN_BUILD_ARGS)' PROJECT_FILE="$(PROJECT_FILE)"

gowin-open:
	$(MAKE) tmds-open PROJECT_FILE="$(PROJECT_FILE)"

gowin-probe:
	$(MAKE) tmds-probe PROJECT_FILE="$(PROJECT_FILE)"

gowin-run-probe:
	$(MAKE) tmds-run-probe PROJECT_FILE="$(PROJECT_FILE)"

gowin-program:
	$(MAKE) tmds-program BITSTREAM_FILE="$(BITSTREAM_FILE)"

gowin-program-cli:
	$(MAKE) tmds-program-cli BITSTREAM_FILE="$(BITSTREAM_FILE)" GOWIN_PROGRAM_ARGS='$(GOWIN_PROGRAM_ARGS)'

gowin-program-probe:
	./scripts/program_gowin.sh --probe --bitstream "$(BITSTREAM_FILE)"

gowin-scan-cables:
	./scripts/program_gowin.sh --scan-cables --device "$(DEVICE)" --bitstream "$(BITSTREAM_FILE)"

gowin-scan-device:
	./scripts/program_gowin.sh --scan-device --device "$(DEVICE)" --bitstream "$(BITSTREAM_FILE)"

blinky-open:
	./scripts/build_gowin.sh --gui --project "$(BLINKY_PROJECT_FILE)"

blinky-build:
	./scripts/build_gowin.sh --project "$(BLINKY_PROJECT_FILE)" --process "$(RUN_PROCESS)"

blinky-probe:
	./scripts/build_gowin.sh --probe --project "$(BLINKY_PROJECT_FILE)"

blinky-run-probe:
	./scripts/build_gowin.sh --probe-run --project "$(BLINKY_PROJECT_FILE)"

blinky-program-sram:
	./scripts/program_gowin.sh --sram --device "$(DEVICE)" --bitstream "$(BLINKY_BITSTREAM_FILE)"

blinky-program-flash:
	./scripts/program_gowin.sh --flash --device "$(DEVICE)" --bitstream "$(BLINKY_BITSTREAM_FILE)"

blinky-deploy-sram: blinky-build
	./scripts/program_gowin.sh --sram --device "$(DEVICE)" --bitstream "$(BLINKY_BITSTREAM_FILE)"

blinky-deploy-flash: blinky-build
	./scripts/program_gowin.sh --flash --device "$(DEVICE)" --bitstream "$(BLINKY_BITSTREAM_FILE)"
