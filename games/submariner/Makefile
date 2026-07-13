SDK = $(HOME)/Developer/PlaydateSDK
PDX = Submariner.pdx

build:
	"$(SDK)/bin/pdc" source $(PDX)

run: build
	open -a "$(SDK)/bin/Playdate Simulator.app" $(PDX)

clean:
	rm -rf $(PDX)

.PHONY: build run clean
