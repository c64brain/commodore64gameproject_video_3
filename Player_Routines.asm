;===============================================================================
; PLAYER SETUP
;===============================================================================
; The Player Sprite here can move around the screen on top of the tiles
; and when the edge is reached, the screen scrolls in that direction.
;===============================================================================

#region "Player Setup"
PlayerInit

        ;------------------------------------------------------------------------------
        ; PLAYER has a strange setup as it's ALWAYS going to be using sprites 0 and 1
        ; As well as always being 'active' (used)
        ;------------------------------------------------------------------------------

        lda #COLOR_BLACK
        sta VIC_BACKGROUND_COLOR
        sta VIC_BORDER_COLOR

        lda #%00000011                          ; Turn on multicolor for sprites 0 and 1
        sta VIC_SPRITE_MULTICOLOR               ; also turn all others to single color

        lda #COLOR_BLACK
        sta VIC_SPRITE_MULTICOLOR_1             ; Set sprite shared multicolor 1 to brown
        lda #COLOR_LTRED
        sta VIC_SPRITE_MULTICOLOR_2             ; set sprite shared multicolor 2 to 'pink'

        lda #COLOR_YELLOW
        sta VIC_SPRITE_COLOR                    ; set sprite 0 color to yellow
        lda #COLOR_BLUE
        sta VIC_SPRITE_COLOR + 1                ; set sprite 1 color to orange (bkground sprite)

        ;------------------------------------------------------------------------------
        ; We now use a system that tracks the sprite position in character coords on
        ; the screen, so to avoid costly calculations every frame, we set the sprite
        ; to a character border intially and track all movement from there. That way
        ; we need only do this set of calculations once in the lifetime of the Player.
        ;
        ; To initally place the sprite, we use 'SpriteToCharPos'
        ;------------------------------------------------------------------------------
; Sprite X position
        lda #19
        sta PARAM1                              ; Sprite Y0 Head

; Sprite Y0 Head
        ldx #0
        lda #9
        sta PARAM2                              ; Sprite Y1 Body/Legs
        jsr SpriteToCharPos

; Sprite Y1 Legs
        ldx #1
        lda #11
        sta PARAM2
        jsr SpriteToCharPos

        ;---------------------------------------------------------------------------
        ; The Sprite active state will be used later to track if a sprite is alive or dead.
        ; The "caps" area below track the limits a sprite walks before the screen is scrolled.
        ;---------------------------------------------------------------------------

        lda #1
        sta SPRITE_IS_ACTIVE            ; Set sprite 0 to active
        sta SPRITE_IS_ACTIVE + 1        ; Set sprite 1 to active
        rts

#endregion


#region "Update Player"

PLAYER_RIGHT_CAP = $1c                      ; Sprite movement caps - at this point we don't
PLAYER_LEFT_CAP = $09                       ; Move the sprite, we scroll the screen
PLAYER_UP_CAP = $04                          
PLAYER_DOWN_CAP = $0F

UpdatePlayer
                                            ; Only update the player if it's active
        lda SPRITE_IS_ACTIVE                ; check against sprite #0 - is it active?
        bne @update 
        rts
@update           
        jsr PlayerStateIdle
        rts

;#endregion

;===============================================================================
; JOYSTICK TESTING
;===============================================================================

#region "JoystickReady"
JoystickReady

        lda SCROLL_MOVING               ; if moving is 'stopped' we can test joystick
        beq @joyready
                                        ; if it's moving but direction is stopped, we're 'fixing'
        lda SCROLL_DIRECTION
        bne @joyready

        lda #1                          ; Send code for joystick NOT ready for input
        rts

@joyready
        lda #SCROLL_STOP                ; reset scroll direction - if it needs to scroll
        sta SCROLL_DIRECTION            ; it will be updated

        lda #0                          ; send code for joystick ready
        rts

#endregion

;===============================================================================
; PLAYER WALKS TO THE RIGHT
;===============================================================================

