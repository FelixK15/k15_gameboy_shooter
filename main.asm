INCLUDE "hardware.inc"

OAMDMA EQU $FF83
PlayerSpriteTop_Stand EQU       $80
PlayerSpriteBottom_Stand EQU    $81
PlayerSpriteBottom_Walk EQU     $82

SECTION "Header", ROM0[$100]

Main:
    jp StartGame

REPT $150 - $104;
    db 0
ENDR

SECTION "VBlank Interrupt", ROM0[$0040]

VBlank:
    call copyObjectAttributes
    reti

SECTION "Tilemap", ROM0
StartTileMap:
INCBIN "tilemap.bin"
EndTileMap:

SECTION "Functions", ROM0[$0150]

;memcpy input:
;   hl - source
;   bc - destination
;   d - byte count
memcpy:
    ld a, [hli] ;Load byte from hl into a and increment i (take byte from current Source)
    ld [bc], a  ;Store byte to bc
    inc bc      ;increment bc (write to next byte)
    dec d       ;decrement byte count
    jr nz, memcpy
    ret

cpy_dmacpy:
    ld hl, dmacpy
    ld bc, OAMDMA
    ld d, dmacpy_end - dmacpy
    call memcpy
    ret

dmacpy:
    ldh [rDMA], a
    ld a, 40
  .wait
    dec a
    jr nz, .wait
    ret
dmacpy_end:

; after function: b = buttons, d = digi pad
readInput:
    ld a, P1F_5     ; buttons
    ld [rP1], a
    ld a, [rP1]
    ld a, [rP1]
    ld a, [rP1]
    ld a, [rP1]
    ld a, [rP1]
    ld a, [rP1]
    ld b, a
    ld a, P1F_5     ;digi pad
    ld [rP1], a
    ld a, [rP1]
    ld a, [rP1]
    ld a, [rP1]
    ld a, [rP1]
    ld a, [rP1]
    ld a, [rP1]
    ld d, a
    ret

initPlayer:
    ld a, 20
    ld [PlayerPosX], a
    ld [PlayerPosY], a
    ld a, PlayerSpriteTop_Stand
    ld [PlayerSpriteTop], a
    ld a, 0
    ld [PlayerSpriteTopFlag], a
    ld [PlayerSpriteBottomFlag], a
    
    ld a, PlayerSpriteBottom_Stand
    ld [PlayerSpriteBottom], a
    ret 

SECTION "Shadow OAM", WRAM0, ALIGN[8]
wShadowOAM:
PlayerSpriteTopY:
    DS 1
PlayerSpriteTopX:
    DS 1
PlayerSpriteTop:
    DS 1
PlayerSpriteTopFlag:
    DS 1

PlayerSpriteBottomY:
    DS 1
PlayerSpriteBottomX:
    DS 1
PlayerSpriteBottom:
    DS 1
PlayerSpriteBottomFlag:
    DS 1

DS 4*38

SECTION "Game Data", WRAM0
PlayerPosX:
    DS 1

PlayerPosY:
    DS 1

SECTION "Game Code", ROM0

StartGame:
.start 
    call cpy_dmacpy     ; copy dma function to hram

    di                  ; disable interrupts
    ld a, IEF_VBLANK    ; set vblank enable interrupt flag
    ld [rIE], a         ; set intterupt flag
    ei                  ; enable intterupts

    ld a, [rLCDC]
    or LCDCF_OBJON      ; enable sprite
    or LCDCF_OBJ8       ; sprite mode = 8x8
    ld [rLCDC], a

    ;load default palette for OBP0
    ld a, %11100100
    ld [rOBP0], a

    ld sp, $FFFE        ; set stack pointer to $FFFE
    
    halt                ; wait for vblank so that the tilemap can be loaded
    nop 

    call loadTileMap    ; load global tile map
    call initPlayer
    jr .mainLoop        ; start main loop
.move_player_right
    ld a, [PlayerPosX]
    inc a
    ld [PlayerPosX], a

    xor a
    ld [PlayerSpriteBottomFlag], a
    ld [PlayerSpriteTopFlag], a

    ret 

.move_player_left
    ld a, [PlayerPosX]
    dec a
    ld [PlayerPosX], a

    ld a, %00100000                 ; Flip sprites horizontally
    ld [PlayerSpriteBottomFlag], a
    ld [PlayerSpriteTopFlag], a

    ret 

.update_player_pos
    call readInput

    ld a, d
    and P1F_1
    call z, .move_player_left
    ld a, d
    and P1F_0
    call z, .move_player_right

    ld a, [PlayerPosX]
    ld [PlayerSpriteBottomX], a
    ld [PlayerSpriteTopX], a

    ld a, [PlayerPosY]
    ld [PlayerSpriteTopY], a
    add 8
    ld [PlayerSpriteBottomY], a
    ret

.mainLoop
    ; wait for vblank
    halt 
    nop 

    call .update_player_pos
    ld a, HIGH(wShadowOAM)  
    call OAMDMA             ; Copy from ShadowOAM to OAM
    jr .mainLoop

loadTileMap:
    ld a, [StartTileMap]
    ld hl, StartTileMap+1
    ld bc, $8800
    ld d, a
    call memcpy
    ret