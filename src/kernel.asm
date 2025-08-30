BITS 32

section .data
prompt db 'KoticOS> ',0
help_text db '/help - список команд',10,'/echo <text> - вывод текста',10,'/cls - очистка экрана',10,'/explorer - GUI',10,0
cls_cmd db '/cls',0
explorer_cmd db '/explorer',0
echo_cmd db '/echo ',0

section .bss
stack resb 4096
input_buffer resb 128
cursor_x resb 1
cursor_y resb 1

section .text
global _start
_start:

    call init_screen

main_loop:
    call print_prompt
    call read_input
    call handle_command
    jmp main_loop

init_screen:
    mov ah,0x0
    mov al,0x03
    int 0x10
    ret

print_prompt:
    mov esi, prompt
.next_char:
    lodsb
    cmp al,0
    je .done
    mov ah,0x0E
    int 0x10
    jmp .next_char
.done:
    ret

read_input:
    mov edi, input_buffer
.read_loop:
    mov ah,0
    int 0x16
    cmp al,13
    je .done
    stosb
    jmp .read_loop
.done:
    mov byte [edi],0
    ret

handle_command:
    mov esi, input_buffer
    mov edi, help_text
    call strcmp
    cmp eax,0
    je .help_cmd
    mov edi, cls_cmd
    call strcmp
    cmp eax,0
    je .cls_cmd
    mov edi, explorer_cmd
    call strcmp
    cmp eax,0
    je .explorer_cmd
    mov edi, echo_cmd
    call startswith
    cmp eax,0
    je .echo_cmd
    ret

.help_cmd:
    mov esi, help_text
.print_help:
    lodsb
    cmp al,0
    je .done_help
    mov ah,0x0E
    int 0x10
    jmp .print_help
.done_help:
    ret

.cls_cmd:
    call init_screen
    ret

.explorer_cmd:
    call gui_demo
    ret

.echo_cmd:
    mov esi, input_buffer
    add esi, 6
.print_echo:
    lodsb
    cmp al,0
    je .done_echo
    mov ah,0x0E
    int 0x10
    jmp .print_echo
.done_echo:
    ret

gui_demo:
    mov cx, 50
    mov dh, 2
    mov dl, 10
.draw_top:
    mov al,'#'
    call print_char_at
    inc dl
    loop .draw_top
    ret

print_char_at:
    mov ah,0x0E
    int 0x10
    ret

strcmp:
    push esi
.next_cmp:
    lodsb
    cmp al, [edi]
    jne .not_equal
    cmp al,0
    je .equal
    inc edi
    jmp .next_cmp
.equal:
    mov eax,0
    pop esi
    ret
.not_equal:
    mov eax,1
    pop esi
    ret

startswith:
    push esi
.next_sw:
    lodsb
    cmp al, [edi]
    jne .sw_fail
    cmp al,0
    je .sw_ok
    inc edi
    jmp .next_sw
.sw_ok:
    mov eax,0
    pop esi
    ret
.sw_fail:
    mov eax,1
    pop esi
    ret
