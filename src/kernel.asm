BITS 32

global _start

section .multiboot
align 8
mb2_header_start:
    dd 0xE85250D6           ; magic
    dd 0                    ; architecture (i386)
    dd mb2_header_end - mb2_header_start
    dd 0x100000000 - (0xE85250D6 + 0 + (mb2_header_end - mb2_header_start))  ; checksum

; Request framebuffer from GRUB
align 8
    dw 5                    ; tag type 5: framebuffer
    dw 0                    ; flags
    dd 20                   ; size
    dd 1024                 ; width
    dd 768                  ; height
    dd 32                   ; bpp
align 8
    dw 0                    ; end tag
    dw 0
    dd 8
mb2_header_end:

section .bss
align 16
stack_bottom:    resb 4096
stack_top:

input_buf:       resb 256
input_len:       resd 1

section .data
hello:      db "KoticOS (ASM) - type /help", 0
prompt:     db 10,"> ",0
nl:         db 10,0
help_txt:   db "/help /echo /reboot /shutdown /sysinfo /cls /explorer",0
unknown:    db "Unknown command",0
sysinfo:    db "KoticOS v0.1 | 32-bit | Framebuffer demo",0
echo_prefix:db "",0
gui_exit:   db "GUI demo closed.",0
clear_seq:  db 27,'[2J',27,'[H',0  ; ANSI clear (works in some terms, but we do manual clear too)


; scancode -> ascii (lowercase); 128 entries
scancode_table:
    db 0,  27, '1','2','3','4','5','6','7','8','9','0','-','=', 8,  9
    db 'q','w','e','r','t','y','u','i','o','p','[',']', 13, 0, 'a','s'
    db 'd','f','g','h','j','k','l',';','\'', '`', 0, '\\','z','x','c','v'
    db 'b','n','m',',','.','/', 0,  '*', 0,  ' ', 0,   0,   0,   0,   0,  0
    times (128-64) db 0


section .text

; === Basic port I/O ===
outb:
    ; [esp+4]=port, [esp+8]=value
    mov dx, [esp+4]
    mov al, [esp+8]
    out dx, al
    ret

inb:
    ; [esp+4]=port -> al
    mov dx, [esp+4]
    in  al, dx
    ret

; === Simple screen using VGA text mode (0xB8000) ===
print:
    ; esi -> zero-terminated string
    pusha
    mov edi, 0xB8000
    ; find current cursor pos (we keep it simple: scan for last non-zero? too slow)
    ; For simplicity, we maintain a shadow cursor in [cursor_pos]
    mov ebx, [cursor_pos]
.print_loop:
    lodsb
    cmp al, 0
    je .done
    cmp al, 10
    jne .store
    ; newline
    add ebx, (80 - (ebx % 80))
    jmp .print_loop
.store:
    mov ah, 0x0F
    mov edx, ebx
    mov ecx, 2
    imul edx, ecx
    mov [edi + edx], ax
    inc ebx
    jmp .print_loop
.done:
    mov [cursor_pos], ebx
    popa
    ret

print_nl:
    pusha
    mov esi, nl
    call print
    popa
    ret

; write char in AL
putch:
    pusha
    mov edi, 0xB8000
    mov ebx, [cursor_pos]
    cmp al, 10
    jne .not_nl
    add ebx, (80 - (ebx % 80))
    jmp .store_end
.not_nl:
    mov ah, 0x0F
    mov edx, ebx
    mov ecx, 2
    imul edx, ecx
    mov [edi + edx], ax
    inc ebx
.store_end:
    mov [cursor_pos], ebx
    popa
    ret

cls:
    pusha
    mov edi, 0xB8000
    mov ecx, 80*25
    mov ax, 0x0720         ; ' ' with attribute
.clr:
    mov [edi], ax
    add edi, 2
    loop .clr
    mov dword [cursor_pos], 0
    popa
    ret

; === Minimal int setup (we avoid interrupts; we poll keyboard) ===

; === Keyboard poll: read scancode -> ascii (lowercase) ===
kbd_read_char:
    ; returns AL=ascii or 0 if none
    pusha
    ; wait while output buffer not ready
    mov dx, 0x64