#region "MovePlayerRight"
MovePlayerRight
        lda MAP_X_POS                   ; load the current MAP X Position          
        cmp #54                         ; the map is 64 tiles wide, the screen is 10 tiles wide
        bne @scrollRight
        lda MAP_X_DELTA                 ; each tile is 4 characters wide (0-3)
        cmp #1                          ; if we hit this limit we don't scroll (or move)
        bne @scrollRight
                                        ;at this point we will revert to move 
        jmp @rightMove
        rts
        ;------------------------------------------ SCROLL RIGHT
                                        ; Pre-scroll check
@scrollRight
        lda #SCROLL_RIGHT               ; Set the direction for scroll and post scroll checks
        sta SCROLL_DIRECTION
        sta SCROLL_MOVING
        lda #0                          ; load 'clear code'
        rts                             ; TODO - ensure collision code is returned

        ;----------------------------------------- MOVE SPRITE RIGHT                                
@rightMove
        bne @rightDone

        lda #0                          ; move code 'clear'
@rightDone
        rts

#endregion

;===============================================================================
; PLAYER WALKS TO THE LEFT
;===============================================================================

#region "Move Player Left"
MovePlayerLeft
        lda MAP_X_POS                   ; Check for map pos X = 0
        bne @scrollLeft                 
        lda MAP_X_DELTA                 ; check for map delta = 0
        bne @scrollLeft
                                        ; We're at the maps left edge
                                        ; So we revert to sprite movement once more
        bpl @leftMove                   ; so we could walk to the edge of screen
        rts

@scrollLeft
        lda #SCROLL_LEFT
        sta SCROLL_DIRECTION
        sta SCROLL_MOVING

        lda #0                          ; return 'clear code'
                                        ; TODO - return clear collision code
        rts
        ;---------------------------------------- MOVE THE PLAYER LEFT ONE PIXEL
@leftMove
        lda #0                          ; move code 'clear'

@leftDone
        rts

#endregion

;===============================================================================
; PLAYER MOVES DOWN THE SCREEN
;===============================================================================

#region "Move Player Down"
MovePlayerDown
        lda MAP_Y_POS
        cmp #$1B
        bne @downScroll
        lda MAP_Y_DELTA
        cmp #02
        bcc @downScroll
        rts

@downScroll
        lda #SCROLL_DOWN
        sta SCROLL_DIRECTION
        sta SCROLL_MOVING
        lda #0                          ; return a clear collision code
        rts

#endregion


;===============================================================================
; PLAYER MOVES UP THE SCREEN
;===============================================================================

#region "MovePlayerUp"
MovePlayerUp
        lda MAP_Y_POS
        bne @upScroll
        clc
        lda MAP_Y_DELTA
        cmp #1
        bcs @upScroll
        rts

@upScroll
        lda #SCROLL_UP
        sta SCROLL_DIRECTION
        sta SCROLL_MOVING
        rts

#endregion

PLAYER_SUBSTATE_ENTER   = 0     ; we have just entered this state
PLAYER_SUBSTATE_RUNNING = 1     ; This state is running normally

;===============================================================================
; PLAYER REMAINS IDLE - Main Entry point of project
;===============================================================================

#region "Player State Idle"
PlayerStateIdle
        lda PLAYER_SUBSTATE                     ; Check for first entry to state
        bne @running

;===============================================================================
; SET IDLE SPRITE
;===============================================================================
        ldx #0                                  ; load sprite number (0) in X
        lda #<ANIM_PLAYER_IDLE                  ; load animation list in ZEROPAGE_POINTER_1 
        sta ZEROPAGE_POINTER_1                  ; byte %00000111
        lda #>ANIM_PLAYER_IDLE
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; setup the animation for Idle
        lda PLAYER_SUBSTATE_RUNNING             ; set the substate to Running
        sta PLAYER_SUBSTATE
        rts 

;===============================================================================
; GET JOYSTICK TEST
;===============================================================================
@running
        jsr JoystickReady
        beq @input
        rts                                     ; not ready for input, we return

;===============================================================================
; CHECK FOR JOYSTICK BUTTON PRESS
;===============================================================================
@input                                          ; process valid joystick input
        lda #%00010000                          ; Mask for bit 0
        bit JOY_2                               ; check zero = jumping (button pressed)
        beq @butPress                           ; continue other checks

