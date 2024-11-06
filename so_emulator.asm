; by OP i mean operations from task such as MOVI arg1, imm8

global so_emul

A           equ 0                   ; SO processor registers
D           equ 1
X           equ 2
Y           equ 3
PC          equ 4
C           equ 6
Z           equ 7

section .bss                        ; declaration of SO processors
align 8
proc: resq  CORES                   ; one processor for each core needed

section .text
convert_arg:                        ; function get address of proper SO register
    lea     rax, [rel proc]         ; according to arg code (0 - 7)
    add     rax, rcx                ; function modifies only rax and r11
    xor     r11, r11                ; code is passed via r8
    cmp     r8w, 4                  ; codes (0 - 3)
    jl      .in_register
    cmp     r8w, 6                  ; codes (4 - 5)
    jl      .single_address
    jmp     .double_address         ; codes (6 - 7)

.in_register:
    add     ax, r8w
    ret

.single_address:
    mov     r11b, [rax + r8 - 2]
    add     r11, rsi                ; access to data
    mov     rax, r11
    ret

.double_address:
    mov     r11b, [rax + D]
    add     r11b, [rax + r8 - 4]
    add     r11, rsi                ; access to data
    mov     rax, r11
    ret


so_emul:
    push    rbx                     ; ABI requirements
    push    r12
    push    r13
    push    r14

                                    ; rdi-code rsi-data rdx-steps rcx-core
    shl     rcx, 3                  ; each processor uses 8 bytes
    lea     r14, [rel proc]         ; r14 will be effective address of proc
    add     r14, rcx
    xor     rbx, rbx
.while_steps:                       ; looping until `steps` operations
    cmp     rbx, rdx                ; have been performed
    jae     .end_while

    xor     r13, r13                ; r13 will hold code of current OP
    xor     r10, r10
    mov     r10b, [r14 + PC]        ; checking PC
    mov     r13w, [r10 * 2 + rdi]   ; each code takes 2 bytes
    cmp     r13w, 0x4000            ; maximal command code of type OP arg1 arg2
    jae     .other_ops              ; checking if OP is of type OP arg1 arg2

    mov     r10w, r13w              ; get the value of (code mod 16)
    and     r10w, 0x000F            ; now r10w holds the type of operation

    mov     r8, r13                 ; decoding arg1 code
    shr     r8, 8                   ; r8 will hold proper 3 bits of OP code
    and     r8, 7
    call    convert_arg
    mov     r12, rax

    mov     r8, r13                 ; decoding arg2 code
    shr     r8, 11                  ; again find proper 3 bits of OP code
    and     r8, 7
    call    convert_arg
    mov     r9, rax

    mov     r8, r12                 ; now r8 = arg1, r9 = arg2 (address-wise)
    mov     r12, r9                 ; r12 = arg2 (address-wise)
    mov     r9b, [r12]              ; r9 = value of arg2

.check_2argop_type:
    cmp     r10w, 0                 ; checking possible OP types
    jz      .mov_op
    cmp     r10w, 2
    jz      .or_op
    cmp     r10w, 4
    jz      .add_op
    cmp     r10w, 5
    jz      .sub_op
    cmp     r10w, 6
    jz      .adc_op
    cmp     r10w, 7
    jz      .sbb_op
    jmp     .xchg_op

.mov_op:                            ; simple move
    mov     [r8], r9b
    jmp     .end_ops

.or_op:                             ; or, set Z flag
    or      [r8], r9b
    sete    [r14 + Z]
    jmp     .end_ops

.add_op:                            ; add, set Z flag
    add     [r8], r9b
    sete    [r14 + Z]
    jmp     .end_ops

.sub_op:                            ; sub, set Z flag
    sub     [r8], r9b
    sete    [r14 + Z]
    jmp     .end_ops

.adc_op:                            ; add with carry, set C, Z flags
    mov     r10b, [r14 + C]
    bt      r10, 0                  ; setting CF
    adc     [r8], r9b               ; carry may occur here
    setc    r10b
    mov     [r14 + C], r10b         ; we want to know if carry occured
    sete    [r14 + Z]
    jmp     .end_ops