.wait:
    in al, dx
    test al, 1
    jz .none
    ; read scancode
    mov dx, 0x60
    in al, dx
    cmp al, 0xE0
    je .none     ; ignore extended for simplicity
    ; key release? (>=0x80)
    test al, 0x80
    jnz .none
    ; translate
    movzx ebx, al
    mov al, [scancode_table + ebx]
    cmp al, 0
    je .none2
    mov [esp+28], al   ; place return AL into saved EAX
    popa
    ret
.none2:
    popa
    xor al, al
    ret
.none:
    popa
    xor al, al
    ret

read_line:
    ; reads into input_buf, updates input_len, handles backspace, enter
    pusha
    mov edi, input_buf
    mov ecx, 0
.rl_loop:
    call kbd_read_char
    cmp al, 0
    je .rl_loop
    cmp al, 8              ; backspace
    jne .not_bs
    cmp ecx, 0
    jz .rl_loop
    dec ecx
    dec edi
    mov al, 8
    call putch
    mov al, ' '
    call putch
    mov al, 8
    call putch
    jmp .rl_loop
.not_bs:
    cmp al, 13             ; enter
    jne .store
    mov byte [edi], 0
    mov [input_len], ecx
    mov al, 10
    call putch
    jmp .done
.store:
    mov [edi], al
    inc edi
    inc ecx
    call putch
    jmp .rl_loop
.done:
    popa
    ret

; string compare: esi=str1, edi=str2 -> ZF=1 equal
strcmp:
    push eax
    push ebx
    push ecx
    push edx
.sc_loop:
    lodsb
    mov bl, [edi]
    inc edi
    cmp al, bl
    jne .noteq
    test al, al
    jnz .sc_loop
    ; both 0
    xor eax, eax
    jmp .end
.noteq:
    mov eax, 1
.end:
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; parse command in input_buf (prefixed with '/')
handle_command:
    pusha
    mov esi, input_buf
    cmp byte [esi], '/'
    jne .unknown
    inc esi
    ; check "help"
    mov edi, cmd_help
    call strcmp
    test eax, eax
    jne .chk_echo
    mov esi, help_txt
    call print
    jmp .done
.chk_echo:
    mov edi, cmd_echo
    mov eax, [input_len]
    call strcmp
    test eax, eax
    jne .chk_reboot
    ; print the rest after "/echo "
    ; find space
    mov esi, input_buf
    add esi, 5
    call print
    jmp .done
.chk_reboot:
    mov edi, cmd_reboot
    call strcmp
    test eax, eax
    jne .chk_shutdown
    call do_reboot
    jmp .done
.chk_shutdown:
    mov edi, cmd_shutdown
    call strcmp
    test eax, eax
    jne .chk_sysinfo
    jmp $                   ; halt loop (simple "shutdown")
.chk_sysinfo:
    mov edi, cmd_sysinfo
    call strcmp
    test eax, eax
    jne .chk_cls
    mov esi, sysinfo
    call print
    jmp .done
.chk_cls:
    mov edi, cmd_cls
    call strcmp
    test eax, eax
    jne .chk_explorer
    call cls
    jmp .done
.chk_explorer:
    mov edi, cmd_explorer
    call strcmp
    test eax, eax
    jne .unknown
    call gui_demo
    mov esi, gui_exit
    call print
    jmp .done
.unknown:
    mov esi, unknown
    call print
.done:
    popa
    ret

; Simple warm reboot via 8042
do_reboot:
    pusha
    mov dx, 0x64
.wait_ibf:
    in al, dx
    test al, 2
    jnz .wait_ibf
    mov al, 0xFE
    out dx, al
.hang:
    jmp .hang

; === GUI demo using GRUB framebuffer ===
; On entry, EBX has multiboot info pointer from GRUB.
; We saved it in mb_info earlier. We draw a rectangle window.
gui_demo:
    pusha
    mov eax, [fb_addr]
    test eax, eax
    jz .no_fb
    ; Clear screen to dark gray
    mov edi, eax
    mov ecx, [fb_pitch]
    mov ebx, [fb_height]
    mov edx, [fb_width]
    imul ebx, ecx           ; total bytes
    mov ecx, ebx
    mov eax, 0x00202020     ; ARGB?
