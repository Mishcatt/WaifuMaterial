bgPalettes:
    ; Background Palette
    .byte $0F, $2D, $3D, $30 ; dark_gray, light_gray, white
    .byte $0F, $3D, $30, $16 ; light_gray, white, red
    .byte $0F, $0F, $0F, $0F ; dark_gray, light_gray, white
    .byte $0F, $0F, $0F, $0F ; gray, light_gray, white

spritePalettes:
    ; Sprite Palette
    .byte $0F, $2D, $00, $3D ; dark_gray, gray, light_gray
    .byte $0F, $2D, $00, $30 ; dark_gray, gray, white
    .byte $0F, $2D, $3D, $30 ; dark_gray, light_gray, white
    .byte $0F, $3D, $30, $16 ; light_gray, white, red
