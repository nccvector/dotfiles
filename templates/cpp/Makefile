# make run | make release | make run PRESET=release
.DEFAULT_GOAL := build
PRESET ?= debug
CLANG_TIDY ?= clang-tidy
ARGS ?=

ifeq ($(PRESET),debug)
BUILD_DIR := builds/debug
else ifeq ($(PRESET),release)
BUILD_DIR := build/release
else
$(error PRESET must be debug or release)
endif

.PHONY: configure build run debug release clean lint
configure:
	cmake --preset $(PRESET)

build: configure
	cmake --build --preset $(PRESET)

run: build
	./$(BUILD_DIR)/demo $(ARGS)

debug:
	$(MAKE) build PRESET=debug

release:
	$(MAKE) build PRESET=release

# Clean compiled outputs for the selected preset; retain the CMake cache.
clean:
	cmake --build --preset $(PRESET) --target clean

# Analyze every demo source using the selected compiler database.
lint: configure
	$(CLANG_TIDY) -p $(BUILD_DIR) src/*.cpp
