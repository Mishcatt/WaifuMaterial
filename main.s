.include "registers.s"
.include "const.s"
.include "vars.s"

.segment "HEADER"
  ; .byte "NES", $1A      ; iNES header identifier
  .byte $4E, $45, $53, $1A
  .byte 2               ; 2x 16KB PRG code
  .byte 4               ; 4x  8KB CHR data
  .byte $30, $00        ; mapper 3, horizontal mirroring

.segment "VECTORS"
  ;; When an NMI happens (once per frame if enabled) the label nmi:
  .addr nmi
  ;; When the processor first turns on or is reset, it will jump to the label reset:
  .addr reset
  ;; External interrupt IRQ (unused)
  .addr irq

; "nes" linker config requires a STARTUP section, even if it's empty
.segment "STARTUP"

; Main code segment for the program
.segment "CODE"

reset:
    sei		; disable IRQs
    cld		; disable decimal mode
    ldx #$40
    stx JOYPAD2	; disable APU frame IRQ
    ldx #$ff 	; Set up stack
    txs		;  .
    inx		; now X = 0
    stx PPUCTRL	; disable NMI
    stx PPUMASK 	; disable rendering
    stx DMC_FREQ 	; disable DMC IRQs

;; first wait for vblank to make sure PPU is ready
vblankwait1:
    bit PPUSTATUS
    bpl vblankwait1

clear_memory:
    lda #$00
    sta $0000, x
    sta $0100, x
    sta $0200, x
    sta $0300, x
    sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $0700, x
    inx
    bne clear_memory

;; second wait for vblank, PPU is ready after this
vblankwait2:
    bit PPUSTATUS
    bpl vblankwait2

load_palettes:
    bit PPUSTATUS ; clear w register by reading Status
    lda #$3f
    sta PPUADDR
    lda #$00
    sta PPUADDR

    ldx #$00
    @bgloop:
        lda bgPalettes, x
        sta PPUDATA
        inx
        cpx #$10
        bne @bgloop
    ldx #$00
    @spriteloop:
        lda spritePalettes, x
        sta PPUDATA
        inx
        cpx #$10
        bne @spriteloop

load_initial_sprites:
    ldx #$00
    @loop:
        lda sprites, x
        sta OAM, x         ; Load the sprites into OAM
        inx
        cpx #SpriteLastByte
        bne @loop
    ; inc dmaflag

load_nametable:
    ldx #$00
    lda #%00001000  ; Disable NMI, sprite tile 1, horizontal increment
    sta PPUCTRL
    bit PPUSTATUS   ; clear w register by reading Status
    lda #$20        ; load nametable 0 address
    sta PPUADDR
    lda #$00
    sta PPUADDR
    @loop1:
        lda Nametable1A, x
        sta PPUDATA
        inx
        bne @loop1
    @loop2:
        lda Nametable1B, x
        sta PPUDATA
        inx
        bne @loop2
    @loop3:
        lda Nametable1C, x
        sta PPUDATA
        inx
        bne @loop3
    @loop4:
        lda Nametable1D, x
        sta PPUDATA
        inx
        cpx #240
        bne @loop4
    bit PPUSTATUS   ; clear w register by reading Status
    lda #$28        ; load nametable 2 address
    sta PPUADDR
    lda #$00
    sta PPUADDR
    ldx #$00
    @loop5:
        lda Nametable2A, x
        sta PPUDATA
        inx
        bne @loop5
    @loop6:
        lda Nametable2B, x
        sta PPUDATA
        inx
        bne @loop6
    @loop7:
        lda Nametable2C, x
        sta PPUDATA
        inx
        bne @loop7
    @loop8:
        lda Nametable2D, x
        sta PPUDATA
        inx
        cpx #240
        bne @loop8

load_attributes:
    bit PPUSTATUS   ; clear w register by reading Status
    lda #$23        ; load attribute table 0 address
    sta PPUADDR
    lda #$C0
    sta PPUADDR
    ldx #$00
    @loop1:
        lda Attributes1, x
        sta PPUDATA
        inx
        cpx #64
        bne @loop1
    bit PPUSTATUS   ; clear w register by reading Status
    lda #$2B        ; load attribute table 2 address
    sta PPUADDR
    lda #$C0
    sta PPUADDR
    ldx #$00
    @loop2:
        lda Attributes2, x
        sta PPUDATA
        inx
        cpx #64
        bne @loop2

