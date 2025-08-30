; kernel.asm - KoticOS стартовый код
BITS 32
ORG 0x100000

; -----------------------
; Таблица команд
; -----------------------
section .data
prompt db 'KoticOS> ',0
help_text db '/help - список команд',10,'/echo <text> - вывод текста',10,'/cls - очистка экрана',10,'/explorer - GUI',10,0

; -----------------------
; Стек
; -----------------------
section .bss
stack resb 4096

; -----------------------
; Код ядра
; -----------------------
section .text
global _start
_start:

    call init_screen
main_loop:
    call print_prompt
    call read_input
    call handle_command
    jmp main_loop

; -----------------------
; Инициализация экрана (очистка)
; -----------------------
init_screen:
    mov ax,0x0F00      ; черный фон, белый текст
    int 0x10
    ret

; -----------------------
; Вывод prompt
; -----------------------
print_prompt:
    mov edx, prompt
.next_char:
    lodsb
    cmp al,0
    je .done
    mov ah,0x0E
    int 0x10
    jmp .next_char
.done:
    ret

; -----------------------
; Чтение ввода
; -----------------------
read_input:
    mov ecx,input_buffer
.read_loop:
    mov ah,0
    int 0x16           ; BIOS: считываем символ
    cmp al,13
    je .done
    stosb
    jmp .read_loop
.done:
    mov byte [ecx],0
    ret

section .bss
input_buffer resb 128

; -----------------------
; Обработка команд
; -----------------------
handle_command:
    mov esi, input_buffer
    ; команда /help
    mov edi, help_text
    call strcmp
    je .help_cmd
    ; команда /cls
    mov edi, cls_cmd
    call strcmp
    je .cls_cmd
    ; команда /explorer
    mov edi, explorer_cmd
    call strcmp
    je .explorer_cmd
    ; команда /echo
    mov edi, echo_cmd
    call startswith
    je .echo_cmd
    ret

.help_cmd:
    ; вывести help_text
    mov edx, help_text
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
    ; выводим текст после "/echo "
    ret

section .data
cls_cmd db '/cls',0
explorer_cmd db '/explorer',0
echo_cmd db '/echo ',0

; -----------------------
; Стартовое GUI-демо
; -----------------------
gui_demo:
    ; рисуем простое окно (рамка)
    ret

; -----------------------
; Вспомогательные функции (strcmp, startswith)
; -----------------------
strcmp:
    ; простой пример сравнения строк
    ret

startswith:
    ret
