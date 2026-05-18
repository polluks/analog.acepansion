# Makefile for LP-1 Light Pen Z80 Driver
# Requires RASM (Roudoudou's Z80 Assembler)
# https://github.com/EdouardBERGE/rasm

RASM    = rasm
OUTPUT  = lp1_driver.bin

all: $(OUTPUT)

$(OUTPUT): lp1_driver.asm
	$(RASM) $< -o $@ -b

clean:
	rm -f $(OUTPUT)
