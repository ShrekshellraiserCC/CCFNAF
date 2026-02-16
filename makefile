# Convert processed assets (.png and .gif) to BIMG format
PROCESSED_ASSETS := $(wildcard processed/*.png processed/*.gif processed/*.wav)
CONVERTED_OUTPUTS := $(patsubst processed/%,%,$(PROCESSED_ASSETS))
CONVERTED_OUTPUTS := $(patsubst %.png,converted/%.bimg,$(CONVERTED_OUTPUTS))
CONVERTED_OUTPUTS := $(patsubst %.gif,converted/%.bimg,$(CONVERTED_OUTPUTS))
CONVERTED_OUTPUTS := $(patsubst %.wav,converted/%.dfpwm,$(CONVERTED_OUTPUTS))

PROCESSED_ASSETS := $(wildcard processed/*.png processed/*.gif processed/*.wav)
PROCESSED_OUTPUTS := $(patsubst processed/%,%,$(PROCESSED_ASSETS))
PROCESSED_OUTPUTS := $(patsubst %.png,resources/%.bimg.gz,$(PROCESSED_OUTPUTS))
PROCESSED_OUTPUTS := $(patsubst %.gif,resources/%.bimg.gz,$(PROCESSED_OUTPUTS))
PROCESSED_OUTPUTS := $(patsubst %.wav,resources/%.dfpwm,$(PROCESSED_OUTPUTS))

.PHONY: all
all: $(CONVERTED_OUTPUTS) $(PROCESSED_OUTPUTS)

converted/%.bimg: processed/%.png conv.sh
	./conv.sh $< $@

converted/%.bimg: processed/%.gif conv.sh
	./conv.sh $< $@

converted/%.dfpwm: processed/%.wav
	ffmpeg -hide_banner -loglevel error -i $< -ar 48000 $@ 

resources/%.bimg.gz: converted/%.bimg
	gzip -c -9 $< > $@

resources/%.dfpwm: converted/%.dfpwm
	cp $< $@

.PHONY: clean
clean:
	rm -f $(BIMG_OUTPUTS)