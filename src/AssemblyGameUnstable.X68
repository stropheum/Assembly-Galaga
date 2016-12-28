*-----------------------------------------------------------
* Title      : Assembly Game
* Written by : Dale Diaz
* Date       :
* Description: A galaga clone which utilizes randomness, acceleration, a score and player input
*-----------------------------------------------------------
        
*********************
*** Global Values ***
*********************
ALL_REG                     REG     D0-D7/A0-A6
LINE_RENDERING_REGS         REG     D0-D4
ALL_REG_BYTE_SIZE           EQU     60
ARG_1                       EQU     4
ARG_2                       EQU     8
ARG_3                       EQU     12
ARG_4                       EQU     16
ARG_5                       EQU     20
ARG_6                       EQU     24   
ONE_ARG                     EQU     4
TWO_ARGS                    EQU     8
THREE_ARGS                  EQU     12
FOUR_ARGS                   EQU     16
FIVE_ARGS                   EQU     20
SIX_ARGS                    EQU     24  
SET_PEN_COLOR_COMMAND       EQU     80
DRAW_PIXEL_COMMAND          EQU     82
SET_DRAWING_MODE_COMMAND    EQU     92
ENABLE_DOUBLE_BUFFERING     EQU     17
REPAINT_SCREEN              EQU     94
LISTEN_FOR_INPUTS           EQU     19
ONE_BYTE                    EQU     8
BitsPerPixel                EQU     24
BytesPerPixel               EQU     3
SPACE_KEY                   EQU     $20
GET_TIME_COMMAND            EQU     8
   
START:  ORG    $1000
    move.l      #1, FIRST_RUN       // Toggle start screen on first playthrough
    *** Enable double buffering ***
    move.l      #SET_DRAWING_MODE_COMMAND, D0
    move.l      #ENABLE_DOUBLE_BUFFERING, D1
    trap        #15
    
    move.l      #1, BackgroundMusicPlaying
    move.l      #LOAD_DIRECT_X_TASK, D0
    lea         BackgroundMusic, A1
    move.l      #0, D1
    trap        #15
    move.l      #CONTROL_DIRECT_X_TASK, D0
    move.l      #DIRECT_X_LOOP_CMD, D2
    trap        #15
    
START_NEW_GAME:
    *** Lock Player on start screen until they press Enter ***
SHOW_START_SCREEN:
    cmp.l       #1, FIRST_RUN
    bne         BYPASS_START_SCREEN
    JSR         DISPLAY_START_TEXT
    JSR         LISTEN_FOR_GAME_START
    bra         SHOW_START_SCREEN
BYPASS_START_SCREEN:

    move.l      #1, FIRST_REPAINT

    *** Wipe screen ***
    move.l      #CLEAR_SCREEN_VALUE, D1
    move.l      #CLEAR_SCREEN_TASK, D0
    trap        #15

    *** Display Loading Text ***
    move.l      #DISPLAY_TEXT_TRAP_TASK, D0
    move.l      #LOADING_TEXT_X_POS, D1
    move.l      #LOADING_TEXT_Y_POS, D2
    lea         LOADING_TEXT, A1
    trap        #15
    move.l      #REPAINT_SCREEN, D0
    trap        #15
    
    *** Add background image to the stack and generate bitmap data ***
    lea         BackgroundImage, A0
    move.l      A0, -(SP)
    JSR         GENERATE_BACKGROUND_IMAGE_DATA 
    move.l      #ONE_ARG, D0
    add.l       D0, SP
    
    *** Add player image to the stack and generate bitmap data ***
    lea         PlayerImage, A0
    move.l      A0, -(SP)
    JSR         GENERATE_PLAYER_IMAGE_DATA
    move.l      #ONE_ARG, D0
    add.l       D0, SP
    
    *** Add enemy image to the stack and generate bitmap data ***
    lea         EnemyImage, A0
    move.l      A0, -(SP)
    JSR         GENERATE_ENEMY_IMAGE_DATA
    move.l      #ONE_ARG, D0
    add.l       D0, SP
    
    *** Temp: set static projectile for rendering ***
    move.l      #170, PROJECTILE_X_POS
    move.l      #PLAYER_Y_POSITION, PROJECTILE_Y_POS

    JSR         RENDER_INITIAL_BACKGROUND_IMAGE
    *JSR         RENDER_INITIAL_PLAYER_IMAGE
    *JSR         RENDER_INITIAL_ENEMY_IMAGE

    *** Initialize player values ***
    move.l      #0, PLAYER_X_POSITION
    move.l      #0, D1                  // Player x
    move.l      #PLAYER_Y_POSITION, D2  // Player y
    move.l      #0, PLAYER_X_VEL
    move.l      #0, PLAYER_Y_VEL
    move.l      #0, W_PRESSED
    move.l      #0, A_PRESSED
    move.l      #0, S_PRESSED
    move.l      #0, D_PRESSED
    move.l      #1, PLAYER_ALIVE       // Set player to alive
    move.l      #0, PLAYER_POINTS      // Initialize player score
    move.l      #0, PROJECTILE_FIRED   // Ensure projectile is not initially fired
    
    *** Initialize enemy values ***
    move.l      #2<<8, ENEMY_SPEED
    JSR         seedRandomNumber
	clr.l	    D6
    JSR         getRandomLongIntoD6
    lsr.l       #8, D6                  // Shift off lower bits to leave only word length value
    lsr.l       #8, D6
    move.l      #608, D5
    divu        D5, D6                  // Divide by screen width-enemy width
    lsr.l       #8, D6                  // Shift off whole part to leave remainder
    lsr.l       #8, D6
    move.l      D6, ENEMY_X_POS 
    move.l      #0, ENEMY_Y_POS
    
GAME_LOOP:
    cmp.l       #1, FIRST_REPAINT
    beq         PLAY_START_SOUND
    bra         BYPASS_PLAY_START_SOUND
PLAY_START_SOUND:
    move.l      #0, FIRST_REPAINT
    move.l      #PLAY_SOUND_TRAP_TASK, D0
    lea         FightSound, A1
    trap        #15
BYPASS_PLAY_START_SOUND
    
    cmp.l       #1, PLAYER_ALIVE
    bne         GAME_OVER
    
    *** Render BG chunk over old player data ***
    JSR         CLEAR_PLAYER_IMAGE
    
    *** TODO: divert rendering bg over old player to subroutine ***
    JSR         UPDATE_PLAYER_INPUT         // Update player input values
    JSR         UPDATE_PLAYER_VALUES
    
    move.l      PLAYER_X_POSITION, D1
    add.l       PLAYER_X_VEL, D1
    
    move.l      D1, PLAYER_X_POSITION
    
    JSR         UPDATE_ENEMY_VALUES
    JSR         UPDATE_PLAYER_POSITION      // Clamp player (X:D1, Y:D2) to screen bounds
    JSR         HANDLE_PLAYER_COLLISION
    JSR         CLEAR_7_SEG_DISPLAY         // Wipe 7seg off screen to prepare for next number    
    JSR         RENDER_BG_OVER_PROJECTILE
    JSR         UPDATE_PROJECTILE
    JSR         RENDER_PROJECTILE
    
    *** Display player score on 7seg ***
    move.l      PLAYER_POINTS, -(SP)
    JSR         RENDER_7SEG_VALUE
    adda.l      #ONE_ARG, SP
    
    bra         REDRAW_SCREEN
GAME_OVER:
    move.l      #DISPLAY_TEXT_TRAP_TASK, D0
    move.l      #GAME_OVER_TEXT_X_POS, D1
    move.l      #GAME_OVER_TEXT_Y_POS, D2
    lea         GAME_OVER_TEXT, A1
    trap        #15
    JSR         LISTEN_FOR_RESTART
    cmp.l       #1, PLAYER_ALIVE
    beq         START_NEW_GAME
    
REDRAW_SCREEN:
    *** Move buffered image onto screen ***
    move.l      #REPAINT_SCREEN, D0
    trap        #15
    
    bra         GAME_LOOP
    SIMHALT    