.fill:
    mov [edi], eax
    add edi, 4
    sub ecx, 4
    jg .fill

    ; Draw window rectangle at (100,100) size 600x400, white border, blue title
    ; draw horizontal lines
    mov esi, [fb_addr]
    mov ebx, [fb_pitch]
    mov edx, [fb_width]

    ; function draw_hline(x,y,w,color)
%macro DRAW_H 4
    ; x=%1 y=%2 w=%3 color=%4
    mov edi, esi
    mov eax, %4
    mov ecx, %3
    mov ebp, %2
    imul ebp, ebx
    add edi, ebp
    mov ebp, %1
    shl ebp, 2
    add edi, ebp
.dh_loop_%+%2:
    mov [edi], eax
    add edi, 4
    loop .dh_loop_%+%2
%endmacro

    ; function draw_vline(x,y,h,color)
%macro DRAW_V 4
    ; x=%1 y=%2 h=%3 color=%4
    mov edi, esi
    mov eax, %4
    mov ecx, %3
    mov ebp, %2
    imul ebp, ebx
    add edi, ebp
    mov ebp, %1
    shl ebp, 2
    add edi, ebp
.dv_loop_%+%1:
    mov [edi], eax
    add edi, ebx
    loop .dv_loop_%+%1
%endmacro

    ; border
    DRAW_H 100,100,600,0x00FFFFFF
    DRAW_H 100,500,600,0x00FFFFFF
    DRAW_V 100,100,400,0x00FFFFFF
    DRAW_V 700,100,400,0x00FFFFFF
    ; title bar
    DRAW_H 101,101,598,0x000000AA
    DRAW_H 101,120,598,0x000000AA

    ; wait for Enter to exit GUI
.wait_enter:
    call kbd_read_char
    cmp al, 13
    jne .wait_enter
    popa
    ret

.no_fb:
    ; fallback text
    mov esi, unknown
    call print
    popa
    ret

; === Multiboot info parsing to get framebuffer ===
; GRUB gives EBX=mb_info to _start. We scan tags to find framebuffer
parse_mb_fb:
    pusha
    mov esi, [mb_info]
    test esi, esi
    jz .done
    ; skip total size & reserved
    mov eax, [esi]
    add esi, 8
.scan:
    mov edx, [esi]          ; tag type (dw) + flags(dw) -> we'll read type
    mov dx, [esi]
    cmp dx, 0
    je .done
    cmp dx, 8               ; type=8 (framebuffer info tag)
    jne .next
    ; framebuffer tag layout (Multiboot2): type=8, size=... then fb_addr(64), fb_pitch(32), fb_width(32), fb_height(32), bpp(8), type(8), reserved(16) ...
    add esi, 8
    mov eax, [esi]          ; low 32 of fb_addr
    mov [fb_addr], eax
    add esi, 8              ; skip high 32 (we assume below 4G)
    mov eax, [esi]
    mov [fb_pitch], eax
    add esi, 4
    mov eax, [esi]
    mov [fb_width], eax
    add esi, 4
    mov eax, [esi]
    mov [fb_height], eax
    jmp .done
.next:
    ; advance to next tag with 8-byte alignment
    mov eax, [esi+4]        ; size
    add esi, eax
    add esi, 7
    and esi, 0xFFFFFFF8
    jmp .scan
.done:
    popa
    ret

; Data for framebuffer
section .bss
align 4
cursor_pos:   resd 1
mb_info:      resd 1
fb_addr:      resd 1
fb_pitch:     resd 1
fb_width:     resd 1
fb_height:    resd 1

section .data
cmd_help:     db "help",0
cmd_echo:     db "echo",0
cmd_reboot:   db "reboot",0
cmd_shutdown: db "shutdown",0
cmd_sysinfo:  db "sysinfo",0
cmd_cls:      db "cls",0
cmd_explorer: db "explorer",0

section .text
_start:
    ; set stack
    mov esp, stack_top

    ; EBX has multiboot info per GRUB
    mov [mb_info], ebx
    call parse_mb_fb

    ; clear screen and print banner
    call cls
    mov esi, hello
    call print
    call print_nl

.mainloop:
    mov esi, prompt
    call print
    call read_line
    call handle_command
    jmp .mainloop