set_scroll:
    lda #$00
    sta xscroll
    sta yscroll
    bit PPUSTATUS
    lda xscroll    ; set X/Y scroll (conditional via ppuflag)
    sta PPUSCROLL
    lda yscroll
    sta PPUSCROLL
    ; inc ppuflag

init_variables:
    lda #1
    sta split1bank
    sta currentSplit1bank
    sta nmibank
    lda #3
    sta split2bank

set_bank:
    lda #$01
    tay
    sta loadBank, y

enable_rendering:
    lda #%10001000	; Enable NMI, sprite tile 1, horizontal increment
    sta PPUCTRL
    sta softPPUCTRL
    lda #%00011110	; Enable Sprites and Background
    ; sta PPUMASK
    sta softPPUMASK
    ; inc drawflag
    sta nmiflag ; zero the NMI flag
    cli         ; enable interrupts

main_loop:
    lda nmiflag
    beq main_loop   ; wait for nmi_flag

    ; lda nmibank
    ; tay
    ; sta loadBank, y

    jsr readjoyx2   ; read two gamepads

    ldx yscroll

    lda buttons1
    eor previousButtons1
    and #BUTTON_START
    beq :+
        lda buttons1
        and #BUTTON_START
        beq :+
            lda pauseScroll
            eor #$01
            sta pauseScroll
    :

    lda pauseScroll
    bne :+++
        inx
        lda buttons1
        and #BUTTON_LEFT
        beq :+ 
            dex
            jmp :+++++
        :
        lda buttons1
        and #BUTTON_RIGHT
        beq :+
            dex
            jmp :++++
        :
        jmp :+++
    :
    lda buttons1
    and #BUTTON_UP
    beq :+ 
        dex
        jmp :+
    :
    lda buttons1
    and #BUTTON_DOWN
    beq :+ 
        inx
    :

    lda buttons1
    sta previousButtons1

    cpx #250
    bcc :+
        lda currentNametable
        eor #$02
        sta currentNametable
        lda softPPUCTRL
        eor #%00000010 ; swap nametable 0 and 2
        sta softPPUCTRL
        ldx #239
    :

    cpx #240
    bcc :+
        lda currentNametable
        eor #$02
        sta currentNametable
        lda softPPUCTRL
        eor #%00000010 ; swap nametable 0 and 2
        sta softPPUCTRL
        ldx #$00
    :
    stx yscroll

    ldx currentNametable
    bne :++  ; if nametable 0
        ldx yscroll
        cpx #17
        bcc :+  ; if yscroll >= 17
            lda #254
            sec
            sbc yscroll
            sta split1y
            lda #1
            sta nmibank
            lda #2
            sta split1bank
            lda #3
            sta split2bank
            jmp :+++++
        :   ; else
            lda #0
            sta split1y
            lda #1
            sta nmibank
            lda #1
            sta split1bank
            lda #2
            jmp :++++
    :       ; else (nametable 2)
        ldx yscroll
        cpx #15
        bcc :++  ; if yscroll >= 15
            cpx #143
            bcc :+  ; if yscroll >= 143
                lda #254
                sec
                sbc yscroll
                sta split1y
                lda #3
                sta nmibank
                lda #1
                sta split1bank
                jmp :+++
            :   ; else
                lda #126
                sec
                sbc yscroll
                sta split1y
                lda #2
                sta nmibank
                lda #3
                sta split1bank
                lda #1
                sta split2bank
                jmp :++
        :   ; else
            lda #14
            sec
            sbc yscroll
            sta split1y
            lda #1
            sta nmibank
            lda #2
            sta split1bank
            lda #3
            sta split2bank
    :
    lda split1y
    cmp #240
    bcc :+
        lda #3
        sta nmibank
        lda #0
    :
    sta OAM+Sprite0y

    ldx currentNametable
    bne :++++++  ; if nametable 0
        lda yscroll
        cmp #208
        bcs :+++++  ; yscroll < 208? 
            lda #173
            sec
            sbc yscroll
            sta banner1y
            cmp #209
            bcc :+
                ldx #240
                stx banner1y
            :
            clc
            adc #8
            sta banner2y
            cmp #211
            bcc :+
                ldx #240
                stx banner2y
            :
            clc
            adc #8 
            sta banner3y
            cmp #219
            bcc :+
                ldx #240
                stx banner3y
            :
            clc
            adc #8 
            sta banner4y 
            cmp #221
            bcc :+
                ldx #240
                stx banner4y
            :
            jmp :++++
        :       ; else
        lda #240
        sta banner1y
        sta banner2y
        sta banner3y 
        sta banner4y 
        jmp :+++
    :       ; else (nametable 2)
        lda yscroll
        cmp #173
        bcc :+  ; yscroll >= 173? 
            lda #157
            sec
            sbc yscroll
            clc
            sta banner1y
            adc #8
            cmp #240
            bcs :++
            sta banner2y
            clc
            adc #8 
            cmp #240
            bcs :++
            sta banner3y 
            clc
            adc #8 
            cmp #240
            bcs :++
            sta banner4y 
            jmp :++
        :       ; else
        lda #240
        sta banner1y
        sta banner2y
        sta banner3y 
        sta banner4y 
    :
    ; lda banner1y
    ; sta OAM+SpriteBanner00y
    ; sta OAM+SpriteBanner01y
    ; sta OAM+SpriteBanner02y
    ; sta OAM+SpriteBanner03y
    ; sta OAM+SpriteBanner04y
    ; sta OAM+SpriteBanner05y
    ; sta OAM+SpriteBanner06y
    ; sta OAM+SpriteBanner07y
    ; lda banner2y
    ; sta OAM+SpriteBanner08y
    ; sta OAM+SpriteBanner09y
    ; sta OAM+SpriteBanner10y
    ; sta OAM+SpriteBanner11y
    ; sta OAM+SpriteBanner12y
    ; sta OAM+SpriteBanner13y
    ; sta OAM+SpriteBanner14y
    ; sta OAM+SpriteBanner15y
    ; lda banner3y
    ; sta OAM+SpriteBanner16y
    ; sta OAM+SpriteBanner17y
    ; sta OAM+SpriteBanner18y
    ; sta OAM+SpriteBanner19y
    ; sta OAM+SpriteBanner20y
    ; sta OAM+SpriteBanner21y
    ; sta OAM+SpriteBanner22y
    ; sta OAM+SpriteBanner23y
    ; lda banner4y
    ; sta OAM+SpriteBanner24y
    ; sta OAM+SpriteBanner25y
    ; sta OAM+SpriteBanner26y
    ; sta OAM+SpriteBanner27y
    ; sta OAM+SpriteBanner28y
    ; sta OAM+SpriteBanner29y
    ; sta OAM+SpriteBanner30y
    ; sta OAM+SpriteBanner31y

    lda #1
    sta ppuflag
    ; sta drawflag
    ; sta dmaflag

    vblankLoop:
        bit PPUSTATUS  ; check for sprite 0 clear
        bvs vblankLoop ; loop if still set (still in previous vBlank)

    sprite0loop:
        bit PPUSTATUS   ; check for sprite 0 set
        bmi skipSpriteCheck
        bvc sprite0loop ; loop if still clear

        lda currentSplit1bank
        tay
        sta loadBank, y
        lda split1bank
        sta currentSplit1bank

        lda currentNametable
        bne :+   ; if nametable 0
            lda yscroll
            cmp #128
            bcc :+++
                jsr delay
                inc split2bank
                dec split2bank
                lda #3
                tay
                sta loadBank, y
                jmp :+++
        :   ; else (nametable 2)
            lda yscroll
            cmp #16
            bcs :+
                jsr delay
                inc split2bank
                dec split2bank
                lda #3
                tay
                sta loadBank, y
                jmp :++
            :
            cmp #144
            bcs :+
                jsr delay
                lda #1
                tay
                sta loadBank, y
        :

    skipSpriteCheck:
        lda #0
        sta nmiflag
        jmp main_loop

delay:
    ldx #181
    stx delayVar2
    @loop2:
        ldy #242
        sty delayVar1
        @loop1:
            inc delayVar1
            ldy delayVar1
            bne @loop1
        inc delayVar2
        ldx delayVar2
        bne @loop2
    rts

.include "joypad.s"

MusicEngine:
    rts

.include "nmi.s"

irq:
    rti

.include "sprites.s"
.include "palettes.s"
.include "picture.s"

; Character memory
.segment "CHARS"
    .incbin "waifu_random.chr", 0, 8192
    .incbin "waifu1.chr", 0, 4096
    .incbin "waifu_sprites.chr", 0, 4096
    .incbin "waifu2.chr", 0, 4096
    .incbin "waifu_sprites.chr", 0, 4096
    .incbin "waifu3.chr", 0, 4096
    .incbin "waifu_sprites.chr", 0, 4096
