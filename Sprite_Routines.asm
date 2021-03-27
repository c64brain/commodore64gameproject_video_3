SpriteToCharPos
        lda BIT_TABLE,x                 ; Lookup the bit for this sprite number (0-7)
        eor #$ff                        ; flip all bits (invert the byte %0001 would become %1110)
        and SPRITE_POS_X_EXTEND         ; mask out the X extend bit for this sprite
        sta SPRITE_POS_X_EXTEND         ; store the result back - we've erased just this sprites bit
        sta VIC_SPRITE_X_EXTEND         ; store this in the VIC register for extended X bits

        lda PARAM1                      ; load the X pos in character coords (the column)
        sta SPRITE_CHAR_POS_X,x         ; store it in the character X position variable
        cmp #30                         ; if X is less than 30, no need set the extended bit
        bcc @noExtendedX
        
        lda BIT_TABLE,x                 ; look up the the bit for this sprite number
        ora SPRITE_POS_X_EXTEND         ; OR in the X extend values - we have set the correct bit
        sta SPRITE_POS_X_EXTEND         ; Store the results back in the X extend variable
        sta VIC_SPRITE_X_EXTEND         ; and the VIC X extend register

@noExtendedX
                                        ; Setup our Y register so we transfer X/Y values to the
                                        ; correct VIC register for this sprite
        txa                             ; first, transfer the sprite number to A
        asl                             ; multiply it by 2 (shift left)
        tay                             ; then store it in Y 
                                        ; (note : see how VIC sprite pos registers are ordered
                                        ;  to understand why I'm doing this)

        lda PARAM1                      ; load in the X Char position
        asl                             ; 3 x shift left = multiplication by 8
        asl
        asl
        clc                             
        adc #24 - SPRITE_DELTA_OFFSET_X ; add the edge of screen (24) minus the delta offset
                                        ; to the rough center 8 pixels (1 char) of the sprite

        sta SPRITE_POS_X,x              ; save in the correct sprite pos x variable
        sta VIC_SPRITE_X_POS,y          ; save in the correct VIC sprite pos register


        lda PARAM2                      ; load in the y char position (rows)  "9"
        sta SPRITE_CHAR_POS_Y,x         ; store it in the character y pos for this sprite
        asl                             ; 3 x shift left = multiplication by 8
        asl
        asl
        clc
        adc #50 - SPRITE_DELTA_OFFSET_Y ; add top edge of screen (50) minus the delta offset - 42
        sta SPRITE_POS_Y,x              ; store in the correct sprite pos y variable 
        sta VIC_SPRITE_Y_POS,y          ; and the correct VIC sprite pos register

        lda #0
        sta SPRITE_POS_X_DELTA,x        ;set both x and y delta values to 0 - we are aligned
        sta SPRITE_POS_Y_DELTA,x        ;on a character border (for the purposes of collisions)
        rts

#endregion

;===================================================================================================
;                                                                               SET SPRITE IMAGE
;===================================================================================================
; Sets the sprite image for a hardware sprite, and sets up its pointers for both screens
;---------------------------------------------------------------------------------------------------
; A = Sprite image number
; X = Hardware sprite
;
; Leaves registers intact
;---------------------------------------------------------------------------------------------------
#region "SetSpriteImage"
SetSpriteImage
        pha
        clc
        adc #SPRITE_BASE                        ; Sprite image = image num + base
        sta SPRITE_POINTER_BASE1,x
        sta SPRITE_POINTER_BASE2,x             
        pla
        rts

#endregion

;===================================================================================================
;                                                                               INIT SPRITE ANIM
;---------------------------------------------------------------------------------------------------
;
; Setup and initialize a sprites animations
;
; X = Sprite number
; ZERO_PAGE_POINTER_1 = animation list address
;
; Modifies A,Y
;---------------------------------------------------------------------------------------------------
#region "InitSpriteAnim"
InitSpriteAnim
        lda #1                          ; Reset Anim counter to first frame
        sta SPRITE_ANIM_COUNT,x

        txa                             ; copy sprite number to A
        asl                             ; multiply it by 2 (so we can index a word)
        tay                             ; transfer result to Y
                                        ; reads "ANIM_PLAYER_" or "ANIM_ENEMY_"
        lda ZEROPAGE_POINTER_1          ; Get ANIM_PLAYER_IDLE address
        sta SPRITE_ANIMATION,y          ; in the correct 'slot' for this sprite
        lda ZEROPAGE_POINTER_1 + 1
        sta SPRITE_ANIMATION + 1,y      ; SPRITE_ANIMATION = "ANIM_PLAYER_" (example)

        ldy #0                          ; First byte in the list is the timer
        lda (ZEROPAGE_POINTER_1),y      ; fetch it
        sta SPRITE_ANIM_TIMER,x         ; store it in this sprites timer slot


        iny                             ; increment Y to 1 - the first anim frame 
        lda (ZEROPAGE_POINTER_1),y      ; load it
 
                                        ; right now we have the sprite image in A
                                        ; and the sprite number in X, which is exactly what
                                        ; what we need to use SetSpriteImage
        jsr SetSpriteImage

        cpx #0                          ; if the sprite = 0, then we are setting the player sprite
        beq @secondSprite               ; the player uses 2 sprites        
        rts


@secondSprite
                                        ; We don't need to set all the info for this sprite
        inx                             ; increment X to the next hardware sprite
        clc                             ; add one to the current anim frame number
        adc #1                          ; because our background sprite is the next frame.
        
        jsr SetSpriteImage              ; Now set the sprite image
        
        rts

#endRegion

;---------------------------------------------------------------------------------------------------
;                                                                          SPRITE POINTER TABLES
;---------------------------------------------------------------------------------------------------

                                                ; Lookup tables for setting Sprite Pointers for the
                                                ; correct screens

SPRITE_POINTER_BASE1 = SCREEN1_MEM + $3f8
SPRITE_POINTER_BASE2 = SCREEN2_MEM + $3f8
SPRITE_POINTER_BASE3 = SCREEN2_MEM + $3f8

;---------------------------------------------------------------------------------------------------
;===================================================================================================
;                                                                            SPRITE HANDLING DATA
;===================================================================================================                                        


SPRITE_IS_ACTIVE
        byte $00,$00,$00,$00,$00,$00,$00,$00
                                                        ; Hardware sprite X position
SPRITE_POS_X
        byte $00,$00,$00,$00,$00,$00,$00,$00
                                                        ; Delta X position (0-7) - within a char
SPRITE_POS_X_DELTA
        byte $00,$00,$00,$00,$00,$00,$00,$00

SPRITE_CHAR_POS_X                                       ; Char pos X - sprite position in character
        byte $00,$00,$00,$00,$00,$00,$00,$00            ; coords (0-40)
SPRITE_DELTA_TRIM_X
        byte $00,$00,$00,$00,$00,$00,$00,$00            ; Trim delta for better collisions

SPRITE_POS_X_EXTEND                                     ; extended flag for X positon > 255
        byte $00                                        ; bits 0-7 correspond to sprite numbers


SPRITE_POS_Y                                            ; Hardware sprite Y position
        byte $00,$00,$00,$00,$00,$00,$00,$00
SPRITE_POS_Y_DELTA
        byte $00,$00,$00,$00,$00,$00,$00,$00
SPRITE_CHAR_POS_Y
        byte $00,$00,$00,$00,$00,$00,$00,$00

SPRITE_ANIM_TIMER
        byte $00,$00,$00,$00,$00,$00,$00,$00    ; Timing and playback direction for current anim 
SPRITE_ANIM_COUNT
        byte $00,$00,$00,$00,$00,$00,$00,$00    ; Position in the anim list

                                                ; Pointer to current animation table
SPRITE_ANIMATION
        word $0000,$0000,$0000,$0000
        word $0000,$0000,$0000,$0000  
                 
;===================================================================================================
;                                                                       SPRITE ANIMATION TABLES
;===================================================================================================
; Anims are held in a block of data containing info and a list of anim frames.
; byte 0 = Timing mask:
;          The lower 4 bits contain a mask we will and with the master timer, if the result is
;          is 0 we will go to the next frame
;          valid values are those that use all bits (1,3,5,7,15)
.
;          Bit 7 is used for the direction of the animation (in ping pong anims). if we set it
;          we can then use bmi (Branch MInus) to see if we count backwards instead of forwards
;
; byte 1 to end = sprite numbers for the animation frames
; 
; The last byte both terminates the animation, and also shows what should be done at the end
; of it.  On a loop we would reset to 0, on a play once anim we would end, on a ping pong type 
; it will start counting backwards
;---------------------------------------------------------------------------------------------------
;---------------------------------------------------------
;                                       ANIMATION TYPES
TYPE_LOOP = $FF
TYPE_PLAY_ONCE = $FE
TYPE_PING_PONG = $FD
;---------------------------------------------------------
ANIM_PLAYER_IDLE                                ; Player idle animation
        byte %0001111
        byte 4,2
        byte TYPE_PING_PONG