**********************************************************************************************************************
**********************************************************************************************************************
***     ____                 __          _                _____       __                     __  _                 ***
***    / __ \___  ____  ____/ /__  _____(_)___  ____ _   / ___/__  __/ /_  _________  __  __/ /_(_)___  ___  _____ ***
***   / /_/ / _ \/ __ \/ __  / _ \/ ___/ / __ \/ __ `/   \__ \/ / / / __ \/ ___/ __ \/ / / / __/ / __ \/ _ \/ ___/ ***
***  / _, _/  __/ / / / /_/ /  __/ /  / / / / / /_/ /   ___/ / /_/ / /_/ / /  / /_/ / /_/ / /_/ / / / /  __(__  )  ***
*** /_/ |_|\___/_/ /_/\__,_/\___/_/  /_/_/ /_/\__, /   /____/\__,_/_.___/_/   \____/\__,_/\__/_/_/ /_/\___/____/   ***
***                                          /____/                                                                ***
**********************************************************************************************************************
**********************************************************************************************************************

***********************************************************************
*** Byte swaps the value in d7 while preserving all other registers ***
***********************************************************************
*** D6: Temporarily holds the swapped data during bit shifting      ***
*** D7: Returns the byte swapped value after swapping               ***
***********************************************************************
SWAP_LONG_IN_D7:
    movem.l     D6, -(SP)                     

    clr.l       D6
    
    move.b      D7, D6
    
    lsr.l       #8, D7
    lsl.l       #8, D6
    move.b      D7, D6
    
    lsr.l       #8, D7
    lsl.l       #8, D6
    move.b      D7, D6
    
    lsr.l       #8, D7
    lsl.l       #8, D6
    move.b      D7, D6
    
    move.l      D6, D7

    movem.l     (SP)+, D6                        
    RTS

******************************************************************************************************************
*** Parses through the bitmap data and generates global constants for future rendering to optimize performance ***
******************************************************************************************************************
*** D6: Used for storing the number of bytes in the bitmap image                                               ***
*** D7: Used for storing temp data of all dimensional values in the file                                       ***
******************************************************************************************************************
GENERATE_BACKGROUND_IMAGE_DATA:
    movem.l     ARG_1(SP), A0               // Take bitmap image from stack
    move.l      BackgroundImageDataOffset, D7
    JSR         SWAP_LONG_IN_D7    
    adda.l      D7, A0                      // Offset a0 to start of image data
    move.l      A0, BackgroundImageData

    *** After image height is determined, swap and store back in variable ***    
    move.l      (BackgroundHeightLocation), D7
    JSR         SWAP_LONG_IN_D7
    move.l      D7, BackgroundImageHeight
    
    move.l      (BackgroundWidthLocation), D7
    JSR         SWAP_LONG_IN_D7
    
    *** Move the number of unpadded bytes into D6 ***
    move.l      D7, D6
    mulu        #BytesPerPixel, D6          // Multiply number of pixels by bytes per pixel
    
    *** Compute the number of bytes per row with padding in the image ***
    mulu        #BitsPerPixel, D7           // Computes number of bits within the pixel data
    addi.l      #31, D7                     // Adds just under one word to d7
    lsr.l       #5, D7                      // d7 /= 32 with 31 padded will truncate remainder bits that aren't divisible by word length
    lsl.l       #2, D7                      // d7 *= 4 will adjust the value back to byte length (net division of 8 from pixel count)
    move.l      D7, BackgroundImageWidth
    
    *** Compute the number of padded bytes at the end of a row ***
    sub.l       D6, D7                      // Subtract unpadded row length from padded row length
    move.l      D7, BackgroundRowPadding    // Store the number of padded bytes
    RTS
    
*****************************************************************************
*** Using stored background image data and location/dimension arguments,  ***
*** renders a bitmap chunk to the screen                                  ***
*****************************************************************************
*** D1: x position on screen                                              ***
*** D2: y position on screen                                              ***
*** D4: x chunk start in background image                                 ***
*** D5: y chunk start in background image                                 ***
*** BackgroundChunkWidth: width of all chunks rendered from this image    ***
*** BackgroundChunkHeight: height of all chunks rendered from this image  ***
*****************************************************************************
RENDER_BACKGROUND_CHUNK:
    movem.l     ALL_REG,-(SP)                    
    adda.l      #ALL_REG_BYTE_SIZE, SP           

    *** Handle passed arguments ***    
    move.l      ARG_1(SP), D2                       // Pull rendering y position from stack
    move.l      ARG_2(SP), D1                       // Pull rendering x position from stack
    move.l      ARG_3(SP), BackgroundChunkHeight    // Store rendering height
    move.l      ARG_4(SP), BackgroundChunkWidth     // Store rendering width
    move.l      ARG_5(SP), D5                       // Pull bitmap y position from stack
    move.l      ARG_6(SP), D4                       // Pull bitmap x position from stack
    
    move.l      BackgroundImageData, A0
    
    *** Add chunk height to D2 to invert rendering ***
    move.l      BackgroundChunkHeight, D6           // Store chunk height temporarily
    add.l       D6, D2                              // Offset pen y to end of image
    
    *** Offset to rendering position of bitmap data ***
    move.l      BackgroundImageWidth, D7
    mulu.w      D5, D7
    
    add.l       D4, D7
    add.l       D4, D7
    add.l       D4, D7    
    
    adda.l      D7, A0

    *** Initialize rendering loop ***
    move.l      #0, D7                              // Initialize D7 as column counter
    move.l      #0, D3                              // Initialize D3 as row counter
ITERATE_OVER_BACKGROUND_CHUNK:
    *** TODO: Handle rendering ***
    move.l      D1, D6                              // Temporary move pen x to D6 while setting pen color
    
    *** Move next color to D1 ***
    clr         D1
    move.b      (A0)+, D1
    lsl.l       #8, D1
    move.b      (A0)+, D1
    lsl.l       #8, D1
    move.b      (A0)+, D1
    
    move.l      #SET_PEN_COLOR_COMMAND, D0
    trap        #15
    
    *** Draw pixel ***
    move.l      D6, D1                              // Move pen x back to D1
    move.l      #DRAW_PIXEL_COMMAND, D0
    trap        #15
        
    addi.l      #1, D1                              // Offset pen x to the right by one
    addi.l      #1, D7                              // Add 1 to column counter
    
    move.l      BackgroundChunkWidth, D6            // Move chunk width to D6 for comparisons
    cmp.l       D7, D6
    bgt         ITERATE_OVER_BACKGROUND_CHUNK
    
MOVE_TO_NEXT_LINE_BG_IMAGE:
    sub.l       #1, D2                              // Move pen up 1 value
    addi.l      #1, D3                              // Increment y counter
    
    move.l      BackgroundChunkWidth, D6
    sub.l       D6, D1                              // Move pen x back to origin
    
    *** Store remaining row bytes in D6 ***
    move.l      BackgroundImageWidth, D6            // Load Image width
    move.l      BackgroundChunkWidth, D7                
    mulu.w      #BytesPerPixel, D7                  // Convert pixels to bytes
    sub.l       D7, D6                              // Subtract chunk start pos
    add.l       D6, A0                              // Offset to end of row
    
    move.l      #0, D7                              // Reset column counter
    
    move.l      BackgroundChunkHeight, D6           // Move chunk height to d6 for comparisons
    cmp.l       D3, D6
    bgt         ITERATE_OVER_BACKGROUND_CHUNK

    suba.l      #ALL_REG_BYTE_SIZE, SP           
    movem.l     (SP)+, ALL_REG                   
    RTS

**************************************************************************
*** Renders entire background chunk to the entirety of the game screen ***
**************************************************************************    
RENDER_INITIAL_BACKGROUND_IMAGE:
    movem.l     ALL_REG, -(SP)

    move.l      #0, -(SP)               // Start X value of bitmap
    move.l      #0, -(SP)               // Start Y value of bitmap
    move.l      #BG_WIDTH, -(SP)        // Width of chunk
    move.l      #BG_HEIGHT, -(SP)       // Height of chunk
    move.l      #0, -(SP)               // X position on screen
    move.l      #0, -(SP)               // Y position on screen
    JSR         RENDER_BACKGROUND_CHUNK
    move.l      #SIX_ARGS, D0
    add.l       D0, SP
    
    movem.l     (SP)+, ALL_REG
    RTS
    
****************************************************
*** Render player to screen in starting location ***
****************************************************
RENDER_INITIAL_PLAYER_IMAGE:
    movem.l     ALL_REG, -(SP)

    move.l      #0, -(SP)
    move.l      #0, -(SP)
    move.l      #PLAYER_WIDTH, -(SP)
    move.l      #PLAYER_HEIGHT, -(SP)
    move.l      PLAYER_X_POSITION, -(SP)
    move.l      #PLAYER_Y_POSITION, -(SP)
    JSR         RENDER_PLAYER_CHUNK
    move.l      #SIX_ARGS, D0
    add.l       D0, SP
    
    movem.l     (SP)+, ALL_REG
    RTS
    
***************************************************
*** Render enemy to screen in starting location ***
***************************************************
RENDER_INITIAL_ENEMY_IMAGE:
    movem.l     ALL_REG, -(SP)

    move.l      #0, -(SP)
    move.l      #0, -(SP)
    move.l      #ENEMY_WIDTH, -(SP)
    move.l      #ENEMY_HEIGHT, -(SP)
    move.l      #0, -(SP)
    move.l      #0, -(SP)
    JSR         RENDER_ENEMY_CHUNK
    move.l      #SIX_ARGS, D0
    add.l       D0, SP
    
    movem.l     (SP)+, ALL_REG
    RTS

****************************************************************************
*** Generates Player Image Data and stores it in global values           ***
****************************************************************************
*** D6: Used for storing the number of bytes in the bitmap image         ***
*** D7: Used for storing temp data of all dimensional values in the file ***
****************************************************************************
GENERATE_PLAYER_IMAGE_DATA:

    movem.l     ARG_1(SP), A0               // Take bitmap image from stack
    move.l      PlayerImageDataOffset, D7
    JSR         SWAP_LONG_IN_D7    
    adda.l      D7, A0                      // Offset A0 to start of image data
    move.l      A0, PlayerImageData

    *** After image height is determined, swap and store back in variable ***    
    move.l      (PlayerHeightLocation), D7
    JSR         SWAP_LONG_IN_D7
    move.l      D7, PlayerImageHeight
    
    move.l      (PlayerWidthLocation), D7
    JSR         SWAP_LONG_IN_D7
    
    *** Move the number of unpadded bytes into D6 ***
    move.l      D7, D6
    mulu        #BytesPerPixel, D6          // Multiply number of pixels by bytes per pixel
    
    *** Compute the number of bytes per row with padding in the image ***
    mulu        #BitsPerPixel, D7           // Computes number of bits within the pixel data
    addi.l      #31, D7                     // Adds just under one word to D7
    lsr.l       #5, D7                      // D7 /= 32 with 31 padded will truncate remainder bits that aren't divisible by word length
    lsl.l       #2, D7                      // D7 *= 4 will adjust the value back to byte length (net division of 8 from pixel count)
    move.l      D7, PlayerImageWidth
    
    *** Compute the number of padded bytes at the end of a row ***
    sub.l       D6, D7                      // Subtract unpadded row length from padded row length
    move.l      D7, PlayerRowPadding        // Store the number of padded bytes

    RTS
    
****************************************************************************
*** Generates Enemy Image Data and stores it in global values            ***
****************************************************************************
*** D6: Used for storing the number of bytes in the bitmap image         ***
*** D7: Used for storing temp data of all dimensional values in the file ***
****************************************************************************
GENERATE_ENEMY_IMAGE_DATA:

    movem.l     ARG_1(SP), A0               // Take bitmap image from stack
    move.l      EnemyImageDataOffset, D7
    JSR         SWAP_LONG_IN_D7    
    adda.l      D7, A0                      // Offset A0 to start of image data
    move.l      A0, EnemyImageData

    *** After image height is determined, swap and store back in variable ***    
    move.l      (EnemyHeightLocation), D7
    JSR         SWAP_LONG_IN_D7
    move.l      D7, EnemyImageHeight
    
    move.l      (EnemyWidthLocation), D7
    JSR         SWAP_LONG_IN_D7
    
    *** Move the number of unpadded bytes into D6 ***
    move.l      D7, D6
    mulu        #BytesPerPixel, D6          // Multiply number of pixels by bytes per pixel
    
    *** Compute the number of bytes per row with padding in the image ***
    mulu        #BitsPerPixel, D7           // Computes number of bits within the pixel data
    addi.l      #31, D7                     // Adds just under one word to D7
    lsr.l       #5, D7                      // D7 /= 32 with 31 padded will truncate remainder bits that aren't divisible by word length
    lsl.l       #2, D7                      // D7 *= 4 will adjust the value back to byte length (net division of 8 from pixel count)
    move.l      D7, EnemyImageWidth
    
    *** Compute the number of padded bytes at the end of a row ***
    sub.l       D6, D7                      // Subtract unpadded row length from padded row length
    move.l      D7, EnemyRowPadding         // Store the number of padded bytes

    RTS
    
*******************************************************************
*** Renders background image chunk over current player location ***
*******************************************************************
CLEAR_PLAYER_IMAGE:
    movem.l     ALL_REG, -(SP)
    
    move.l      #PLAYER_Y_POSITION, D2
    
    move.l      PLAYER_X_POSITION, D4
    asr.l       #8, D4                  // Shift off fractional bits of player position
    
    move.l      BackgroundImageHeight, D3
    sub.l       D2, D3                  // Subtract player y value from height of image
    sub.l       #PLAYER_HEIGHT, D3      // Subtract player height from image height
    move.l      D4, -(SP)               // Pass player x with fractional bits adjusted off
    move.l      D3, -(SP)
    move.l      #PLAYER_WIDTH, -(SP)    // Chunk size of player width
    move.l      #PLAYER_HEIGHT, -(SP)   // Chunk size of player height
    
    
    move.l      D4, -(SP)               // Pass player x with fractional bits adjusted off
    move.l      #PLAYER_Y_POSITION, -(SP)               // Player y
    JSR         RENDER_BACKGROUND_CHUNK
    move.l      #SIX_ARGS, D0
    add.l       D0, SP
    
    movem.l     (SP)+, ALL_REG
    RTS
    
******************************************************************
*** Renders background image chunk over current enemy location ***
******************************************************************
CLEAR_ENEMY_IMAGE:
    movem.l     ALL_REG, -(SP)
    
    move.l      ENEMY_Y_POS, D2
    asr.l       #8, D2                  // Shift off fractional bits
    
    move.l      ENEMY_X_POS, D4
    
    move.l      BackgroundImageHeight, D3
    sub.l       D2, D3                  // Subtract player y value from height of image
    sub.l       #ENEMY_HEIGHT, D3       // Subtract enemy height from image height
    move.l      D4, -(SP)               // Pass enemy x
    move.l      D3, -(SP)
    move.l      #ENEMY_WIDTH, -(SP)     // Chunk size of enemy width
    move.l      #ENEMY_HEIGHT, -(SP)    // Chunk size of enemy height
    
    
    move.l      D4, -(SP)               // Pass enemy x 
    move.l      D2, -(SP)               // Enemy y with fractioanl bits shifted off
    JSR         RENDER_BACKGROUND_CHUNK
    move.l      #SIX_ARGS, D0
    add.l       D0, SP
    
    movem.l     (SP)+, ALL_REG
    RTS

    
*************************************************************************
*** Using stored player image data and location/dimension arguments,  ***
*** renders a bitmap chunk to the screen                              ***
*************************************************************************
*** D1: x position on screen                                          ***
*** D2: y position on screen                                          ***
*** D4: x chunk start in player image                                 ***
*** D5: y chunk start in player image                                 ***
*** PlayerChunkWidth: width of all chunks rendered from this image    ***
*** PlayerChunkHeight: height of all chunks rendered from this image  ***
*************************************************************************
RENDER_PLAYER_CHUNK:
    movem.l     ALL_REG,-(SP)                                  
    adda.l      #ALL_REG_BYTE_SIZE, SP             

    *** Handle passed arguments ***    
    move.l      ARG_1(SP), D2                       // Pull rendering y position from stack
    move.l      ARG_2(SP), D1                       // Pull rendering x position from stack
    move.l      ARG_3(SP), PlayerChunkHeight        // Store rendering height
    move.l      ARG_4(SP), PlayerChunkWidth         // Store rendering width
    move.l      ARG_5(SP), D5                       // Pull bitmap y position from stack
    move.l      ARG_6(SP), D4                       // Pull bitmap x position from stack
    
    move.l      PlayerImageData, A0
    
    *** Add chunk height to D2 to invert rendering ***
    move.l      PlayerChunkHeight, D6               // Store chunk height temporarily
    add.l       D6, D2                              // Offset pen y to end of image
    
    *** Offset to rendering position of bitmap data ***
    move.l      PlayerImageWidth, D7
    mulu.w      D5, D7
    
    add.l       D4, D7
    add.l       D4, D7
    add.l       D4, D7    
    
    adda.l      D7, A0

    *** Initialize rendering loop ***
    move.l      #0, D7                              // Initialize D7 as column counter
    move.l      #0, D3                              // Initialize D3 as row counter
ITERATE_OVER_PLAYER_CHUNK:
    *** TODO: Handle rendering ***
    move.l      D1, D6                              // Temporary move pen x to D6 while setting pen color
    
    *** Move next color to D1 ***
    clr         D1
    move.b      (A0)+, D1
    lsl.l       #8, D1
    move.b      (A0)+, D1
    lsl.l       #8, D1
    move.b      (A0)+, D1
    
    move.l      #SET_PEN_COLOR_COMMAND, D0
    trap        #15
    
    *** Draw pixel ***
    cmp.l       #$FF00FF, D1
    beq         DISREGARD_PLAYER_PIXEL
    
    move.l      D6, D1                              // Move pen x back to D1
    move.l      #DRAW_PIXEL_COMMAND, D0
    trap        #15
DISREGARD_PLAYER_PIXEL:
    move.l      D6, D1                              // Move pen x back to D1    
    addi.l      #1, D1                              // Offset pen x to the right by one
    addi.l      #1, D7                              // Add 1 to column counter
    
    move.l      PlayerChunkWidth, D6                // Move chunk width to D6 for comparisons
    cmp.l       D7, D6
    bgt         ITERATE_OVER_PLAYER_CHUNK
    
MOVE_TO_NEXT_LINE_PLAYER_IMAGE:
    sub.l       #1, D2                              // Move pen up 1 value
    addi.l      #1, D3                              // Increment y counter
    
    move.l      PlayerChunkWidth, D6
    sub.l       D6, D1                              // Move pen x back to origin
    
    *** Store remaining row bytes in D6 ***
    move.l      PlayerImageWidth, D6                // Load Image width
    move.l      PlayerChunkWidth, D7                
    mulu.w      #BytesPerPixel, D7                  // Convert pixels to bytes
    sub.l       D7, D6                              // Subtract chunk start pos
    add.l       D6, A0                              // Offset to end of row
    
    move.l      #0, D7                              // Reset column counter
    
    move.l      PlayerChunkHeight, D6               // Move chunk height to d6 for comparisons
    cmp.l       D3, D6
    bgt         ITERATE_OVER_PLAYER_CHUNK
    
    suba.l      #ALL_REG_BYTE_SIZE, SP           
    movem.l     (SP)+, ALL_REG                   
    RTS
    
*************************************************************************
*** Using stored enemy image data and location/dimension arguments,   ***
*** renders a bitmap chunk to the screen                              ***
*************************************************************************
*** D1: x position on screen                                          ***
*** D2: y position on screen                                          ***
*** D4: x chunk start in enemy image                                  ***
*** D5: y chunk start in enemy image                                  ***
*** EnemyChunkWidth: width of all chunks rendered from this image     ***
*** EnemyChunkHeight: height of all chunks rendered from this image   ***
*************************************************************************
RENDER_ENEMY_CHUNK:
    movem.l     ALL_REG,-(SP)                                  
    adda.l      #ALL_REG_BYTE_SIZE, SP             

    *** Handle passed arguments ***    
    move.l      ARG_1(SP), D2                       // Pull rendering y position from stack
    move.l      ARG_2(SP), D1                       // Pull rendering x position from stack
    move.l      ARG_3(SP), EnemyChunkHeight         // Store rendering height
    move.l      ARG_4(SP), EnemyChunkWidth          // Store rendering width
    move.l      ARG_5(SP), D5                       // Pull bitmap y position from stack
    move.l      ARG_6(SP), D4                       // Pull bitmap x position from stack
    
    move.l      EnemyImageData, A0
    
    *** Add chunk height to D2 to invert rendering ***
    move.l      EnemyChunkHeight, D6                // Store chunk height temporarily
    add.l       D6, D2                              // Offset pen y to end of image
    
    *** Offset to rendering position of bitmap data ***
    move.l      EnemyImageWidth, D7
    mulu.w      D5, D7
    
    add.l       D4, D7
    add.l       D4, D7
    add.l       D4, D7    
    
    adda.l      D7, A0

    *** Initialize rendering loop ***
    move.l      #0, D7                              // Initialize D7 as column counter
    move.l      #0, D3                              // Initialize D3 as row counter
ITERATE_OVER_ENEMY_CHUNK:
    *** TODO: Handle rendering ***
    move.l      D1, D6                              // Temporary move pen x to D6 while setting pen color
    
    *** Move next color to D1 ***
    clr         D1
    move.b      (A0)+, D1
    lsl.l       #8, D1
    move.b      (A0)+, D1
    lsl.l       #8, D1
    move.b      (A0)+, D1
    
    *** Draw pixel ***    
    cmp.l       #$FF00FF, D1
    beq         DISREGARD_ENEMY_PIXEL
    
    move.l      #SET_PEN_COLOR_COMMAND, D0
    trap        #15
    
    move.l      D6, D1
    
    move.l      #DRAW_PIXEL_COMMAND, D0
    trap        #15
    
DISREGARD_ENEMY_PIXEL:
    move.l      D6, D1                              // Move pen x back to D1
    addi.l      #1, D1                              // Offset pen x to the right by one
    addi.l      #1, D7                              // Add 1 to column counter
    
    move.l      EnemyChunkWidth, D6                 // Move chunk width to D6 for comparisons
    cmp.l       D7, D6
    bgt         ITERATE_OVER_ENEMY_CHUNK
    
MOVE_TO_NEXT_LINE_ENEMY_IMAGE:
    sub.l       #1, D2                              // Move pen up 1 value
    addi.l      #1, D3                              // Increment y counter
    
    move.l      EnemyChunkWidth, D6
    sub.l       D6, D1                              // Move pen x back to origin
    
    *** Store remaining row bytes in D6 ***
    move.l      EnemyImageWidth, D6                 // Load Image width
    move.l      EnemyChunkWidth, D7                
    mulu.w      #BytesPerPixel, D7                  // Convert pixels to bytes
    sub.l       D7, D6                              // Subtract chunk start pos
    add.l       D6, A0                              // Offset to end of row
    
    move.l      #0, D7                              // Reset column counter
    
    move.l      EnemyChunkHeight, D6                // Move chunk height to d6 for comparisons
    cmp.l       D3, D6
    bgt         ITERATE_OVER_ENEMY_CHUNK
    
    suba.l      #ALL_REG_BYTE_SIZE, SP           
    movem.l     (SP)+, ALL_REG                   
    RTS
    
****************************************
*** Determines player movement speed ***
****************************************
*** D0: Reserved for trap tasks      ***
*** D1: Player input value           ***
****************************************
UPDATE_PLAYER_INPUT:
    movem.l     D0, -(SP)                          
    movem.l     D1, -(SP)                          
    movem.l     D2, -(SP)                          
    
    *** Check player input and set velocity values ***
    MOVE.B      #LISTEN_FOR_INPUTS, D0
    move.l      #SPACE_KEY, D1
    lsl.l       #8, D1    
    move.b      #'A', D1
    lsl.l       #8, D1
    move.b      #'D', D1
    TRAP        #15
    
    andi.l      #$FFFFFF, D1
    beq         NO_INPUT
    
    move.l      #HAVE_HAD_NO_INPUT, D0
    beq         BYPASS_NO_INPUT
    move.l      #0, HAVE_HAD_NO_INPUT
    
    *** Check if D key pressed ***
    cmp.b       #$FF, D1
    beq         SET_D_PRESSED
    move.l      #0, D_PRESSED
    bra         BYPASS_D_PRESSED
SET_D_PRESSED:
    move.l      #1, D_PRESSED
BYPASS_D_PRESSED:

    *** Check if A key pressed ***
    lsr.l       #8, D1
    cmp.b       #$FF, D1
    beq         SET_A_PRESSED
    move.l      #0, A_PRESSED
    bra         BYPASS_A_PRESSED
SET_A_PRESSED:
    move.l      #1, A_PRESSED
BYPASS_A_PRESSED:
    
    *** Check if space key pressed ***
    LSR.L       #8, D1
    cmp.b       #$FF, D1
    beq         SET_SPACE_PRESSED
    move.l      #0, SPACE_PRESSED
    bra         BYPASS_SPACE_PRESSED
SET_SPACE_PRESSED:
    move.l      #1, SPACE_PRESSED
    move.l      PROJECTILE_FIRED, D2
    cmp.l       #0, D2
    bne         DONT_FIRE_NEW_PROJECTILE
    *** If no projectile exists, fire projectile at player x/y pos ***
    move.l      PLAYER_X_POSITION, D2
    asr.l       #8, D2                      // Shift off fractional bits of xPos
    add.l       #PROJECTILE_POS_OFFSET, D2
    move.l      D2, PROJECTILE_X_POS
    move.l      #PLAYER_Y_POSITION, D2
    move.l      D2, PROJECTILE_Y_POS
    move.l      #1, PROJECTILE_FIRED
    
    lea         BulletFiredSound, A1
    move.l      #PLAY_SOUND_TRAP_TASK, D0
    trap        #15
DONT_FIRE_NEW_PROJECTILE:
    
BYPASS_SPACE_PRESSED:
    
    bra         BYPASS_NO_INPUT
    
NO_INPUT:
    move.l      #1, HAVE_HAD_NO_INPUT
    move.l      #0, A_PRESSED
    move.l      #0, D_PRESSED
BYPASS_NO_INPUT:
    
    movem.l     (SP)+, D2                        
    movem.l     (SP)+, D1                        
    movem.l     (SP)+, D0                        
    RTS

*************************************************************************************************************
*** De-renders old projectile data by drawing that segment of the background over the old projectile data ***
*************************************************************************************************************
RENDER_BG_OVER_PROJECTILE:
    movem.l     ALL_REG, -(SP)     

    move.l      PROJECTILE_FIRED, D0
    cmp.l       #0, D0
    beq         BYPASS_RENDER_OVER_PROJECTILE                   

    move.l      PROJECTILE_X_POS, D1
    move.l      BackgroundImageHeight, D2
    sub.l       PROJECTILE_Y_POS, D2
    sub.l       #PROJECTILE_LENGTH, D2
    move.l      #1, D3
    move.l      #PROJECTILE_LENGTH, D4
    move.l      PROJECTILE_X_POS, D5
    move.l      PROJECTILE_Y_POS, D6
    
    move.l      D1, -(SP)
    move.l      D2, -(SP)
    move.l      D3, -(SP)
    move.l      D4, -(SP)
    move.l      D5, -(SP)
    move.l      D6, -(SP)
    JSR         RENDER_BACKGROUND_CHUNK
    move.l      #SIX_ARGS, D0
    add.l       D0, SP
BYPASS_RENDER_OVER_PROJECTILE:

    movem.l     (SP)+, ALL_REG                       
    RTS
    
********************************************************************************
*** Renders projectile on screen in current position if projectile is active ***
********************************************************************************
RENDER_PROJECTILE:
    movem.l     ALL_REG, -(SP)                        

    move.l      PROJECTILE_FIRED, D7
    cmp.l       #1, D7
    bne         IGNORE_RENDER_PROJECTILE
    
    move.l      #SET_PEN_COLOR_COMMAND, D0
    move.l      #$FFFFFF, D1
    trap        #15

    move.l      PROJECTILE_X_POS, D1
    move.l      PROJECTILE_Y_POS, D2
    move.l      D1, D3
    move.l      D2, D4
    add.l       #PROJECTILE_LENGTH, D4
    
    move.l      #DRAW_LINE_TRAP_TASK, D0
    trap        #15
    *move.l      #0, SPACE_PRESSED
IGNORE_RENDER_PROJECTILE:

    movem.l     (SP)+, ALL_REG                       
    RTS
    
**************************************************************************************************
*** Moves the projectile towards the top of the screen and despawns it when it reaches the top ***
**************************************************************************************************
UPDATE_PROJECTILE:
    movem.l     ALL_REG, -(SP)                    

    move.l      PROJECTILE_FIRED, D0
    cmp.l       #1, D0
    bne         DISREGARD_PROJECTILE_UPDATE

    move.l      PROJECTILE_X_POS, D1
    move.l      PROJECTILE_Y_POS, D2
    sub.l       #PROJECTILE_SPEED, D2       // Subtract speed because projectile moves up
    
    cmp.l       #(0-PROJECTILE_LENGTH), D2
    blt         DESPAWN_PROJECTILE
    
    *** Test code handle collisions within update ***
    JSR         HANDLE_PROJECTILE_COLLISION
    move.l      PROJECTILE_FIRED, D0
    cmp.l       #1, D0
    bne         DESPAWN_PROJECTILE
    
    move.l      D1, PROJECTILE_X_POS
    move.l      D2, PROJECTILE_Y_POS
    bra         DISREGARD_PROJECTILE_UPDATE
    
DESPAWN_PROJECTILE:
    move.l      #0, PROJECTILE_FIRED
    
    move.l      PROJECTILE_X_POS, -(SP)
    move.l      #0, -(SP)
    move.l      #2, -(SP)
    move.l      #2, -(SP)
    move.l      PROJECTILE_X_POS, -(SP)
    move.l      PROJECTILE_Y_POS, -(SP)
    JSR         RENDER_BACKGROUND_CHUNK
    move.l      #SIX_ARGS, D0
    add.l       D0, SP
    
DISREGARD_PROJECTILE_UPDATE:
    
    movem.l     (SP)+, ALL_REG                   
    RTS
    
********************************************************************************
*** Despawns projectile and respawns enemy with explosion sound if colliding ***
********************************************************************************
HANDLE_PROJECTILE_COLLISION:
    movem.l     ALL_REG, -(SP)
    
    *** Only assert collisions if projectile is on the screen ***
    move.l      PROJECTILE_FIRED, D1
    cmp.l       #1, D1
    bne         DO_NOT_COLLIDE
    
    move.l      PROJECTILE_X_POS, D1            // Store projectile x
    move.l      PROJECTILE_Y_POS, D2            // Store projectile y
    move.l      ENEMY_X_POS, D3                 // Store enemy left bound
    move.l      ENEMY_Y_POS, D4                 // Store enemy upper bound
    asr.l       #8, D4                          // Shift off fractional bits
    move.l      ENEMY_X_POS, D5                 
    add.l       #ENEMY_WIDTH, D5                // Store enemy right bound
    move.l      ENEMY_Y_POS, D6        
    asr.l       #8, D6                          // Shift off fractional bits
    add.l       #ENEMY_HEIGHT, D6               // Store enemy lower bound
ASSERT_PROJECTILE_ABOVE_LOWER:
    cmp.l       D2, D6
    blt         DO_NOT_COLLIDE
ASSERT_PROJECTILE_BELOW_UPPER:
    cmp.l       D2, D4
    bgt         DO_NOT_COLLIDE
ASSERT_PROJECTILE_RIGHT_OF_LEFT:
    cmp.l       D1, D3
    bgt         DO_NOT_COLLIDE
ASSERT_PROJECTILE_LEFT_OF_RIGHT:
    cmp.l       D1, D5
    blt         DO_NOT_COLLIDE
    
    *** If all asserts are met, despawn bullet, respawn projectile and play explosion sound ***
    move.l      #0, PROJECTILE_FIRED
    
    JSR         RESPAWN_ENEMY
    lea         ExplosionSound, A1
    move.l      #PLAY_SOUND_TRAP_TASK, D0
    trap        #15
    
    *** Increment player score ***
    move.l      PLAYER_POINTS, D1
    add.l       #1, D1
    move.l      D1, PLAYER_POINTS
    
DO_NOT_COLLIDE:
    movem.l     (SP)+, ALL_REG
    RTS
    
********************************************************************************************************
*** Kills current enemy, respawns him at the top of the screen in a random xPos with increased speed ***
********************************************************************************************************
RESPAWN_ENEMY:
    movem.l     ALL_REG, -(SP)
    
    JSR         CLEAR_ENEMY_IMAGE
    *move.l      ENEMY_X_POS, D1
    *add.l       #10, D1
    *move.l      D1, ENEMY_X_POS
    clr.l	    D6
    JSR         getRandomLongIntoD6
    lsr.l       #8, D6                  // Shift off lower bits to leave only word length value
    lsr.l       #8, D6
    move.l      #608, D5
    divu        D5, D6                  // Divide by screen width-enemy width
    lsr.l       #8, D6                  // Shift off whole part to leave remainder
    lsr.l       #8, D6
    move.l      D6, ENEMY_X_POS
    
    move.l      #0, ENEMY_Y_POS
    add.l       #ENEMY_SPEED_INCREMENT, ENEMY_SPEED  // Speed up enemy
    
    movem.l     (SP)+, ALL_REG
    RTS
    
**********************************************************************************************
*** Updates enemy velocity based on constant speed                                         ***
**********************************************************************************************
*** D1: Stores the enemy xPos                                                              ***
*** D2: Stores the enemy yPos                                                              ***
*** D3: Stores the lower bound of the screen offset by enemy height                        ***
**********************************************************************************************
UPDATE_ENEMY_VALUES:                          
    movem.l     ALL_REG, -(SP)          

    JSR         CLEAR_ENEMY_IMAGE                      
    
    move.l      ENEMY_X_POS,  D1
    move.l      ENEMY_Y_POS,  D2
    
    add.l       ENEMY_SPEED, D2
    move.l      D2, D4                      // Copy speed to preserve fractional bits
    asr.l       #8, D2                      // Shift off fractional bits
    move.l      BackgroundImageHeight, D3
    sub.l       #ENEMY_HEIGHT, D3
    cmp.l       D3, D2
    bgt         RESET_ENEMY_TO_TOP
    move.l      D4, ENEMY_Y_POS
    bra         BYPASS_ENEMY_RESET
RESET_ENEMY_TO_TOP:
    JSR         RESPAWN_ENEMY
    move.l      ENEMY_X_POS, D1
    move.l      ENEMY_Y_POS, D2
    move.l      #0, D2
BYPASS_ENEMY_RESET:

    *** Renders enemy to the buffer ***
    move.l      #0, -(SP)               
    move.l      #0, -(SP)
    move.l      #ENEMY_WIDTH, -(SP)
    move.l      #ENEMY_HEIGHT, -(SP)
    move.l      D1, -(SP)
    move.l      D2, -(SP)
    JSR         RENDER_ENEMY_CHUNK
    move.l      #SIX_ARGS, D0
    add.l       D0, SP

    movem.l     (SP)+, ALL_REG                   
    RTS
    
**********************************************************************************************
*** Updates player velocity based on currently pressed keys                                ***
**********************************************************************************************
*** D5: stores the boolean values for individual key presses                               ***
*** D6: Stores the directional velocities which will be transferred to the player velocity ***
**********************************************************************************************
UPDATE_PLAYER_VALUES:
    movem.l     D5, -(SP)                          
    movem.l     D6, -(SP)                               
    
    move.l      #0, PLAYER_X_VEL
CHECK_PLAYER_MOVING_LEFT:
    move.l      A_PRESSED, D5
    cmp.l       #1, D5
    beq         SET_PLAYER_MOVING_LEFT
    bra         CHECK_PLAYER_MOVING_RIGHT
SET_PLAYER_MOVING_LEFT:
    move.l      #MOVING_LEFT, D6
    move.l      D6, PLAYER_X_VEL
    bra         END_X_VEL_ASSERTIONS
CHECK_PLAYER_MOVING_RIGHT:
    move.l      D_PRESSED, D5
    cmp.l       #1, D5
    beq         SET_PLAYER_MOVING_RIGHT
    bra         END_X_VEL_ASSERTIONS
SET_PLAYER_MOVING_RIGHT:
    move.l      #MOVING_RIGHT, D6
    move.l      D6, PLAYER_X_VEL
END_X_VEL_ASSERTIONS:

    movem.l     (SP)+, D6                        
    movem.l     (SP)+, D5                        
    RTS
    
********************************************************************************************************
*** Takes player x,y in D1, D2, clamps them to screen bounds, and updates position in same registers ***
********************************************************************************************************
UPDATE_PLAYER_POSITION:
    movem.l     D1, -(SP)
    movem.l     D2, -(SP)

    move.l      PLAYER_X_POSITION, D1
    asr.l       #8, D1                  // Shift off fractional bits
    move.l      #PLAYER_Y_POSITION, D2

    cmp.l       #0, D1
    ble         CLAMP_LOWER_X
    cmp.l       #(BG_WIDTH-PLAYER_WIDTH), D1
    bgt         CLAMP_UPPER_X
    bra         DO_NOT_CLAMP_X
CLAMP_LOWER_X:
    move.l      #0, D1
    move.l      #0, PLAYER_X_POSITION
    bra         END_X_CLAMP
CLAMP_UPPER_X:
    move.l      #(BG_WIDTH-PLAYER_WIDTH), D1
    asl.l       #8, D1                  // Shift fractional bits back after clamping
END_X_CLAMP:
    move.l      D1, PLAYER_X_POSITION
    asr.l       #8, D1
DO_NOT_CLAMP_X:

    *** Renders player to the buffer ***
    move.l      #0, -(SP)               
    move.l      #0, -(SP)
    move.l      #PLAYER_WIDTH, -(SP)
    move.l      #PLAYER_HEIGHT, -(SP)
    move.l      D1, -(SP)
    move.l      D2, -(SP)
    JSR         RENDER_PLAYER_CHUNK
    move.l      #SIX_ARGS, D0
    add.l       D0, SP
    
    movem.l     (SP)+, D2
    movem.l     (SP)+, D1
    RTS
    
******************************************************************
*** If player is dead, game will restart when space is pressed ***
******************************************************************
LISTEN_FOR_RESTART:
    movem.l     ALL_REG, -(SP)
    
    *** Check player input and set velocity values ***
    MOVE.B      #LISTEN_FOR_INPUTS, D0
    move.l      #ENTER_KEY, D1
    trap        #15
    
    cmp.b       #$FF, D1
    beq         RESPAWN_PLAYER
    bra         BYPASS_RESPAWN_PLAYER
RESPAWN_PLAYER:
    move.l      #1, PLAYER_ALIVE
BYPASS_RESPAWN_PLAYER:
    
    movem.l     (SP)+, ALL_REG
    RTS

******************************************************************************
*** Determines if the player is colliding with the enemy and ends the game ***
******************************************************************************    
HANDLE_PLAYER_COLLISION:
    movem.l     ALL_REG, -(SP)
    
    move.l      PLAYER_X_POSITION, D1           // Store player LEFT
    asr.l       #8, D1                          // Shift off fractional bits
    move.l      #PLAYER_Y_POSITION, D2          // Store player TOP
    move.l      D1, D3                          // Store player RIGHT
    add.l       #PLAYER_WIDTH, D3
    move.l      ENEMY_X_POS, D4                 // Store enemy LEFT
    move.l      D4, D5                          // Store enemy RIGHT
    add.l       #ENEMY_WIDTH, D5
    move.l      ENEMY_Y_POS, D6                 // Store enemy TOP
    asr.l       #8, D6                          // Shift off fractional bits
    move.l      D6, D7                          // Store enemy BOTTOM
    add.l       #ENEMY_HEIGHT, D7
    
ASSERT_PLAYER_LEFT_COL:
    move.l      PLAYER_X_POSITION, D1
    asr.l       #8, D1
    move.l      ENEMY_X_POS, D2
    add.l       #ENEMY_WIDTH, D2
    cmp.l       D1, D2
    blt         DO_NOT_COLLIDE_PLAYER
ASSERT_PLAYER_RIGHT_COL:
    move.l      PLAYER_X_POSITION, D1
    asr.l       #8, D1
    move.l      ENEMY_X_POS, D2
    add.l       #PLAYER_WIDTH, D1
    cmp.l       D1, D2
    bgt         DO_NOT_COLLIDE_PLAYER
ASSERT_PLAYER_TOP_COL:
    move.l      #PLAYER_Y_POSITION, D1
    move.l      ENEMY_Y_POS, D2
    asr.l       #8, D2                      // Shift off fractional bits
    add.l       #ENEMY_HEIGHT, D2
    cmp.l       D1, D2
    blt         DO_NOT_COLLIDE_PLAYER
ASSERT_PLAYER_BOTTOM_COL:
    move.l      #PLAYER_Y_POSITION, D1
    move.l      ENEMY_Y_POS, D2
    asr.l       #8, D2                      // Shift off fractional bits
    add.l       #PLAYER_HEIGHT, D1
    cmp.l       D1, D2
    bgt         DO_NOT_COLLIDE_PLAYER
    
    move.l      #0, PLAYER_ALIVE
    move.l      #PLAY_SOUND_TRAP_TASK, D0
    lea         DeathSound, A1
    trap        #15
DO_NOT_COLLIDE_PLAYER:
    
    movem.l     (SP)+, ALL_REG
    RTS

******************************************************************************************************************************
******************************************************************************************************************************    
***  _____   _____ ______________  __________   ________   _____ __  ______  ____  ____  __  _____________   _____________ ***
*** /__  /  / ___// ____/ ____/  |/  / ____/ | / /_  __/  / ___// / / / __ )/ __ \/ __ \/ / / /_  __/  _/ | / / ____/ ___/ ***
***   / /   \__ \/ __/ / / __/ /|_/ / __/ /  |/ / / /     \__ \/ / / / __  / /_/ / / / / / / / / /  / //  |/ / __/  \__ \  ***
***  / /   ___/ / /___/ /_/ / /  / / /___/ /|  / / /     ___/ / /_/ / /_/ / _, _/ /_/ / /_/ / / / _/ // /|  / /___ ___/ /  ***
*** /_/   /____/_____/\____/_/  /_/_____/_/ |_/ /_/     /____/\____/_____/_/ |_|\____/\____/ /_/ /___/_/ |_/_____//____/   ***
***                                                                                                                        ***
******************************************************************************************************************************
******************************************************************************************************************************

DRAW_7SEG_A:
    movem.l     LINE_RENDERING_REGS, -(SP)   

    move.l      #SET_PEN_COLOR_COMMAND, D0
    move.l      #$FFFFFF, D1
    trap        #15

    move.l      #DRAW_LINE_TRAP_TASK, D0
    move.l      #SEGMENT_A_X1, D1
    move.l      #SEGMENT_A_Y1, D2
    move.l      #SEGMENT_A_X2, D3
    move.l      #SEGMENT_A_Y2, D4
    trap        #15

    movem.l     (SP)+, LINE_RENDERING_REGS   
    RTS
    
DRAW_7SEG_B:
    movem.l     LINE_RENDERING_REGS, -(SP)   

    move.l      #SET_PEN_COLOR_COMMAND, D0
    move.l      #$FFFFFF, D1
    trap        #15

    move.l      #DRAW_LINE_TRAP_TASK, D0
    move.l      #SEGMENT_B_X1, D1
    move.l      #SEGMENT_B_Y1, D2
    move.l      #SEGMENT_B_X2, D3
    move.l      #SEGMENT_B_Y2, D4
    trap        #15

    movem.l     (SP)+, LINE_RENDERING_REGS   
    RTS
    
DRAW_7SEG_C:
    movem.l     LINE_RENDERING_REGS, -(SP)   

    move.l      #SET_PEN_COLOR_COMMAND, D0
    move.l      #$FFFFFF, D1
    trap        #15

    move.l      #DRAW_LINE_TRAP_TASK, D0
    move.l      #SEGMENT_C_X1, D1
    move.l      #SEGMENT_C_Y1, D2
    move.l      #SEGMENT_C_X2, D3
    move.l      #SEGMENT_C_Y2, D4
    trap        #15

    movem.l     (SP)+, LINE_RENDERING_REGS   
    RTS
    
DRAW_7SEG_D:
    movem.l     LINE_RENDERING_REGS, -(SP)   

    move.l      #SET_PEN_COLOR_COMMAND, D0
    move.l      #$FFFFFF, D1
    trap        #15

    move.l      #DRAW_LINE_TRAP_TASK, D0
    move.l      #SEGMENT_D_X1, D1
    move.l      #SEGMENT_D_Y1, D2
    move.l      #SEGMENT_D_X2, D3
    move.l      #SEGMENT_D_Y2, D4
    trap        #15

    movem.l     (SP)+, LINE_RENDERING_REGS   
    RTS

DRAW_7SEG_E:
    movem.l     LINE_RENDERING_REGS, -(SP)   

    move.l      #SET_PEN_COLOR_COMMAND, D0
    move.l      #$FFFFFF, D1
    trap        #15

    move.l      #DRAW_LINE_TRAP_TASK, D0
    move.l      #SEGMENT_E_X1, D1
    move.l      #SEGMENT_E_Y1, D2
    move.l      #SEGMENT_E_X2, D3
    move.l      #SEGMENT_E_Y2, D4
    trap        #15

    movem.l     (SP)+, LINE_RENDERING_REGS   
    RTS
    
DRAW_7SEG_F:
    movem.l     LINE_RENDERING_REGS, -(SP)   

    move.l      #SET_PEN_COLOR_COMMAND, D0
    move.l      #$FFFFFF, D1
    trap        #15

    move.l      #DRAW_LINE_TRAP_TASK, D0
    move.l      #SEGMENT_F_X1, D1
    move.l      #SEGMENT_F_Y1, D2
    move.l      #SEGMENT_F_X2, D3
    move.l      #SEGMENT_F_Y2, D4
    trap        #15

    movem.l     (SP)+, LINE_RENDERING_REGS   
    RTS

DRAW_7SEG_G:
    movem.l     LINE_RENDERING_REGS, -(SP)   

    move.l      #SET_PEN_COLOR_COMMAND, D0
    move.l      #$FFFFFF, D1
    trap        #15

    move.l      #DRAW_LINE_TRAP_TASK, D0
    move.l      #SEGMENT_G_X1, D1
    move.l      #SEGMENT_G_Y1, D2
    move.l      #SEGMENT_G_X2, D3
    move.l      #SEGMENT_G_Y2, D4
    trap        #15

    movem.l     (SP)+, LINE_RENDERING_REGS   
    RTS

DRAW_7SEG_A_TENS:
    movem.l     LINE_RENDERING_REGS, -(SP)   

    move.l      #SET_PEN_COLOR_COMMAND, D0
    move.l      #$FFFFFF, D1
    trap        #15

    move.l      #DRAW_LINE_TRAP_TASK, D0
    move.l      #TENS_SEGMENT_A_X1, D1
    move.l      #TENS_SEGMENT_A_Y1, D2
    move.l      #TENS_SEGMENT_A_X2, D3
    move.l      #TENS_SEGMENT_A_Y2, D4
    trap        #15

    movem.l     (SP)+, LINE_RENDERING_REGS   
    RTS
    
DRAW_7SEG_B_TENS:
    movem.l     LINE_RENDERING_REGS, -(SP)   

    move.l      #SET_PEN_COLOR_COMMAND, D0
    move.l      #$FFFFFF, D1
    trap        #15

    move.l      #DRAW_LINE_TRAP_TASK, D0
    move.l      #TENS_SEGMENT_B_X1, D1
    move.l      #TENS_SEGMENT_B_Y1, D2
    move.l      #TENS_SEGMENT_B_X2, D3
    move.l      #TENS_SEGMENT_B_Y2, D4
    trap        #15

    movem.l     (SP)+, LINE_RENDERING_REGS   
    RTS
    
DRAW_7SEG_C_TENS:
    movem.l     LINE_RENDERING_REGS, -(SP)   

    move.l      #SET_PEN_COLOR_COMMAND, D0
    move.l      #$FFFFFF, D1
    trap        #15

    move.l      #DRAW_LINE_TRAP_TASK, D0
    move.l      #TENS_SEGMENT_C_X1, D1
    move.l      #TENS_SEGMENT_C_Y1, D2
    move.l      #TENS_SEGMENT_C_X2, D3
    move.l      #TENS_SEGMENT_C_Y2, D4
    trap        #15

    movem.l     (SP)+, LINE_RENDERING_REGS   
    RTS
    
DRAW_7SEG_D_TENS:
    movem.l     LINE_RENDERING_REGS, -(SP)   

    move.l      #SET_PEN_COLOR_COMMAND, D0
    move.l      #$FFFFFF, D1
    trap        #15

    move.l      #DRAW_LINE_TRAP_TASK, D0
    move.l      #TENS_SEGMENT_D_X1, D1
    move.l      #TENS_SEGMENT_D_Y1, D2
    move.l      #TENS_SEGMENT_D_X2, D3
    move.l      #TENS_SEGMENT_D_Y2, D4
    trap        #15

    movem.l     (SP)+, LINE_RENDERING_REGS   
    RTS

DRAW_7SEG_E_TENS:
    movem.l     LINE_RENDERING_REGS, -(SP)   

    move.l      #SET_PEN_COLOR_COMMAND, D0
    move.l      #$FFFFFF, D1
    trap        #15

    move.l      #DRAW_LINE_TRAP_TASK, D0
    move.l      #TENS_SEGMENT_E_X1, D1
    move.l      #TENS_SEGMENT_E_Y1, D2
    move.l      #TENS_SEGMENT_E_X2, D3
    move.l      #TENS_SEGMENT_E_Y2, D4
    trap        #15

    movem.l     (SP)+, LINE_RENDERING_REGS   
    RTS
    
DRAW_7SEG_F_TENS:
    movem.l     LINE_RENDERING_REGS, -(SP)   

    move.l      #SET_PEN_COLOR_COMMAND, D0
    move.l      #$FFFFFF, D1
    trap        #15

    move.l      #DRAW_LINE_TRAP_TASK, D0
    move.l      #TENS_SEGMENT_F_X1, D1
    move.l      #TENS_SEGMENT_F_Y1, D2
    move.l      #TENS_SEGMENT_F_X2, D3
    move.l      #TENS_SEGMENT_F_Y2, D4
    trap        #15

    movem.l     (SP)+, LINE_RENDERING_REGS   
    RTS

DRAW_7SEG_G_TENS:
    movem.l     LINE_RENDERING_REGS, -(SP)   

    move.l      #SET_PEN_COLOR_COMMAND, D0
    move.l      #$FFFFFF, D1
    trap        #15

    move.l      #DRAW_LINE_TRAP_TASK, D0
    move.l      #TENS_SEGMENT_G_X1, D1
    move.l      #TENS_SEGMENT_G_Y1, D2
    move.l      #TENS_SEGMENT_G_X2, D3
    move.l      #TENS_SEGMENT_G_Y2, D4
    trap        #15

    movem.l     (SP)+, LINE_RENDERING_REGS   
    RTS

    
***********************************************************
*** Renders a numerical value on the 7-segment display  ***
***********************************************************
*** Arguments *********************************************
*** Value to be rendered(long)                          ***
***********************************************************
*** Registers *********************************************
*** D1: Value to be rendered                            ***
*** D1: Stores the singles value to be rendered         ***
*** D2: Stores the 7seg table value                     ***
*** A0: 7 Segment Instruction Table                     ***
*** A1: Address of segment rendering function           ***
*** A2: Function pointer jump location                  ***
*** D1: Later holds binary table value data             ***
*** D2: After indexing, stores loop counter             ***
*** D3: Stores the right-most bit of D1 for comparison  ***
*** D3: After bit masking, stores the function location ***
*** D4: Stores the tens value to be rendered            ***
*** D7: Stores a flag to repeat once
***********************************************************
RENDER_7SEG_VALUE:
    movem.l     ALL_REG,-(SP)                    

    move.l      ALL_REG_BYTE_SIZE+ARG_1(SP), D1
    
    divu        #10, D1                         // Get 10's in lower and singles in upper
    clr.l       D4
    move.w      D1, D4                          // Move tens value to D4
    lsr.l       #8, D1
    lsr.l       #8, D1
    
    lea         LED_INSTRUCTION_TABLE, A0
    add.l       D1, A0
    move.b      (A0), D1
    
    lea         SEGMENT_FUNCTION_TABLE, A1      // Store table of function pointers
    
    move.l      #7, D2                          // Initialize counter
ITERATE_OVER_DISPLAY_VALUE:
    move.b      D1, D3                          // Move the rightmost byte to D3
    andi.b      #1, D3                          // Mask off rightmost bit in D3
    cmp.b       #1, D3
    beq         RENDER_NEXT_SEGMENT
    bra         BYPASS_RENDER_NEXT_SEGMENT
    
RENDER_NEXT_SEGMENT:
    move.l      (A1), D3
    move.l      D3, A2
    JSR         (A2)                            // Jump to function pointer for rendering proper segment
BYPASS_RENDER_NEXT_SEGMENT:
    adda.l      #4, A1                          // Offset function table to next segment
    lsr.l       #1, D1                          // Push least significant bit off table value

    subi.l      #1, D2
    bne         ITERATE_OVER_DISPLAY_VALUE
    
    *** Repeat rendering for tens values ***
    move.l      D4, D1                          // Move tens value to D1 for iterating
    
    
    lea         LED_INSTRUCTION_TABLE, A0
    add.l       D1, A0
    move.b      (A0), D1
    
    lea         TENS_SEGMENT_FUNCTION_TABLE, A1      // Store table of function pointers
    
    move.l      #7, D2                          // Initialize counter
ITERATE_OVER_TENS_DISPLAY_VALUE:
    move.b      D1, D3                          // Move the rightmost byte to D3
    andi.b      #1, D3                          // Mask off rightmost bit in D3
    cmp.b       #1, D3
    beq         RENDER_NEXT_TENS_SEGMENT
    bra         BYPASS_RENDER_NEXT_TENS_SEGMENT
    
RENDER_NEXT_TENS_SEGMENT:
    move.l      (A1), D3
    move.l      D3, A2
    JSR         (A2)                            // Jump to function pointer for rendering proper segment
BYPASS_RENDER_NEXT_TENS_SEGMENT:
    adda.l      #4, A1                          // Offset function table to next segment
    lsr.l       #1, D1                          // Push least significant bit off table value

    subi.l      #1, D2
    bne         ITERATE_OVER_TENS_DISPLAY_VALUE

    *** Display Score Text ***
    move.l      #DISPLAY_TEXT_TRAP_TASK, D0
    move.l      #SCORE_TEXT_X_POS, D1
    move.l      #SCORE_TEXT_Y_POS, D2
    lea         SCORE_TEXT, A1
    trap        #15

    movem.l     (SP)+, ALL_REG                   
    RTS
    
**********************************************
*** Wipes the 7seg for next rendering pass ***
**********************************************
CLEAR_7_SEG_DISPLAY:
    movem.l     ALL_REG, -(SP)                    

    move.l      BackgroundImageHeight, D3
    sub.l       #(DISPLAY_Y_POS-1), D3                  
    sub.l       #(SEGMENT_LENGTH+SEGMENT_LENGTH+2), D3 // Offset y value to account for bmp image inversion
    
    *** Clear Tens Display ***
    move.l      #(DISPLAY_X_POS-1), -(SP)
    move.l      D3, -(SP)
    move.l      #(SEGMENT_LENGTH+2), -(SP)    
    move.l      #(SEGMENT_LENGTH+SEGMENT_LENGTH+2), -(SP)
    move.l      #(DISPLAY_X_POS-1), -(SP)
    move.l      #(DISPLAY_Y_POS-1), -(SP)
    JSR         RENDER_BACKGROUND_CHUNK
    move.l      #SIX_ARGS, D0
    add.l       D0, SP
    
    *** Clear Singles Display ***
    move.l      #(DISPLAY_X_POS-1+ONES_SEGMENT_OFFSET), -(SP)
    move.l      D3, -(SP)
    move.l      #(SEGMENT_LENGTH+2), -(SP)    
    move.l      #(SEGMENT_LENGTH+SEGMENT_LENGTH+2), -(SP)
    move.l      #(DISPLAY_X_POS-1+ONES_SEGMENT_OFFSET), -(SP)
    move.l      #(DISPLAY_Y_POS-1), -(SP)
    JSR         RENDER_BACKGROUND_CHUNK
    move.l      #SIX_ARGS, D0
    add.l       D0, SP
    
    movem.l     (SP)+, ALL_REG                   
    RTS
    
seedRandomNumber:
        movem.l ALL_REG,-(sp)
        clr.l   d6
        move.b  #GET_TIME_COMMAND,d0
        TRAP    #15

        move.l  d1,RANDOMVAL
        movem.l (sp)+,ALL_REG
        rts

getRandomByteIntoD6:
        movem.l d0,-(sp)
        movem.l d1,-(sp)
        movem.l d2,-(sp)
        move.l  RANDOMVAL,d0
       	moveq	#$AF-$100,d1
       	moveq	#18,d2
Ninc0	
	add.l	d0,d0
	bcc	Ninc1
	eor.b	d1,d0
Ninc1
	dbf	d2,Ninc0
	
	move.l	d0,RANDOMVAL
	clr.l	d6
	move.b	d0,d6
	
        movem.l (sp)+,d2
        movem.l (sp)+,d1
        movem.l (sp)+,d0
        RTS

getRandomLongIntoD6:
        movem.l ALL_REG,-(sp)
        JSR     getRandomByteIntoD6
        move.b  d6,d5
        JSR     getRandomByteIntoD6
        lsl.l   #8,d5
        move.b  d6,d5
        JSR     getRandomByteIntoD6
        lsl.l   #8,d5
        move.b  d6,d5
        JSR     getRandomByteIntoD6
        lsl.l   #8,d5
        move.b  d6,d5
        move.l  d5,TEMPRANDOMLONG
        movem.l (sp)+,ALL_REG
        move.l  TEMPRANDOMLONG,d6
        RTS
        
************************************************************
*** Hangs game on initial run until player presses enter ***
************************************************************
LISTEN_FOR_GAME_START:
    movem.l     ALL_REG, -(SP)
    
    MOVE.B      #LISTEN_FOR_INPUTS, D0
    move.l      #ENTER_KEY, D1
    trap        #15
    
    cmp.b       #$FF, D1
    beq         SET_GAME_STARTED
    bra         BYPASS_SET_GAME_STARTED
SET_GAME_STARTED:
    move.l      #0, FIRST_RUN
BYPASS_SET_GAME_STARTED:
    
    movem.l     (SP)+, ALL_REG
    RTS
    
**************************************************
*** Displays controls and credits for the game ***
**************************************************
DISPLAY_START_TEXT:
    movem.l     ALL_REG, -(SP)
    
    move.l      #SET_FONT_TRAP_TASK, D0
    move.l      #$FFFF00, D1
    move.l      #TITLE_FONT, D2
    trap        #15
    
    move.l      #DISPLAY_TEXT_TRAP_TASK, D0
    lea         GameName,        A1
    move.l      #GAME_NAME_X_POS, D1
    move.l      #GAME_NAME_Y_POS, D2
    trap        #15
    
    move.l      #SET_FONT_TRAP_TASK, D0
    move.l      #$FFFFFF, D1
    move.l      #STANDARD_FONT, D2
    trap        #15
    
    move.l      #DISPLAY_TEXT_TRAP_TASK, D0
    lea         PressEnterToBeginText, A1
    move.l      #PRESS_ENTER_X_POS, D1
    move.l      #PRESS_ENTER_Y_POS, D2
    trap        #15
    
    lea         DeveloperCredits, A1
    move.l      #DEV_NAME_X_POS, D1
    move.l      #DEV_NAME_Y_POS, D2
    trap        #15
    
    lea         MusicCredits, A1
    move.l      #MUSIC_CRED_X_POS, D1
    move.l      #MUSIC_CRED_Y_POS, D2
    trap        #15
    
    move.l      #REPAINT_SCREEN, D0
    trap        #15
    
    movem.l     (SP)+, ALL_REG
    RTS
        
*************************
*** Random Value Data ***
*************************
RANDOMVAL       ds.l    1
TEMPRANDOMLONG  ds.l    1

*****************************
*** Background image data ***
*****************************
BackgroundImage             INCBIN  "Background.bmp"
BackgroundImageHeight       ds.l    1
BackgroundImagewidth        ds.l    1
BackgroundImageData         ds.l    1
BackgroundRowPadding        ds.l    1
BackgroundChunkWidth        ds.l    1
BackgroundChunkHeight       ds.l    1
BackgroundImageDataOffset   EQU     (BackgroundImage+10)
BackgroundWidthLocation     EQU     (BackgroundImageDataOffset+8)
BackgroundHeightLocation    EQU     (BackgroundWidthLocation+4)
BG_WIDTH                    EQU     640
BG_HEIGHT                   EQU     480

*************************
*** Player image data ***
*************************
PlayerImage                 INCBIN  "Player.bmp"
PlayerImageHeight           ds.l    1
PlayerImageWidth            ds.l    1
PlayerImageData             ds.l    1
PlayerRowPadding            ds.l    1
PlayerChunkWidth            ds.l    1
PlayerChunkHeight           ds.l    1
PlayerImageDataOffset       EQU     (PlayerImage+10)
PlayerWidthLocation         EQU     (PlayerImageDataOffset+8)
PlayerHeightLocation        EQU     (PlayerWidthLocation+4)
PLAYER_WIDTH                EQU     32
PLAYER_HEIGHT               EQU     32
PLAYER_Y_POSITION           EQU     (BG_HEIGHT-PLAYER_HEIGHT-60)
PLAYER_X_POSITION           ds.l    1

************************
*** Enemy image data ***
************************
EnemyImage                  INCBIN  "Enemy.bmp"
EnemyImageHeight            ds.l    1
EnemyImageWidth             ds.l    1
EnemyImageData              ds.l    1
EnemyRowPadding             ds.l    1
EnemyChunkWidth             ds.l    1
EnemyChunkHeight            ds.l    1
EnemyImageDataOffset        EQU     (EnemyImage+10)
EnemyWidthLocation          EQU     (EnemyImageDataOffset+8)
EnemyHeightLocation         EQU     (EnemyWidthLocation+4)
ENEMY_WIDTH                 EQU     32
ENEMY_HEIGHT                EQU     32
ENEMY_X_POS                 ds.l    1
ENEMY_Y_POS                 ds.l    1
ENEMY_SPEED                 ds.l    1
ENEMY_SPEED_INCREMENT       EQU     125

***********************
*** Projectile data ***
***********************
PROJECTILE_SPEED            EQU     9
PROJECTILE_LENGTH           EQU     20
PROJECTILE_X_POS            ds.l    1
PROJECTILE_Y_POS            ds.l    1
PROJECTILE_FIRED            ds.l    1
PROJECTILE_POS_OFFSET       EQU     14

*************************
*** Player input data ***
*************************
W_PRESSED                   ds.l    1
A_PRESSED                   ds.l    1
S_PRESSED                   ds.l    1
D_PRESSED                   ds.l    1
SPACE_PRESSED               ds.l    1
MOVING_LEFT                 EQU     -1600
MOVING_RIGHT                EQU     1600
MOVING_DOWN                 EQU     1
MOVING_UP                   EQU     -1
PLAYER_X_VEL                ds.l    1
PLAYER_Y_VEL                ds.l    1
HAVE_HAD_NO_INPUT           ds.l    1
PLAYER_ALIVE                ds.l    1
PLAYER_POINTS               ds.l    1

****************************
*** LED Instruction Data ***
****************************
DRAW_LINE_TRAP_TASK         equ     84
LED_INSTRUCTION_TABLE       dc.b    $3F, $06, $5B, $4F, $66, $6D, $7D, $07, $7F, $6F 
SEGMENT_FUNCTION_TABLE      dc.l    DRAW_7SEG_A, DRAW_7SEG_B, DRAW_7SEG_C, DRAW_7SEG_D, DRAW_7SEG_E, DRAW_7SEG_F, DRAW_7SEG_G
TENS_SEGMENT_FUNCTION_TABLE dc.l    DRAW_7SEG_A_TENS, DRAW_7SEG_B_TENS, DRAW_7SEG_C_TENS, DRAW_7SEG_D_TENS, DRAW_7SEG_E_TENS, DRAW_7SEG_F_TENS, DRAW_7SEG_G_TENS
SEGMENT_LENGTH              equ     16
ONES_SEGMENT_OFFSET         EQU     24
SCORE_TEXT                  dc.b    'SCORE:', 0

DISPLAY_X_POS               equ     575
DISPLAY_Y_POS               equ     480-SEGMENT_LENGTH-SEGMENT_LENGTH-10
SCORE_TEXT_X_POS            EQU     DISPLAY_X_POS
SCORE_TEXT_Y_POS            EQU     DISPLAY_Y_POS-15

SEGMENT_A_X1                equ     DISPLAY_X_POS+ONES_SEGMENT_OFFSET
SEGMENT_A_X2                equ     DISPLAY_X_POS+SEGMENT_LENGTH+ONES_SEGMENT_OFFSET
SEGMENT_A_Y1                equ     DISPLAY_Y_POS
SEGMENT_A_Y2                equ     DISPLAY_Y_POS   

SEGMENT_B_X1                equ     DISPLAY_X_POS+SEGMENT_LENGTH+ONES_SEGMENT_OFFSET
SEGMENT_B_X2                equ     DISPLAY_X_POS+SEGMENT_LENGTH+ONES_SEGMENT_OFFSET
SEGMENT_B_Y1                equ     DISPLAY_Y_POS
SEGMENT_B_Y2                equ     DISPLAY_Y_POS+SEGMENT_LENGTH

SEGMENT_C_X1                equ     DISPLAY_X_POS+SEGMENT_LENGTH+ONES_SEGMENT_OFFSET
SEGMENT_C_X2                equ     DISPLAY_X_POS+SEGMENT_LENGTH+ONES_SEGMENT_OFFSET
SEGMENT_C_Y1                equ     DISPLAY_Y_POS+SEGMENT_LENGTH
SEGMENT_C_Y2                equ     DISPLAY_Y_POS+SEGMENT_LENGTH+SEGMENT_LENGTH

SEGMENT_D_X1                equ     DISPLAY_X_POS+ONES_SEGMENT_OFFSET
SEGMENT_D_X2                equ     DISPLAY_X_POS+SEGMENT_LENGTH+ONES_SEGMENT_OFFSET
SEGMENT_D_Y1                equ     DISPLAY_Y_POS+SEGMENT_LENGTH+SEGMENT_LENGTH
SEGMENT_D_Y2                equ     DISPLAY_Y_POS+SEGMENT_LENGTH+SEGMENT_LENGTH

SEGMENT_E_X1                equ     DISPLAY_X_POS+ONES_SEGMENT_OFFSET
SEGMENT_E_X2                equ     DISPLAY_X_POS+ONES_SEGMENT_OFFSET
SEGMENT_E_Y1                equ     DISPLAY_Y_POS+SEGMENT_LENGTH
SEGMENT_E_Y2                equ     DISPLAY_Y_POS+SEGMENT_LENGTH+SEGMENT_LENGTH

SEGMENT_F_X1                equ     DISPLAY_X_POS+ONES_SEGMENT_OFFSET
SEGMENT_F_X2                equ     DISPLAY_X_POS+ONES_SEGMENT_OFFSET
SEGMENT_F_Y1                equ     DISPLAY_Y_POS
SEGMENT_F_Y2                equ     DISPLAY_Y_POS+SEGMENT_LENGTH

SEGMENT_G_X1                equ     DISPLAY_X_POS+ONES_SEGMENT_OFFSET
SEGMENT_G_X2                equ     DISPLAY_X_POS+SEGMENT_LENGTH+ONES_SEGMENT_OFFSET
SEGMENT_G_Y1                equ     DISPLAY_Y_POS+SEGMENT_LENGTH
SEGMENT_G_Y2                equ     DISPLAY_Y_POS+SEGMENT_LENGTH

TENS_SEGMENT_A_X1           equ     DISPLAY_X_POS
TENS_SEGMENT_A_X2           equ     DISPLAY_X_POS+SEGMENT_LENGTH
TENS_SEGMENT_A_Y1           equ     DISPLAY_Y_POS
TENS_SEGMENT_A_Y2           equ     DISPLAY_Y_POS   

TENS_SEGMENT_B_X1           equ     DISPLAY_X_POS+SEGMENT_LENGTH
TENS_SEGMENT_B_X2           equ     DISPLAY_X_POS+SEGMENT_LENGTH
TENS_SEGMENT_B_Y1           equ     DISPLAY_Y_POS
TENS_SEGMENT_B_Y2           equ     DISPLAY_Y_POS+SEGMENT_LENGTH

TENS_SEGMENT_C_X1           equ     DISPLAY_X_POS+SEGMENT_LENGTH
TENS_SEGMENT_C_X2           equ     DISPLAY_X_POS+SEGMENT_LENGTH
TENS_SEGMENT_C_Y1           equ     DISPLAY_Y_POS+SEGMENT_LENGTH
TENS_SEGMENT_C_Y2           equ     DISPLAY_Y_POS+SEGMENT_LENGTH+SEGMENT_LENGTH

TENS_SEGMENT_D_X1           equ     DISPLAY_X_POS
TENS_SEGMENT_D_X2           equ     DISPLAY_X_POS+SEGMENT_LENGTH
TENS_SEGMENT_D_Y1           equ     DISPLAY_Y_POS+SEGMENT_LENGTH+SEGMENT_LENGTH
TENS_SEGMENT_D_Y2           equ     DISPLAY_Y_POS+SEGMENT_LENGTH+SEGMENT_LENGTH

TENS_SEGMENT_E_X1           equ     DISPLAY_X_POS
TENS_SEGMENT_E_X2           equ     DISPLAY_X_POS
TENS_SEGMENT_E_Y1           equ     DISPLAY_Y_POS+SEGMENT_LENGTH
TENS_SEGMENT_E_Y2           equ     DISPLAY_Y_POS+SEGMENT_LENGTH+SEGMENT_LENGTH

TENS_SEGMENT_F_X1           equ     DISPLAY_X_POS
TENS_SEGMENT_F_X2           equ     DISPLAY_X_POS
TENS_SEGMENT_F_Y1           equ     DISPLAY_Y_POS
TENS_SEGMENT_F_Y2           equ     DISPLAY_Y_POS+SEGMENT_LENGTH

TENS_SEGMENT_G_X1           equ     DISPLAY_X_POS
TENS_SEGMENT_G_X2           equ     DISPLAY_X_POS+SEGMENT_LENGTH
TENS_SEGMENT_G_Y1           equ     DISPLAY_Y_POS+SEGMENT_LENGTH
TENS_SEGMENT_G_Y2           equ     DISPLAY_Y_POS+SEGMENT_LENGTH

******************
*** Sound Data ***
******************
PLAY_SOUND_TRAP_TASK        EQU     73
LOAD_DIRECT_X_TASK          EQU     74
CONTROL_DIRECT_X_TASK       EQU     77
DIRECT_X_LOOP_CMD           EQU     1
DIRECT_X_STOP_CMD           EQU     3
BulletFiredSound            dc.b    'BulletFired.wav', 0
ExplosionSound              dc.b    'Explosion.wav', 0
DeathSound                  dc.b    'Death.wav', 0
BackgroundMusic             dc.b    'BackgroundMusic.wav', 0
BackgroundMusicPlaying      dc.l    1

***************************
*** Loading screen data ***
***************************
DISPLAY_TEXT_TRAP_TASK      EQU     95
LOADING_TEXT_X_POS          EQU     280
LOADING_TEXT_Y_POS          EQU     240
LOADING_TEXT                dc.b    'Loading...', 0

*****************************
*** Game over screen data ***
*****************************
GAME_OVER_TEXT_X_POS        EQU     185
GAME_OVER_TEXT_Y_POS        EQU     240
GAME_OVER_TEXT              dc.b    'Game Over. Press ENTER to continue', 0
CLEAR_SCREEN_VALUE          EQU     $FF00
CLEAR_SCREEN_TASK           EQU     11
ENTER_KEY                   EQU     $D
FIRST_RUN                   ds.l    1
FIRST_REPAINT               ds.l    1
FightSound                  dc.b    'Fight.wav', 0

*************************
*** Start screen data ***
*************************
TITLE_FONT                  EQU     $60120000
STANDARD_FONT               EQU     $600C0000
SET_FONT_TRAP_TASK          EQU     21
GAME_NAME_X_POS             EQU     240
GAME_NAME_Y_POS             EQU     200
DEV_NAME_X_POS              EQU     240
DEV_NAME_Y_POS              EQU     400
MUSIC_CRED_X_POS            EQU     150
MUSIC_CRED_Y_POS            EQU     DEV_NAME_Y_POS+30
PRESS_ENTER_X_POS           EQU     245
PRESS_ENTER_Y_POS           EQU     250
GameName                    dc.b    'GALAGA(ISH)', 0
DeveloperCredits            dc.b    'Created by: Dale Diaz', 0
MusicCredits                dc.b    'Royalty free music provided by: joshuaempyre', 0
PressEnterToBeginText       dc.b    'Press ENTER to begin', 0
     
    END    START


























*~Font name~Courier New~
*~Font size~16~
*~Tab type~1~
*~Tab size~4~