.sbb_op:                            ; sub with carry, set C, Z flags
    mov     r10b, [r14 + C]
    bt      r10, 0                  ; setting CF
    sbb     [r8], r9b               ; carry may occur here
    setc    r10b
    mov     [r14 + C], r10b         ; we want to know if carry occured
    sete    [r14 + Z]
    jmp     .end_ops

.xchg_op:                           ; xchg two args
    mov     al, [r12]
    xchg    [r8], al
    mov     [r12], al
    jmp     .end_ops

.other_ops:
    mov     r8, r13                 ; arg1 code (if exists) in r8
    and     r8, 0x0700
    shr     r8, 8

    mov     r9, r13                 ; imm8 (if exists) in r9
    and     r9, 0x00FF

    xor     r10, r10                ; used as helper register later

    cmp     r13w, 0x5800            ; checking possible OP types
    jb      .movi_op
    cmp     r13w, 0x6000
    jb      .xori_op
    cmp     r13w, 0x6800
    jb      .addi_op
    cmp     r13w, 0x7001
    jb      .cmpi_op
    cmp     r13w, 0x8000
    jb      .rcr_op
    cmp     r13w, 0x8100
    jb      .clc_op
    cmp     r13w, 0xC000
    jb      .stc_op
    cmp     r13w, 0xC200
    jb      .jmp_op
    cmp     r13w, 0xC300
    jb      .jnc_op
    cmp     r13w, 0xC400
    jb      .jc_op
    cmp     r13w, 0xC500
    jb      .jnz_op
    cmp     r13w, 0xFFFF
    jb      .jz_op
    jmp     .brk_op

.movi_op:                           ; simple move
    call    convert_arg
    mov     [rax], r9b
    jmp     .end_ops

.xori_op:                           ; xor, set Z flag
    call    convert_arg
    xor     [rax], r9b
    sete    [r14 + Z]
    jmp     .end_ops

.addi_op:                           ; add, set Z flag
    call    convert_arg
    add     [rax], r9b
    sete    [r14 + Z]
    jmp     .end_ops

.cmpi_op:                           ; compare, set C, Z flags
    call    convert_arg
    mov     r10b, [rax]
    sub     r10b, r9b
    setc    [r14 + C]
    sete    [r14 + Z]
    jmp     .end_ops

.rcr_op:                            ; rotate by one bit with usage of C flag
    call    convert_arg
    mov     r10b, [r14 + C]
    bt      r10, 0                  ; setting CF bit
    mov     r10b, [rax]
    rcr     r10b, 1
    mov     [rax], r10b
    setc    [r14 + C]
    jmp     .end_ops

.clc_op:                            ; set C flag = 0
    mov     byte [r14 + C], 0
    jmp     .end_ops

.stc_op:                            ; set C flag = 1
    mov     byte [r14 + C], 1
    jmp     .end_ops

.jmp_op:                            ; jmp, modify PC (pointer to current OP)
    add     [r14 + PC], r9b
    jmp     .end_ops

.jnc_op:                            ; jmp when C = 0
    mov     r10b, [r14 + C]
    bt      r10, 0                  ; setting CF bit
    jc      .end_ops                ; CF = 1
    add     [r14 + PC], r9b
    jmp     .end_ops

.jc_op:                             ; jmp when C = 1
    mov     r10b, [r14 + C]
    bt      r10, 0                  ; setting CF bit
    jnc     .end_ops                ; CF = 0
    add     [r14 + PC], r9b
    jmp     .end_ops

.jnz_op:                            ; jmp when Z = 0
    mov     r10b, [r14 + Z]
    and     r10b, r10b              ; setting ZF = r10b
    jnz     .end_ops                ; ZF = 1
    add     [r14 + PC], r9b
    jmp     .end_ops

.jz_op:                             ; jmp when Z = 1
    mov     r10b, [r14 + Z]
    and     r10b, r10b              ; setting ZF = r10b
    jz      .end_ops                ; ZF = 0
    add     [r14 + PC], r9b
    jmp     .end_ops

.brk_op:                            ; terminates SO work
    inc     byte [r14 + PC]         ; last PC increase
    jmp     .end_while

.end_ops:
    inc     byte [r14 + PC]         ; increasing PC
    inc     rbx                     ; increasing number of processed steps
    jmp     .while_steps

.end_while:
    mov     rax, [r14]              ; saving answer
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret
