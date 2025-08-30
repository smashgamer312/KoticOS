TARGET=kernel.bin
ISO=KoticOS.iso
BUILD=build

all: $(ISO)

$(BUILD):
	mkdir -p $(BUILD)/boot/grub

$(BUILD)/$(TARGET): src/kernel.asm src/link.ld | $(BUILD)
	nasm -f elf32 src/kernel.asm -o $(BUILD)/kernel.o
	i386-elf-ld -T src/link.ld -o $(BUILD)/$(TARGET) $(BUILD)/kernel.o --oformat binary

$(ISO): $(BUILD)/$(TARGET)
	cp $(BUILD)/$(TARGET) $(BUILD)/boot/kernel.bin
	cp grub/grub.cfg $(BUILD)/boot/grub/grub.cfg
	grub-mkrescue -o $(ISO) $(BUILD)

run: $(ISO)
	qemu-system-i386 -cdrom $(ISO)

clean:
	rm -rf $(BUILD) $(ISO)