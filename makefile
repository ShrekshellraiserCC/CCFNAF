# Convert processed assets (.png and .gif) to BIMG format
PROCESSED_ASSETS := $(wildcard processed/*.png processed/*.gif processed/*.wav)
BIMG_OUTPUTS := $(patsubst processed/%,%,$(PROCESSED_ASSETS))
BIMG_OUTPUTS := $(patsubst %.png,converted/%.bimg,$(BIMG_OUTPUTS))
BIMG_OUTPUTS := $(patsubst %.gif,converted/%.bimg,$(BIMG_OUTPUTS))
BIMG_OUTPUTS := $(patsubst %.wav,converted/%.dfpwm,$(BIMG_OUTPUTS))

.PHONY: all
all: $(BIMG_OUTPUTS)

converted/%.bimg: processed/%.png conv.sh
	./conv.sh $< $@

converted/%.bimg: processed/%.gif conv.sh
	./conv.sh $< $@

converted/%.dfpwm: processed/%.wav
	ffmpeg -hide_banner -loglevel error -i $< -ar 48000 $@ 

.PHONY: clean
clean:
	rm -f $(BIMG_OUTPUTS)