;===============================================================================
; CHECK THE VERTICAL MOVEMENT
;===============================================================================
; Is Sprite moving to the Left?
;*******************************************************************************
@horizCheck
        lda JOY_X                               ; horizontal movement
        beq @vertCheck                          ; check zero - ho horizontal input
        bmi @left                               ; negative = left
        
;===============================================================================
; SPRITE IS MOVING RIGHT
;===============================================================================
@right
        jsr PlayerStateWalkRight
        rts

;===============================================================================
; SPRITE IS MOVING LEFT
;=============================================================================== 
@left
        jsr PlayerStateWalkLeft
        rts

;===============================================================================
; CHECK IF JOYSTICK IS MOVING UP OR DOWN
;===============================================================================
@vertCheck
        lda JOY_Y                               ; check vertical joystick input
        beq @end                                ; zero means no input
        bmi @up                                 ; negative means up
        bpl @down                               ; already checked for 0 - so this is positive
        rts
@butPress
        rts

;===============================================================================
; SPRITE IS MOVING UP
;===============================================================================
@up
        jsr PlayerStateWalkUp
        rts

;===============================================================================
; SPRITE IS MOVING DOWN
;===============================================================================
@down
        jsr PlayerStateWalkDown
        rts
@end
        rts

#endregion

;===============================================================================
; PLAYER STATE WALK RIGHT
;===============================================================================

#region "Player State Walking Right"
PlayerStateWalkRight                                     

;===============================================================================
; GET JOYSTICK TEST
;===============================================================================
@running
        jsr JoystickReady
        beq @input                      ; Check creates the 'fix' pause for scroll resetting
        rts

;===============================================================================
; NO JOYSTICK MOVEMEMENT - SET TO IDLE
;===============================================================================
@input
        lda JOY_X
        bmi @idle                       ; if negative we are idling
        beq @idle

;===============================================================================
; SPRITE IS MOVING RIGHT
;===============================================================================
@right
        ldx #0
        jsr MovePlayerRight             ; Move player one pixel across - A = move? 0 or 1
        ldx #1
        jsr MovePlayerRight
@idle
        rts

#endregion

;===============================================================================
; PLAYER STATE WALK LEFT
;===============================================================================

#region "Player State Walking Left"
PlayerStateWalkLeft
        jsr JoystickReady
        beq @input                      ; Check creates the 'fix' pause for scroll resetting
        rts
@input
;===============================================================================
; NO JOYSTICK MOVEMEMENT - SET TO IDLE
;===============================================================================
        lda JOY_X
        bpl @idle                       ; if negative we are idling
        beq @idle

;===============================================================================
; SPRITE IS MOVING LEFT
;===============================================================================
@left
        ldx #0
        jsr MovePlayerLeft              ; Move player one pixel across - A = move? 0 or 1
        ldx #1
        jsr MovePlayerLeft 
@idle
        rts

#endregion

;===============================================================================
; PLAYER STATE WALK UP
;===============================================================================
PlayerStateWalkUp
        jsr JoystickReady
        beq @input                      ; Check creates the 'fix' pause for scroll resetting
        rts

;===============================================================================
; SPRITE IS MOVING UP
;===============================================================================
@input  
        ldx #0
        jsr MovePlayerUp             ; Move player one pixel across - A = move? 0 or 1
        ldx #1
        jsr MovePlayerUp
@idle
        rts

#endregion

;===============================================================================
; PLAYER STATE WALK DOWN
;===============================================================================
PlayerStateWalkDown
        jsr JoystickReady
        beq @input                      ; Check creates the 'fix' pause for scroll resetting
        rts

;===============================================================================
; SPRITE IS MOVING DOWN
;===============================================================================
@input
        ldx #0
        jsr MovePlayerDown             ; Move player one pixel across - A = move? 0 or 1
        ldx #1
        jsr MovePlayerDown

@idle
        rts

#endregion

PLAYER_STATE                            ; Current state - walking, standing, dying, climbing
        byte 0
PLAYER_SUBSTATE
        byte 0 
