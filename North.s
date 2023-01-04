; North Jaguar
;
; - implementer la prot
; OK - recaler l'ecran en 50 HZ
; OK - tracer ligne en 256 couleur
; OK - pouvoir ralentir la transformation, + de 128 étapes
; OK - mise en place de la structure
; OK - tracer une ligne au blitter au GPU
; OK - rotation des points au GPU, calculs complets, seule astuce : *1/x à la place de div
; OK - effacement au blitter
; OK  - musique FC au 68000+DSP
; OK - scrolling en bas : qui rebondit en fonction de la musique / couleur en fonction de la ligne / couleur en fonction d'une table
; OK - logo en haut
; OK - effacer au blitter avant les calculs 3D
; OK - couleur 3D : B8B0C0 ( 77C0) ou F8B028 (E9F8)

; OK - bloc fixe motif en fond
; OK - scrolling en 2 plan réels, inversé,  transparent.  p1p1p2p2 etc / shlq


; - BUG : music plante au bout d'un moment
;	- OK : tester sans music
;	- tester sans interruptions dsp/68000
;	- tester avec I2S sans 


temps_GPU=0
;tracer_de_lignes_au_blitter_ON=1
copie_du_scrolling_au_GPU=0
avancer_le_scrolling=1
DEBUG_BIGPEMU=0

SCROLLING_ON=1
CALCS_3D_ON=1
LIGNES3D_ON=1
MUSIC_ON=1




nb_etapes_transformation = 256

couleur_de_fond = $742F
couleur_de_fond_BORD1 = 0			; $1828
couleur_de_fond_BORD2 = 0			; $2F
numero_couleur_ligne_3D_256c=200

couleur_rouge = -1				; $D0C1D0C1
couleur_CLUT_1 = $742F			; $d0c1			; $E9F8
couleur_CLUT_200 = $E9F8			; $E9F8
valeur_zoom = ($7cff06)					;  $7cff06


NBPTS		.EQU	$90		;9*16=144 POINTS
XMILIEU		.EQU	160
YMILIEU		.EQU	100
NBLIGNES	.EQU	165		;NB LIGNES A AFFICHER AU TOTAL
NBCOLS		.EQU	192		;NB PIXELS DE LARGEUR


rotation_en_X=2					; 2
rotation_en_Y=1					; 1
rotation_en_Z=1					; 3

inc_pos_initiale_X=0
inc_pos_initiale_Y=0
inc_pos_initiale_Z=0


; scroll
hauteur_scrolling=8
couleur_du_scrolling=13



;-------------------------
;CC (Carry Clear) = %00100
;CS (Carry Set)   = %01000
;EQ (Equal)       = %00010
;MI (Minus)       = %11000
;NE (Not Equal)   = %00001
;PL (Plus)        = %10100
;HI (Higher)      = %00101
;T (True)         = %00000
;-------------------------


	include	"jaguar.inc"
GPU_STACK_SIZE	equ		4	; long words
GPU_USP			equ		(G_ENDRAM-(4*GPU_STACK_SIZE))
GPU_ISP			equ		(GPU_USP-(4*GPU_STACK_SIZE))	
CLEAR_BSS			.equ			1									; 1=efface toute la BSS jusqu'a la fin de la ram utilisée


ob_list_1				equ		(ENDRAM-52000)				; address of read list =  
ob_list_2				equ		(ENDRAM-104000)				; address of read list =  
nb_octets_par_ligne			equ		320
nb_lignes					equ		240


logo_DUNE_POSX=320-64
logo_DUNE_POSY=26-16
zone3D_POSX = (16+16)		; 16+46
zone3D_POSY = 58+10-16			; (58+(91*2))
hauteur_zone_3D = 240-(58/2)
zone_scrolling_POSX = 0
zone_scrolling_POSY = (2*(240-24))+26-10-16

.opt "~Oall"

.text

			.68000



	move.l		#$70007,G_END
	move.l		#$70007,D_END
	move.l		#INITSTACK-128, sp	

	
	move.w		#%0000011011000001, VMODE			; 320x256 / CRY / $6C7
	
	move.w		#$100,JOYSTICK


	move.w		#801,VI			; stop VI

; clear BSS
	lea			DEBUT_BSS,a0
	lea			FIN_RAM,a1
	moveq		#0,d0
	
boucle_clean_BSS:
	move.b		d0,(a0)+
	cmp.l		a0,a1
	bne.s		boucle_clean_BSS
; clear stack
	lea			INITSTACK-100,a0
	lea			INITSTACK,a1
	moveq		#0,d0
	
boucle_clean_BSS2:
	move.b		d0,(a0)+
	cmp.l		a0,a1
	bne.s		boucle_clean_BSS2

; wait for gpu to stop
	lea			G_CTRL,A0
wait_STOP_GPU:
	move.l		(a0),d0
	btst		#0,d0
	bne.s		wait_STOP_GPU



	.if			MUSIC_ON=1

; init replay FC
		lea		Paula_custom-$A0,a1
		lea		module_FC,a0
		bsr		fcInit
		jsr		PAULA_init

	;move.l  #interrupt_DSP,LEVEL0     	; Install 68K LEVEL0 handler

	;move.w  #%10,J_INT                			; configurer JINT ($F10020) en activant le bit1
	;move.w	#%10001,INT1

	;and.w   #%1111100011111111,sr				; 1111100011111111 => bits 8/9/10 = 0
	.endif


; transforme sincos en .L
	lea		SINCOS,a0
	move.w	#(8*64)-1,d7							; 256 valeurs
boucle_transforme_sincos_en_L:
	move.w	2(a0),d0
	ext.l	d0
	move.l	d0,(a0)+
	dbf		d7,boucle_transforme_sincos_en_L


; traduit le scrolling

	.if		1=0
	lea		texte_du_scrolling,a0
	lea		table_traduction_texte_scrolling,a1
	lea		texte_scrolling_traduit,a4
	move.l	#fonte,D4
boucle_traduction_scrolling:
	move.l	a1,a2
	move.b	(a0)+,d0
	cmp.b	#-1,d0
	beq.s	boucle_traduction_scrolling__sortie
	moveq	#0,d1
boucle_traduction_scrolling2:
	cmp.b	(a2)+,d0
	beq.s	boucle_traduction_scrolling__trouve
	addq.w	#1,d1
	bra.s	boucle_traduction_scrolling2
boucle_traduction_scrolling__trouve:
; d1 = numero dans la fonte
	divs	#20,d1
	move.w	d1,d2
	ext.l	d2
	mulu	#(24*320),d2
	add.l	d4,d2				; + fonte
	swap	d1
	ext.l	d1
	lsl.l	#4,d1				; remainder * 16
	add.l	d1,d2
	move.l	d2,(a4)+
	bra.s	boucle_traduction_scrolling
boucle_traduction_scrolling__sortie:
	.endif
	
; version rapide
	lea		table_traduction_texte_scrolling_direct,a1
	lea		texte_du_scrolling,a0
	lea		texte_scrolling_traduit,a4
boucle_traduction_scrolling:
	move.b	(a0)+,d0
	cmp.b	#-1,d0
	beq.s	boucle_traduction_scrolling__sortie
	ext.w	d0
	sub.w	#32,d0
	lsl.w	#2,d0			; *4
	move.l	(a1,d0.w),(a4)+
	bra.s	boucle_traduction_scrolling
boucle_traduction_scrolling__sortie:
	move.l	#-1,(a4)			; tag de fin



; copie du code GPU
	move.l	#0,G_CTRL
; copie du code GPU dans la RAM GPU

	lea		GPU_debut,A0
	lea		G_RAM,A1
	move.l	#GPU_fin-GPU_base_memoire,d0
	lsr.l	#2,d0
	sub.l	#1,D0
boucle_copie_bloc_GPU:
	move.l	(A0)+,(A1)+
	dbf		D0,boucle_copie_bloc_GPU
	
	bsr		RAPTOR_InitVideo

; creer les object listes
	lea		ob_list_1,a6
	bsr		preparation_OL
	lea		ob_list_2,a6
	bsr		preparation_OL

; remplace la couleur 02 de la fonte par 0
	lea		fonte,a0
	lea		FIN_fonte,a1
boucle_modif_fonte:
	;move.w	#200,d1
	move.b	(a0),d0
	cmp.b	#01,d0
	beq.s	boucle_modif_fonte__pas_01
	moveq	#0,d0
boucle_modif_fonte__pas_01:
	move.b	d0,(a0)+
	cmp.l	a0,a1
	bne.s	boucle_modif_fonte

; init a vide la zone de scrolling
	lea		zone_scrolling_dessus_256c_640pixels__zone1,a0
	lea		zone_scrolling_dessus_256c_640pixels__zone2,a1
	move.w	#(24*640)-1,d7
	move.w	#01,d0				; 01=vide / 0=sans fond edz
vide_zone_texte_scrolling_avec_couleur_200:
	move.b	d0,(a0)+
	move.b	d0,(a1)+
	dbf		d7,vide_zone_texte_scrolling_avec_couleur_200

; copie un objet dans points_en_cours__en_word, pour test
	.if		1=0
	lea		OBJ1,A0
	lea		points_en_cours__en_word,A1
	move.w	#(NBPTS*3)-1,d7
test_remplir_objet:	
	move.b	(a0)+,d0			; X
	ext.w	d0
	add.w	d0,d0
	asl.w	#6,d0
	move.w	d0,(a1)+
	dbf		d7,test_remplir_objet
	.endif

; launch GPU
	move.l	#REGPAGE,G_FLAGS
	move.l	#GPU_init,G_PC
	move.l  #RISCGO,G_CTRL	; START GPU


	.if		1=0
; test zone 1 plan scrolling
	lea		zone_resultat_scrolling_256c,a0
	move.l	#$FF,d0
	move.w	#(24-1),d7
test1P:	
	move.b	d0,64(a0)
	move.b	d0,319(a0)
	lea		320(a0),a0
	;move.b	d0,64(a0)
	;move.b	d0,319(a0)
	;move.b	d0,200(a0)
	;lea		320(a0),a0
	dbf		d7,test1P
	.endif

; remplissage de test zone dessus	
	.if		1=0
	lea		zone_scrolling_dessus_256c_640pixels,a0
	move.w	#(24-1),d7
	move.l	#$FF,d0
test1P2:	
	move.b	d0,64(a0)
	move.b	d0,64+16(a0)
	move.b	d0,64+32(a0)
	move.b	d0,64+48(a0)
	move.b	d0,310(a0)
	lea		320(a0),a0
	move.b	d0,64(a0)
	move.b	d0,64+16(a0)
	move.b	d0,64+32(a0)
	move.b	d0,64+48(a0)
	move.b	d0,310(a0)
	lea		320(a0),a0
	dbf		d7,test1P2
	.endif


	
	
;--------------

; cLUT	
	lea		CLUT,a2
	move.w	#couleur_de_fond,(a2)+
	move.w	#couleur_CLUT_1,(a2)+				; $d0c1 = rouge bof
	
	lea		table_couleur,a0
	move.w	#62-1,d7
SET_CLUT:
	move.w	(a0)+,(a2)+
	dbf		d7,SET_CLUT

; couleur 200
	lea		CLUT+(200*2),a2
	move.w	#couleur_CLUT_200,(a2)+				; $d0c1 = rouge bof
	

; blitter au 68000
				.if		1=0
				move.l	#zone_scrolling_dessus_256c_640pixels,A1_BASE			; A1 = Source
				move.l	#$0,A1_PIXEL
				move.l	#PIXEL8|XADDINC|PITCH1|WID320,A1_FLAGS
				move.l	#$00010000,A1_STEP
				move.l	#$00000000,A1_FSTEP
				move.l	#$00000001,A1_INC
				move.l	#$00000000,A1_FINC
				move.l	#$00000008,A1_PIXEL
				
				
				move.l	#zone_resultat_scrolling_256c,A2_BASE			; A2 = DEST
				move.l	#$0,A2_PIXEL
				move.l	#PIXEL8|XADDPIX|PITCH1|WID320,A2_FLAGS
				
				
				move.w	#24,d0
				swap	d0
				move.l	#320,d1
				move.w	d1,d0
				move.l	d0,B_COUNT
				move.l	#LFU_REPLACE|SRCEN|DSTA2|UPDA1,B_CMD
				.endif


main:
				cmp.l		#0,Paula_flag_Tick_50Hz
				bne.s		main

				move.l		#1,Paula_flag_Tick_50Hz
				bsr			fcTick
				move.l		#2,Paula_flag_Tick_50Hz
.waitint1:
				nop
				move.l	D_CTRL,d0
				btst	#6,d0
				bne.s	.waitint1
				or.l	#DSPINT0,D_CTRL								; interrupt pour prise en compte des valeurs FC par le DSP

				bra.s		main

interrupt_DSP:
				;move.w		#$7451,BORD1
                movem.l d0-d7/a0-a6,-(a7)
				
; interruption 50 hz
				move.l		#1,Paula_flag_Tick_50Hz
				bsr			fcTick
				move.l		#2,Paula_flag_Tick_50Hz
.waitint1:
				nop
				move.l	D_CTRL,d0
				btst	#6,d0
				bne.s	.waitint1
				or.l	#DSPINT0,D_CTRL								; interrupt pour prise en compte des valeurs FC par le DSP

				move.w	#%1000000010001,INT1
				move.w  #%1000000010,J_INT                			; configurer JINT ($F10020) en activant le bit1

                move.w  #$0,INT2
                movem.l (a7)+,d0-d7/a0-a6
				;move.w		#$0,BORD1
                rte






;-----------------------------------------------------------------------------------
; preparation de l'Objects list
;   Condition codes (CC):
;
;       Values     Comparison/Branch
;     --------------------------------------------------
;        000       Branch on equal            (VCnt==VC)
;        001       Branch on less than        (VCnt>VC)
;        010       Branch on greater than     (VCnt<VC)
;        011       Branch if OP flag is set
; input A6=adresse object list 
preparation_OL:
	move.l	a6,a1
	;lea		ob_list_1,a1

;
; ============== insertion de Branch if YPOS < 0 a X+16

	move.l		#$00000003,d0					; branch
	or.l		#%0100000000000000,d0			; <
	move.l		GPU_premiere_ligne,d3
	;add.l		d3,d3							; *2 : half line
	lsl.l		#3,d3
	or.l		d3,d0							; Ymax	

	move.l		a1,d1
	add.l		#16,d1
	lsr.l		#3,d1							
	move.l		d1,d2
	lsl.l		#8,d1							; <<24 : 8 bits
	lsl.l		#8,d1
	lsl.l		#8,d1
	or.l		d1,d0
	lsr.l		#8,d2
	move.l		d2,(a1)+
	move.l		d0,(a1)+

; ============== insertion de Branch if YPOS < Ymax à X+16

	move.l		#$00000003,d0					; branch
	or.l		#%0100000000000000,d0			; <
	;move.l		#derniere_ligne,d3
	;add.l		d3,d3							; *2 : half line
	;moveq		#0,d3
	move.l		GPU_derniere_ligne,d3
	;add.l		d3,d3							; *2 : half line
	lsl.l		#3,d3
	or.l		d3,d0							; Ymax	
	move.l		a1,d1
	add.l		#16,d1
	lsr.l		#3,d1							
	move.l		d1,d2
	lsl.l		#8,d1							; <<24 : 8 bits
	lsl.l		#8,d1
	lsl.l		#8,d1
	or.l		d1,d0
	lsr.l		#8,d2
	move.l		d2,(a1)+
	move.l		d0,(a1)+

; ============== insertion de STOP
	moveq		#0,d0
	move.l		d0,(a1)+
	move.l		#4,d0
	move.l		d0,(a1)+
	
	lea			48(a6),a2

; insertion d'un bra < GPU_derniere_ligne
	move.l		#$00000003,d0					; branch
	or.l		#%0100000000000000,d0			; <
	move.l		GPU_derniere_ligne,d4
	subq.l		#2,d4
	;add.l		d4,d4							; (*2 : half line)
	lsl.l		#3,d4
	or.l		d4,d0							; VC
	move.l		a2,d1
	lsr.l		#3,d1							
	move.l		d1,d2
	lsl.l		#8,d1							; <<24 : 8 bits
	lsl.l		#8,d1
	lsl.l		#8,d1
	or.l		d1,d0
	lsr.l		#8,d2
	move.l		d2,(a1)+
	move.l		d0,(a1)+

; insertion GPU object
	moveq		#0,d0
	move.l		d0,(a1)+
	move.l		#$3FFA,d0				; $3FFA
	move.l		d0,(a1)+
	
; insertion de STOP
	moveq		#0,d0
	move.l		d0,(a1)+
	move.l		#4,d0
	move.l		d0,(a1)+

; insertion de STOP
	moveq		#0,d0
	move.l		d0,(a1)+
	move.l		#4,d0
	move.l		d0,(a1)+
; insertion de STOP
	moveq		#0,d0
	move.l		d0,(a1)+
	move.l		#4,d0
	move.l		d0,(a1)+

; insertion de STOP
	moveq		#0,d0
	move.l		d0,(a1)+
	move.l		#4,d0
	move.l		d0,(a1)+


; insertion de STOP
	moveq		#0,d0
	move.l		d0,(a2)+
	move.l		#4,d0
	move.l		d0,(a2)+

	rts




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Procedure: InitVideo 
;;
RAPTOR_InitVideo:
            movem.l d0-d6,-(sp)
            move.w  CONFIG,d0                            ; Also is joystick register
            andi.w  #VIDTYPE,d0                          ; 0 = PAL, 1 = NTSC
            beq.s    .palvals
            
.ntscvals:    move.w  #RAPTOR_NTSC_HMID,d2
            move.w  #RAPTOR_NTSC_WIDTH,d0
            move.w  #RAPTOR_NTSC_VMID,d6
            move.w  #RAPTOR_NTSC_HEIGHT,d4
            ;move.w    #8,raptor_topclip_val

		move.l	#26-26+8,GPU_premiere_ligne
		move.l	#508-26+8,GPU_derniere_ligne
		move.l	#60,_50ou60hertz	

            bra.s     .calc_vals
.palvals:    move.w     #RAPTOR_PAL_HMID,d2
            move.w     #RAPTOR_PAL_WIDTH,d0
            move.w     #RAPTOR_PAL_VMID+30,d6                        ; +30  322
            move.w     #RAPTOR_PAL_HEIGHT,d4

		move.l	#26+16+16,GPU_premiere_ligne
		move.l	#(256*2)+26+16+16,GPU_derniere_ligne
		move.l	#60,_50ou60hertz	


            ;move.w    #8,raptor_topclip_val
.calc_vals:    ;move.w  d0,raptor_width
            ;move.w  d4,raptor_height
            move.w  d0,d1
            asr     #1,d1                               ; Width/2
            sub.w   d1,d2                               ; Mid - Width/2
            add.w   #4,d2                               ; (Mid - Width/2)+4
            sub.w   #1,d1                               ; Width/2 - 1
            ori.w   #$400,d1                            ; (Width/2 - 1)|$400
            ;move.w  d1,raptor_a_hde
	        move.w  d1,a_hde
            move.w  d1,HDE
            ;move.w  d2,raptor_a_hdb
			move.w  d2,a_hdb
            move.w  d2,HDB1
            move.w  d2,HDB2
            move.w  d6,d5
            sub.w   d4,d5
            add.w   #16,d5
			move.w  d5,a_vdb
            ;move.w  d5,raptor_a_vdb
            add.w   d4,d6
			move.w  d6,a_vde
            ;move.w  d6,raptor_a_vde
            move.w  d5,VDB
            move.w  #$ffff,VDE
            move.w  #couleur_de_fond_BORD1,BORD1                            ; Black border
            move.w  #couleur_de_fond_BORD2,BORD2                            ; Black border
            move.w  #couleur_de_fond,BG                               ; Init line buffer to black
			
			; force ntsc pour pal
			
            movem.l (sp)+,d0-d6
            rts
			
			
;-------------------------------------------
;      VIDEO INITIALIZATION CONSTANTS
;-------------------------------------------

;NTSC_WIDTH      EQU     1409            ; Width of screen in pixel clocks
;NTSC_HMID       EQU     823             ; Middle of screen in pixel clocks
;NTSC_HEIGHT     EQU     241             ; Height of screen in scanlines
;NTSC_VMID       EQU     266             ; Middle of screen in halflines
;PAL_WIDTH       EQU     1381            ; Same as above for PAL...
;PAL_HMID        EQU     843
;PAL_HEIGHT      EQU     287
;PAL_VMID        EQU     322


; 320 PIXELS WIDE
RAPTOR_NTSC_WIDTH      EQU     1229               ; Width of screen in pixel clocks
RAPTOR_NTSC_HMID       EQU     787                ; Middle of screen in pixel clocks
RAPTOR_NTSC_HEIGHT     EQU     241				; 225             ; Height of screen in scanlines
RAPTOR_NTSC_VMID       EQU     266             ; Middle of screen in halflines

; 3.923295454545455
RAPTOR_PAL_WIDTH       EQU     1255            ; Same as above for PAL...
RAPTOR_PAL_HMID        EQU     821
RAPTOR_PAL_HEIGHT      EQU     256				; 225
RAPTOR_PAL_VMID        EQU     322



;*************************************************************************
;
; AMIGA Future Composer v1.4 player
; v1.3 support added by Leonard
;
;*************************************************************************
; A0=pointeur sur le module FC3 ou FC4
; A1=pCustomChip = $dff000

;		lea		(Paula_custom-$A0),a1
;		lea		module_FC,a0
		;bra.s	fcInit
		;bra		fcTick
		;bra.s	fcEnd


; -----------------------------------------------
fcEnd:
	;moveq	#$f,d0
	;trap	#1												;bsr	writeDmacon
	move.l	#$F,dmacon
.waitint1:
				nop
				move.l	D_CTRL,d0
				btst	#6,d0
				bne.s	.waitint1

	or.l	#DSPINT0,D_CTRL
	rts

; -----------------------------------------------
fcInit:

	move.l	a1,pCustom

;	bset #1,$bfe001
	lea	pModule(pc),a1
	move.l	a0,(a1)


	lea		dataClearStart(pc),a1
	move.w	#(dataClearEnd - dataClearStart) - 1,d1
.dClear:
	clr.b	(a1)+
	dbf		d1,.dClear

	tst.b	bSoundBankReloc
	bne.s	.already
	
	lea		FCSoundBank(pc),a1
	move.l	a1,d1
	lea		SOUNDINFO+(90*16)(pc),a1
	move.w	#256-90-1,d2
.rLoop:
	add.l	d1,(a1)
	lea		16(a1),a1
	dbf		d2,.rLoop
	st		bSoundBankReloc
	
	
.already:


	move.w #1,onoff

	lea		bFc14(pc),a1
	cmpi.l	#'FC14',(a0)
	seq		(a1)

	lea	100(a0),a1
	tst.b	bFc14
	beq.s	.no14
	lea		180(a0),a1
.no14:
	move.l a1,SEQpoint
	move.l a0,a1
	add.l 8(a0),a1
	move.l a1,PATpoint
	move.l a0,a1
	add.l 16(a0),a1
	move.l a1,FRQpoint
	move.l a0,a1
	add.l 24(a0),a1
	move.l a1,VOLpoint

	lea 40(a0),a1
	lea SOUNDINFO+4(pc),a2
	moveq #10-1,d1
initloop:
	move.w (a1)+,(a2)+
	move.l (a1)+,(a2)+
	adda.w #10,a2
	dbf d1,initloop

	move.l a0,d1
	add.l 32(a0),d1
	lea SOUNDINFO(pc),a3
	move.l d1,(a3)+
	moveq #9-1,d3
	moveq #0,d2
	
	moveq	#0,d4
	tst.b	bFc14
	beq.s	.no142
	moveq	#2,d4
.no142:
	
	
initloop1:
	move.w (a3),d2
	add.l d2,d1
	add.l d2,d1
	add.l d4,d1				; +0 ou +2 selon FC13 ou FC14
	adda.w #12,a3
	move.l d1,(a3)+
	dbf d3,initloop1


	tst.b	bFc14
	beq.s	init13

;---------------- init FC14

	lea 100(a0),a1
	lea SOUNDINFO+(10*16)(pc),a2
	move.l a0,a3
	add.l 36(a0),a3

	moveq #47-1,d1
	moveq #0,d2
initloop2:
	move.l a3,(a2)+
	move.b (a1)+,d2
	move.w d2,(a2)+
	clr.w (a2)+
	move.w d2,(a2)+
	addq.w #6,a2
	add.w d2,a3
	add.w d2,a3
	dbf d1,initloop2
	bra.s	skipInit13

;--------------------- init FC13

sndInfo3:
	dc.b	$10,$10,$10,$10,$10,$10,$10,$10
	dc.b	$10,$10,$10,$10,$10,$10,$10,$10
	dc.b	$10,$10,$10,$10,$10,$10,$10,$10
	dc.b	$10,$10,$10,$10,$10,$10,$10,$10
	dc.b	$08,$08,$08,$08,$08,$08,$08,$08
	dc.b	$10,$08,$10,$10,$08,$08,$18
	even

init13:
	lea SOUNDINFO+(10*16)(pc),a2
	lea		sndInfo3(pc),a3
	
	moveq #80-1,d1
	moveq #0,d2
	lea		waveForms,a4
	
.mloop:
	move.l	a4,(a2)+
	moveq	#0,d0
	move.b	(a3)+,d0		; TODO: Bug in original AMIGA routine: Read more entries than the sndInfo3 contains !!
	move.w	d0,(a2)+		; length
	clr.w	(a2)+			; repeat start = 0
	move.w	d0,(a2)+		; repeat length = length
	add.w	d0,d0			; word to bytes
	add.w	d0,a4
	addq.w	#6,a2
	dbf		d1,.mloop

;--------------------------------------------


skipInit13:

	move.l SEQpoint(pc),a0
	moveq #0,d2
	move.b 12(a0),d2		;Get replay speed
	bne.s speedok
	move.b #3,d2			;Set default speed
speedok:
	move.w d2,respcnt		;Init repspeed counter
	move.w d2,repspd
INIT2:
	clr.w audtemp
;	move.w #$000f,$dff096		;Disable audio DMA
;	move.w #$0780,$dff09a		;Disable audio IRQ

	;moveq	#$f,d0
	;trap	#1														;	bsr	writeDmacon
	move.l	#$F,dmacon
.waitint1:
				nop
				move.l	D_CTRL,d0
				btst	#6,d0
				bne.s	.waitint1

	or.l	#DSPINT0,D_CTRL	
	
	moveq #0,d7

	move.l	pModule(pc),a0
	move.l 4(a0),d0
	divu	#13,d0
	mulu.w	#13,d0

	moveq #0,d6			;Number of soundchannels-1
	lea V1data(pc),a0		;Point to 1st voice data area
	lea SILENT(pc),a1
initloop3:
	move.l a1,10(a0)
	move.l a1,18(a0)
	clr.w 4(a0)
	move.w #$000d,6(a0)
	clr.w 8(a0)
	clr.l 14(a0)
	move.b #$01,23(a0)
	move.b #$01,24(a0)
	clr.b 25(a0)
	clr.l 26(a0)
	clr.w 30(a0)
	clr.l 38(a0)
	clr.w 42(a0)
	clr.l 44(a0)
	clr.l 48(a0)
	clr.w 56(a0)

	moveq	#0,d4
	bset	d6,d4
	move.w	d4,32(a0)

	move.l	pCustom(pc),a6
	lea		$a0(a6),a6					; pointe sur les registres audio
	move.w	d6,d1
	lsl.w	#4,d1						; channel * 16
	add.w	d1,a6
	move.l 	#nullSample,(a6)
	move.w 	#$0100,4(a6)
	move.w 	#$0000,6(a6)
	move.w 	#$0000,8(a6)
	move.l 	a6,60(a0)

	move.l SEQpoint(pc),(a0)
	move.l SEQpoint(pc),52(a0)
	move.w	d6,d5
	mulu.w	#3,d5
	add.l	d5,52(a0)
	add.l	d5,(a0)
	add.l	d0,52(a0)

	move.l	(a0),a3
	moveq	#0,d1
	move.b	(a3),d1
	lsl.w	#6,d1
	move.l	PATpoint(pc),a4
	adda.w	d1,a4
	move.l	a4,34(a0)
	move.b	1(a3),44(a0)
	move.b	2(a3),22(a0)
	lea 	74(a0),a0		;Point to next voice's data area
	addq.w	#1,d6
	cmpi.w	#4,d6
	bne		initloop3
	rts


; -----------------------------------------------
; Tick de replay
; -----------------------------------------------
fcTick:
	lea audtemp(pc),a5
	tst.w 8(a5)
	bne.s music_on
	rts
music_on:
	moveq #0,d5			; [ARNAUD] BUG in original code: D5 and D6 were not settet properly in no new note !!!
	moveq #6,d6
	subq.w #1,4(a5)			;Decrease replayspeed counter
	bne.s nonewnote

	move.w 6(a5),4(a5)		;Restore replayspeed counter
	lea V1data(pc),a0		;Point to voice1 data area
	bsr.w new_note
	lea V2data(pc),a0		;Point to voice2 data area
	bsr.w new_note
	lea V3data(pc),a0		;Point to voice3 data area
	bsr.w new_note
	lea V4data(pc),a0		;Point to voice4 data area
	bsr.w new_note
	
	
nonewnote:
	clr.w (a5)
;	lea	custom(pc),a6
	move.l	pCustom(pc),a6
	lea V1data(pc),a0
	bsr.w EFFECTS
	move.l d0,$a6(a6)				; ecriture period 0 + volume 0
	
	lea V2data(pc),a0
	bsr.w EFFECTS
	move.l d0,$b6(a6)				; ecriture period 1 + volume 1
	
	lea V3data(pc),a0
	bsr.w EFFECTS
	move.l d0,$c6(a6)				; ecriture period 2 + volume 2
	
	lea V4data(pc),a0
	bsr.w EFFECTS
	move.l d0,$d6(a6)				; ecriture period 3 + volume 3
	
	lea V1data(pc),a0
	move.l 	68+(0*74)(a0),a1		;Get samplepointer
	adda.w 	64+(0*74)(a0),a1		;add repeat_start
	move.l 	68+(1*74)(a0),a2
	adda.w 	64+(1*74)(a0),a2
	move.l 	68+(2*74)(a0),a3
	adda.w 	64+(2*74)(a0),a3
	move.l 	68+(3*74)(a0),a4
	adda.w 	64+(3*74)(a0),a4
	move.w 	66+(0*74)(a0),d1		;Get repeat_length
	move.w 	66+(1*74)(a0),d2
	move.w 	66+(2*74)(a0),d3
	move.w 	66+(3*74)(a0),d4

	move.w (a5),d0
	ori.w #$8000,d0			;Set/clr bit = 1
;	move.w	d0,$dff096
	;trap	#1															;	bsr	writeDmacon
	ext.l	d0
	move.l	d0,dmacon
.waitint1:
				nop
				move.l	D_CTRL,d0
				btst	#6,d0
				bne.s	.waitint1

	or.l	#DSPINT0,D_CTRL			; EDZ 030123

	moveq #2,d0
	moveq #0,d5
chan1:
	lea V1data+72(pc),a0
	move.w (a0),d7
	beq.s chan2
	subq.w #1,(a0)
	cmp.w d0,d7
	bne.s chan2
	move.w d5,(a0)
	move.l a1,$a0(a6)		; Set samplestart 0
	move.w d1,$a4(a6)		; Set samplelength 0
chan2:
	lea V2data+72(pc),a0
	move.w (a0),d7
	beq.s chan3
	subq.w #1,(a0)
	cmp.w d0,d7
	bne.s chan3
	move.w d5,(a0)
	move.l a2,$b0(a6)		; Set samplestart 1
	move.w d2,$b4(a6)		; Set samplelength 1
chan3:
	lea V3data+72(pc),a0
	move.w (a0),d7
	beq.s chan4
	subq.w #1,(a0)
	cmp.w d0,d7
	bne.s chan4
	move.w d5,(a0)
	move.l a3,$c0(a6)		; Set samplestart 2
	move.w d3,$c4(a6)		; Set samplelength 2
chan4:
	lea V4data+72(pc),a0
	move.w (a0),d7
	beq.s endplay
	subq.w #1,(a0)
	cmp.w d0,d7
	bne.s endplay
	move.w d5,(a0)
	move.l a4,$d0(a6)		; Set samplestart 3
	move.w d4,$d4(a6)		; Set samplelength 3
endplay:

	rts

new_note:
	move.l 34(a0),a1
	adda.w 40(a0),a1
	cmp.b #$49,(a1)		;Check "END" mark in pattern
	beq.s patend
	cmp.w #64,40(a0)		;Have all the notes been played?
	bne.s samepat
patend:
	move.w d5,40(a0)
	move.l (a0),a2
	adda.w 6(a0),a2		;Point to next sequence row
	cmpa.l 52(a0),a2	;Is it the end?
	bne.s notend
	move.w d5,6(a0)		;yes!
	move.l (a0),a2		;Point to first sequence
	st		bEndMusicTrigger
	
notend:
	lea spdtemp(pc),a3
	moveq #1,d1
	addq.b #1,(a3)
	cmpi.b #5,(a3)
	bne.s nonewspd
	move.b d1,(a3)
	move.b 12(a2),d1	;Get new replay speed
	beq.s nonewspd
	move.w d1,2(a3)		;store in counter
	move.w d1,4(a3)
nonewspd:
	move.b (a2)+,d1		;Pattern to play
	move.b (a2)+,44(a0)	;Transpose value
	move.b (a2)+,22(a0)	;Soundtranspose value
	lsl.w d6,d1
	move.l PATpoint(pc),a1	;Get pattern pointer
	add.w d1,a1
	move.l a1,34(a0)
	addi.w #$000d,6(a0)
samepat:
	move.b 1(a1),d1		;Get info byte
	move.b (a1)+,d0		;Get note
	bne.s ww1
	andi.w #%11000000,d1
	beq.s noport
	bra.s ww11
ww1:
	move.w d5,56(a0)
ww11:
	move.b d5,47(a0)
	btst #7,d1
	beq.s noport
	move.b 2(a1),47(a0)
noport:
	andi.w #$007f,d0
	beq	 nextnote
	move.b d0,8(a0)
	move.b (a1),d1
	move.b d1,9(a0)
	move.w 32(a0),d3
	or.w d3,(a5)
;	move.w d3,$dff096


;	move.w	d0,-(a7)
;	move.w	d3,d0
;	trap	#1													;	bsr	writeDmacon
;	move.w	(a7)+,d0
	ext.l	d3
	move.l	d3,dmacon
.waitint3:
				nop
				move.l	D_CTRL,d3
				btst	#6,d3
				bne.s	.waitint3

	or.l	#DSPINT0,D_CTRL				; EDZ 030123

	andi.w #$003f,d1	;Max 64 instruments
	add.b 22(a0),d1		;add Soundtranspose
	move.l VOLpoint(pc),a2
	lsl.w d6,d1
	adda.w d1,a2
	move.w d5,16(a0)
	move.b (a2),23(a0)
	move.b (a2)+,24(a0)
	moveq #0,d1
	move.b (a2)+,d1
	move.b (a2)+,27(a0)
	move.b #$40,46(a0)
	move.b (a2),28(a0)
	move.b (a2)+,29(a0)
	move.b (a2)+,30(a0)
	move.l a2,10(a0)
	move.l FRQpoint(pc),a2
	lsl.w d6,d1
	adda.w d1,a2
	move.l a2,18(a0)
	move.w d5,50(a0)
	move.b d5,25(a0)
	move.b d5,26(a0)
nextnote:
	addq.w #2,40(a0)
	rts

EFFECTS:
	moveq #0,d7
testsustain:
	tst.b 26(a0)		;Is sustain counter = 0
	beq.s sustzero
	subq.b #1,26(a0)	;if no, decrease counter
	bra.w VOLUfx
sustzero:		;Next part of effect sequence
	move.l 18(a0),a1	;can be executed now.
	adda.w 50(a0),a1
testeffects:
	cmpi.b #$e1,(a1)	;E1 = end of FREQseq sequence
	beq.w VOLUfx
	move.b (a1),d0
	cmpi.b #$e0,d0		;E0 = loop to other part of sequence
	bne.s testnewsound
	move.b 1(a1),d1		;loop to start of sequence + 1(a1)
	andi.w #$003f,d1
	move.w d1,50(a0)
	move.l 18(a0),a1
	adda.w d1,a1
	move.b (a1),d0
testnewsound:
	cmpi.b #$e2,d0		;E2 = set waveform
	bne.s testE4




e2:	move.w 32(a0),d1
	or.w d1,(a5)
;	move.w d1,$dff096


	;move.w	d0,-(a7)
	;move.w	d1,d0
	;trap	#1																;	bsr	writeDmacon
	;move.w	(a7)+,d0
	ext.l	d1
	move.l	d1,dmacon
.waitint1:
				nop
				move.l	D_CTRL,d1
				btst	#6,d1
				bne.s	.waitint1

	or.l	#DSPINT0,D_CTRL				; EDZ 030123


	moveq #0,d0
	move.b 1(a1),d0
	lea SOUNDINFO(pc),a4
	lsl.w #4,d0
	adda.w d0,a4

	move.l 60(a0),a3	; dff0?0
	move.l (a4)+,d1
	move.l d1,(a3)
	move.l d1,68(a0)


	move.w (a4)+,4(a3)	; nouvelle taille replen




	move.l (a4),64(a0)	; replen adress

	move.w #$0003,72(a0)
	move.w d7,16(a0)
	move.b #$01,23(a0)
	addq.w #2,50(a0)
	bra.w transpose
testE4:
	cmpi.b #$e4,d0
	bne.s testE9
	moveq #0,d0
	move.b 1(a1),d0
	lea SOUNDINFO(pc),a4
	lsl.w #4,d0
	adda.w d0,a4
	move.l 60(a0),a3	; dff0?0
	move.l (a4)+,d1
	move.l d1,(a3)
	move.l d1,68(a0)


	move.w (a4)+,4(a3)
	move.l (a4),64(a0)
	move.w #$0003,72(a0)
	addq.w #2,50(a0)
	bra.w transpose
testE9:
	cmpi.b #$e9,d0
	bne.s testpatjmp
	move.w 32(a0),d1
	or.w d1,(a5)
	
;	move.w d1,$dff096
	;move.w	d0,-(a7)
	;move.w	d1,d0
	;trap	#1	;	bsr	writeDmacon
	;move.w	(a7)+,d0
	ext.l	d1
	move.l	d1,dmacon
.waitint1:
				nop
				move.l	D_CTRL,d1
				btst	#6,d1
				bne.s	.waitint1

	or.l	#DSPINT0,D_CTRL					; EDZ 030123

	moveq #0,d0
	move.b 1(a1),d0
	lea SOUNDINFO(pc),a4
	lsl.w #4,d0
	adda.w d0,a4
	move.l (a4),a2
	cmpi.l #"SSMP",(a2)+
	bne.s nossmp
	lea 320(a2),a4
	moveq #0,d1
	move.b 2(a1),d1
	lsl.w #4,d1
	add.w d1,a2
	add.l (a2),a4
	move.l 60(a0),a3	; dff0?0


	move.l a4,(a3)
	move.l 4(a2),4(a3)
	move.l a4,68(a0)
	move.l 6(a2),64(a0)

	move.w d7,16(a0)
	move.b #1,23(a0)
	move.w #3,72(a0)
nossmp:
	addq.w #3,50(a0)
	bra.s transpose
testpatjmp:
	cmpi.b #$e7,d0
	bne.s testpitchbend
	moveq #0,d0
	move.b 1(a1),d0
	lsl.w d6,d0
	move.l FRQpoint(pc),a1
	adda.w d0,a1
	move.l a1,18(a0)
	move.w d7,50(a0)
	bra.w testeffects
testpitchbend:
	cmpi.b #$ea,d0
	bne.s testnewsustain
	move.b 1(a1),4(a0)
	move.b 2(a1),5(a0)
	addq.w #3,50(a0)
	bra.s transpose
testnewsustain:
	cmpi.b #$e8,d0
	bne.s testnewvib
	move.b 1(a1),26(a0)
	addq.w #2,50(a0)
	bra.w testsustain
testnewvib:
	cmpi.b #$e3,(a1)+
	bne.s transpose
	addq.w #3,50(a0)
	move.b (a1)+,27(a0)
	move.b (a1),28(a0)
transpose:
	move.l 18(a0),a1
	adda.w 50(a0),a1
	move.b (a1),43(a0)
	addq.w #1,50(a0)

VOLUfx:
	tst.b 25(a0)
	beq.s volsustzero
	subq.b #1,25(a0)
	bra.w calcperiod
volsustzero:
	tst.b 15(a0)
	bne.s do_VOLbend
	subq.b #1,23(a0)
	bne.s calcperiod
	move.b 24(a0),23(a0)
volu_cmd:
	move.l 10(a0),a1
	adda.w 16(a0),a1
	move.b (a1),d0
testvoluend:
	cmpi.b #$e1,d0
	beq.s calcperiod
	cmpi.b #$ea,d0
	bne.s testVOLsustain
	move.b 1(a1),14(a0)
	move.b 2(a1),15(a0)
	addq.w #3,16(a0)
	bra.s do_VOLbend
testVOLsustain:
	cmpi.b #$e8,d0
	bne.s testVOLloop
	addq.w #2,16(a0)
	move.b 1(a1),25(a0)
	bra.s calcperiod
testVOLloop:
	cmpi.b #$e0,d0
	bne.s setvolume
	move.b 1(a1),d0
	andi.w #$003f,d0
	subq.b #5,d0
	move.w d0,16(a0)
	bra.s volu_cmd
do_VOLbend:
	not.b 38(a0)
	beq.s calcperiod
	subq.b #1,15(a0)
	move.b 14(a0),d1
	add.b d1,45(a0)
	bpl.s calcperiod
	moveq #0,d1
	move.b d1,15(a0)
	move.b d1,45(a0)
	bra.s calcperiod
setvolume:
	move.b (a1),45(a0)
	addq.w #1,16(a0)
calcperiod:
	move.b 43(a0),d0
	bmi.s lockednote
	add.b 8(a0),d0
	add.b 44(a0),d0
lockednote:
	moveq #$7f,d1
	and.l d1,d0
	lea PERIODS(pc),a1
	add.w d0,d0
	move.w d0,d1
	adda.w d0,a1
	move.w (a1),d0

	move.b 46(a0),d7
	tst.b 30(a0)		;Vibrato_delay = zero ?
	beq.s vibrator
	subq.b #1,30(a0)
	bra.s novibrato
vibrator:
	moveq #5,d2
	move.b d1,d5
	move.b 28(a0),d4
	add.b d4,d4
	move.b 29(a0),d1
	tst.b d7
	bpl.s vib1
	btst #0,d7
	bne.s vib4
vib1:
	btst d2,d7
	bne.s vib2
	sub.b 27(a0),d1
	bcc.s vib3
	bset d2,d7
	moveq #0,d1
	bra.s vib3
vib2:
	add.b 27(a0),d1
	cmp.b d4,d1
	bcs.s vib3
	bclr d2,d7
	move.b d4,d1
vib3:
	move.b d1,29(a0)
vib4:
	lsr.b #1,d4
	sub.b d4,d1
	bcc.s vib5
	subi.w #$0100,d1
vib5:
	addi.b #$a0,d5
	bcs.s vib7
vib6:
	add.w d1,d1
	addi.b #$18,d5
	bcc.s vib6
vib7:
	add.w d1,d0
novibrato:
	eori.b #$01,d7
	move.b d7,46(a0)

; DO THE PORTAMENTO THING
	not.b 39(a0)
	beq.s pitchbend
	moveq #0,d1
	move.b 47(a0),d1	;get portavalue
	beq.s pitchbend		;0=no portamento
	cmpi.b #$1f,d1
	bls.s portaup
portadown:
	andi.w #$1f,d1
	neg.w d1
portaup:
	sub.w d1,56(a0)
pitchbend:
	not.b 42(a0)
	beq.s addporta
	tst.b 5(a0)
	beq.s addporta
	subq.b #1,5(a0)
	moveq #0,d1
	move.b 4(a0),d1
	bpl.s pitchup
	ext.w d1
pitchup:
	sub.w d1,56(a0)
addporta:
	add.w 56(a0),d0
	cmpi.w #$0070,d0
	bhi.s nn1
	move.w #$0071,d0
nn1:
	cmpi.w #$0d60,d0
	bls.s nn2
	move.w #$0d60,d0
nn2:
	swap d0
	move.b 45(a0),d0
	rts


	.phrase
dataClearStart:

V1data:  dcb.b 64,0	;Voice 1 data area
offset1: dcb.b 2,0	;Is added to start of sound
ssize1:  dcb.b 2,0	;Length of sound
start1:  dcb.b 6,0	;Start of sound
V2data:  dcb.b 64,0	;Voice 2 data area
offset2: dcb.b 2,0
ssize2:  dcb.b 2,0
start2:  dcb.b 6,0
V3data:  dcb.b 64,0	;Voice 3 data area
offset3: dcb.b 2,0
ssize3:  dcb.b 2,0
start3:  dcb.b 6,0
V4data:  dcb.b 64,0	;Voice 4 data area
offset4: dcb.b 2,0
ssize4:  dcb.b 2,0
start4:  dcb.b 6,0
audtemp: dc.w 0		;DMACON
spdtemp: dc.w 0
respcnt: dc.w 0		;Replay speed counter
repspd:  dc.w 0		;Replay speed counter temp
onoff:   dc.w 0		;Music on/off flag.

SEQpoint: dc.l 0
PATpoint: dc.l 0
FRQpoint: dc.l 0
VOLpoint: dc.l 0


nullSample:	dc.w	0
bFc14:		dc.w	0



dataClearEnd:

pCustom:	ds.l	1
pModule:	ds.l	1

	.phrase
SOUNDINFO:
;Start.l , Length.w , Repeat start.w , Repeat-length.w , dcb.b 6,0
	dcb.b 	(10*16),0	;Reserved for samples
	dcb.b 	(80*16),0	;Reserved for waveforms

	.phrase
	include "FcSoundBank.inc"
	

	.phrase
SILENT: dc.w $0100,$0000,$0000,$00e1

	.phrase
PERIODS:dc.w $06b0,$0650,$05f4,$05a0,$054c,$0500,$04b8,$0474
	dc.w $0434,$03f8,$03c0,$038a,$0358,$0328,$02fa,$02d0
	dc.w $02a6,$0280,$025c,$023a,$021a,$01fc,$01e0,$01c5
	dc.w $01ac,$0194,$017d,$0168,$0153,$0140,$012e,$011d
	dc.w $010d,$00fe,$00f0,$00e2,$00d6,$00ca,$00be,$00b4
	dc.w $00aa,$00a0,$0097,$008f,$0087,$007f,$0078,$0071
	dc.w $0071,$0071,$0071,$0071,$0071,$0071,$0071,$0071
	dc.w $0071,$0071,$0071,$0071,$0d60,$0ca0,$0be8,$0b40
	dc.w $0a98,$0a00,$0970,$08e8,$0868,$07f0,$0780,$0714
	dc.w $1ac0,$1940,$17d0,$1680,$1530,$1400,$12e0,$11d0
	dc.w $10d0,$0fe0,$0f00,$0e28,$06b0,$0650,$05f4,$05a0
	dc.w $054c,$0500,$04b8,$0474,$0434,$03f8,$03c0,$038a
	dc.w $0358,$0328,$02fa,$02d0,$02a6,$0280,$025c,$023a
	dc.w $021a,$01fc,$01e0,$01c5,$01ac,$0194,$017d,$0168
	dc.w $0153,$0140,$012e,$011d,$010d,$00fe,$00f0,$00e2
	dc.w $00d6,$00ca,$00be,$00b4,$00aa,$00a0,$0097,$008f
	dc.w $0087,$007f,$0078,$0071

	.phrase
waveForms:
	dc.b	$c0,$c0,$d0,$d8,$e0,$e8,$f0,$f8,$00,$f8,$f0,$e8,$e0,$d8,$d0,$c8
	dc.b	$3f,$37,$2f,$27,$1f,$17,$0f,$07,$ff,$07,$0f,$17,$1f,$27,$2f,$37
	dc.b	$c0,$c0,$d0,$d8,$e0,$e8,$f0,$f8,$00,$f8,$f0,$e8,$e0,$d8,$d0,$c8
	dc.b	$c0,$37,$2f,$27,$1f,$17,$0f,$07,$ff,$07,$0f,$17,$1f,$27,$2f,$37
	dc.b	$c0,$c0,$d0,$d8,$e0,$e8,$f0,$f8,$00,$f8,$f0,$e8,$e0,$d8,$d0,$c8
	dc.b	$c0,$b8,$2f,$27,$1f,$17,$0f,$07,$ff,$07,$0f,$17,$1f,$27,$2f,$37
	dc.b	$c0,$c0,$d0,$d8,$e0,$e8,$f0,$f8,$00,$f8,$f0,$e8,$e0,$d8,$d0,$c8
	dc.b	$c0,$b8,$b0,$27,$1f,$17,$0f,$07,$ff,$07,$0f,$17,$1f,$27,$2f,$37
	dc.b	$c0,$c0,$d0,$d8,$e0,$e8,$f0,$f8,$00,$f8,$f0,$e8,$e0,$d8,$d0,$c8
	dc.b	$c0,$b8,$b0,$a8,$1f,$17,$0f,$07,$ff,$07,$0f,$17,$1f,$27,$2f,$37
	dc.b	$c0,$c0,$d0,$d8,$e0,$e8,$f0,$f8,$00,$f8,$f0,$e8,$e0,$d8,$d0,$c8
	dc.b	$c0,$b8,$b0,$a8,$a0,$17,$0f,$07,$ff,$07,$0f,$17,$1f,$27,$2f,$37
	dc.b	$c0,$c0,$d0,$d8,$e0,$e8,$f0,$f8,$00,$f8,$f0,$e8,$e0,$d8,$d0,$c8
	dc.b	$c0,$b8,$b0,$a8,$a0,$98,$0f,$07,$ff,$07,$0f,$17,$1f,$27,$2f,$37
	dc.b	$c0,$c0,$d0,$d8,$e0,$e8,$f0,$f8,$00,$f8,$f0,$e8,$e0,$d8,$d0,$c8
	dc.b	$c0,$b8,$b0,$a8,$a0,$98,$90,$07,$ff,$07,$0f,$17,$1f,$27,$2f,$37
	dc.b	$c0,$c0,$d0,$d8,$e0,$e8,$f0,$f8,$00,$f8,$f0,$e8,$e0,$d8,$d0,$c8
	dc.b	$c0,$b8,$b0,$a8,$a0,$98,$90,$88,$ff,$07,$0f,$17,$1f,$27,$2f,$37
	dc.b	$c0,$c0,$d0,$d8,$e0,$e8,$f0,$f8,$00,$f8,$f0,$e8,$e0,$d8,$d0,$c8
	dc.b	$c0,$b8,$b0,$a8,$a0,$98,$90,$88,$80,$07,$0f,$17,$1f,$27,$2f,$37
	dc.b	$c0,$c0,$d0,$d8,$e0,$e8,$f0,$f8,$00,$f8,$f0,$e8,$e0,$d8,$d0,$c8
	dc.b	$c0,$b8,$b0,$a8,$a0,$98,$90,$88,$80,$88,$0f,$17,$1f,$27,$2f,$37
	dc.b	$c0,$c0,$d0,$d8,$e0,$e8,$f0,$f8,$00,$f8,$f0,$e8,$e0,$d8,$d0,$c8
	dc.b	$c0,$b8,$b0,$a8,$a0,$98,$90,$88,$80,$88,$90,$17,$1f,$27,$2f,$37
	dc.b	$c0,$c0,$d0,$d8,$e0,$e8,$f0,$f8,$00,$f8,$f0,$e8,$e0,$d8,$d0,$c8
	dc.b	$c0,$b8,$b0,$a8,$a0,$98,$90,$88,$80,$88,$90,$98,$1f,$27,$2f,$37
	dc.b	$c0,$c0,$d0,$d8,$e0,$e8,$f0,$f8,$00,$f8,$f0,$e8,$e0,$d8,$d0,$c8
	dc.b	$c0,$b8,$b0,$a8,$a0,$98,$90,$88,$80,$88,$90,$98,$a0,$27,$2f,$37
	dc.b	$c0,$c0,$d0,$d8,$e0,$e8,$f0,$f8,$00,$f8,$f0,$e8,$e0,$d8,$d0,$c8
	dc.b	$c0,$b8,$b0,$a8,$a0,$98,$90,$88,$80,$88,$90,$98,$a0,$a8,$2f,$37
	dc.b	$c0,$c0,$d0,$d8,$e0,$e8,$f0,$f8,$00,$f8,$f0,$e8,$e0,$d8,$d0,$c8
	dc.b	$c0,$b8,$b0,$a8,$a0,$98,$90,$88,$80,$88,$90,$98,$a0,$a8,$b0,$37
	dc.b	$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81
	dc.b	$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f
	dc.b	$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81
	dc.b	$81,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f
	dc.b	$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81
	dc.b	$81,$81,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f
	dc.b	$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81
	dc.b	$81,$81,$81,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f
	dc.b	$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81
	dc.b	$81,$81,$81,$81,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f
	dc.b	$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81
	dc.b	$81,$81,$81,$81,$81,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f
	dc.b	$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81
	dc.b	$81,$81,$81,$81,$81,$81,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f
	dc.b	$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81
	dc.b	$81,$81,$81,$81,$81,$81,$81,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f
	dc.b	$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81
	dc.b	$81,$81,$81,$81,$81,$81,$81,$81,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f
	dc.b	$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81
	dc.b	$81,$81,$81,$81,$81,$81,$81,$81,$81,$7f,$7f,$7f,$7f,$7f,$7f,$7f
	dc.b	$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81
	dc.b	$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$7f,$7f,$7f,$7f,$7f,$7f
	dc.b	$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81
	dc.b	$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$7f,$7f,$7f,$7f,$7f
	dc.b	$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81
	dc.b	$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$7f,$7f,$7f,$7f
	dc.b	$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81
	dc.b	$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$7f,$7f,$7f
	dc.b	$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80
	dc.b	$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$7f,$7f
	dc.b	$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80
	dc.b	$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$7f
	dc.b	$80,$80,$80,$80,$80,$80,$80,$80,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f
	dc.b	$80,$80,$80,$80,$80,$80,$80,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f
	dc.b	$80,$80,$80,$80,$80,$80,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f
	dc.b	$80,$80,$80,$80,$80,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f
	dc.b	$80,$80,$80,$80,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f
	dc.b	$80,$80,$80,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f
	dc.b	$80,$80,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f
	dc.b	$80,$80,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f,$7f
	dc.b	$80,$80,$90,$98,$a0,$a8,$b0,$b8,$c0,$c8,$d0,$d8,$e0,$e8,$f0,$f8
	dc.b	$00,$08,$10,$18,$20,$28,$30,$38,$40,$48,$50,$58,$60,$68,$70,$7f
	dc.b	$80,$80,$a0,$b0,$c0,$d0,$e0,$f0,$00,$10,$20,$30,$40,$50,$60,$70
	dc.b	$45,$45,$79,$7d,$7a,$77,$70,$66,$61,$58,$53,$4d,$2c,$20,$18,$12
	dc.b	$04,$db,$d3,$cd,$c6,$bc,$b5,$ae,$a8,$a3,$9d,$99,$93,$8e,$8b,$8a
	dc.b	$45,$45,$79,$7d,$7a,$77,$70,$66,$5b,$4b,$43,$37,$2c,$20,$18,$12
	dc.b	$04,$f8,$e8,$db,$cf,$c6,$be,$b0,$a8,$a4,$9e,$9a,$95,$94,$8d,$83
	dc.b	$00,$00,$40,$60,$7f,$60,$40,$20,$00,$e0,$c0,$a0,$80,$a0,$c0,$e0
	dc.b	$00,$00,$40,$60,$7f,$60,$40,$20,$00,$e0,$c0,$a0,$80,$a0,$c0,$e0
	dc.b	$80,$80,$90,$98,$a0,$a8,$b0,$b8,$c0,$c8,$d0,$d8,$e0,$e8,$f0,$f8
	dc.b	$00,$08,$10,$18,$20,$28,$30,$38,$40,$48,$50,$58,$60,$68,$70,$7f
	dc.b	$80,$80,$a0,$b0,$c0,$d0,$e0,$f0,$00,$10,$20,$30,$40,$50,$60,$70
	even

	.phrase
bSoundBankReloc:	dc.b	0
					dc.b	0
					
	.phrase
FCSoundBank:
	incbin	"FcSoundBank.bin"
	even







;--------------------------------------------- GPU ------------------------------------------


	.dphrase
GPU_debut:

	.gpu
	.org	G_RAM
GPU_base_memoire:
; CPU interrupt
	.rept	8				; 3
		nop
	.endr
; DSP interrupt, the interrupt output from Jerry
	.rept	8
		nop
	.endr
; Timing generator
	.rept	8
		nop
	.endr
; Object Processor
	jump	(R27)
	nop
	.rept	6
		nop
	.endr
; Blitter
	.rept	8
		nop
	.endr



GPU_init:
	movei	#GPU_ISP+(GPU_STACK_SIZE*4),r31			; init isp				6
	moveq	#0,r1										;						2
	moveta	r31,r31									; ISP (bank 0)		2
	nop													;						2
	movei	#GPU_USP+(GPU_STACK_SIZE*4),r31			; init usp				6

	moveq	#$0,R0										; 2
	moveta	R0,R26							; compteur	  2
	movei	#interrupt_OP,R1							; 6
	moveta	R1,R27										; 2

	movei	#OBF,R0									; 6
	moveta	R0,R22										; 2

	movei	#G_FLAGS,R1											; GPU flags
	moveta	R1,R28

	movei	#G_FLAGS,r30

	movei	#G_OPENA|REGPAGE,r29			; object list interrupt
	nop
	nop
	store	r29,(r30)
	nop
	nop

; swap les pointeurs d'OL
		movei	#GPU_pointeur_object_list_a_modifier,R0
		movei	#GPU_pointeur_object_list_a_afficher,R1
		load	(R0),R2
		load	(R1),R3
		store	R2,(R1)
		movei	#OLP,R4
		;moveta	R3,R3
		rorq	#16,R2
		store	R3,(R0)
		store	R2,(R4)

; swap les pointeurs de zone 3D
		movei	#pointeur_zone3D_a_modifier,R0
		movei	#pointeur_zone3D_a_afficher,R1
		load	(R0),R2
		load	(R1),R3
		store	R2,(R1)
		store	R3,(R0)



; -------------------------- LOOP ------------------------
GPU_loop:

	.if		temps_GPU=1
		movei	#BORD1,R26
		movei	#$8888,R25				; blanc en haut
		storew	R25,(R26)
	.endif


	.if			LIGNES3D_ON=1
; CLS zone 3D au blitter
	movei		#pointeur_zone3D_a_modifier,R10
	movei		#A1_BASE,R14
	moveq		#0,R0
	move		R14,R15
	load		(R10),R1					; R1 = zone a effacer
	movei		#PITCH1|PIXEL16|WID320|XADDPHR,R2
	store		R0,(R14+3)					; A1_PIXEL								F0220C				+3
	store		R0,(R15+$1A)				; B_PATD								F02268				+1A
	movei		#$00010000+(81920/2),R3
	store		R2,(R15+1)					; A1_FLAGS								F02204				+1
	store		R1,(R14)
	store		R0,(R15+$1B)				; B_PATD+4								F02268				+1A
	movei		#PATDSEL|UPDA1,R4
	store		R3,(R14+$0F)				; B_COUNT								F0223C				+0F
	store		R4,(R15+$0E)				; B_CMD		
	.endif

; ----------------- object list --------------------

; inserer zone motif
	movei		#GPU_premiere_ligne,R20
	movei		#GPU_pointeur_object_list_a_modifier,R10
	load		(R20),R4
	;movei		#pointeur_zone_scrolling_a_modifier,R17
	load		(R10),R11
	shlq		#3,R4
	movei		#((zone_scrolling_POSY)<<3)+(24<<14),R1				; YPOS<<3 + HEIGHT<<14
	addq		#32,R11
	;load		(R17),R0			; R0=DATA
	add			R4,R1
	movei		#motif_fond_scrolling,R0
	
	addq		#16,R11
	movei		#(zone_scrolling_POSX)+(4<<12)+(1<<15)+(80<<18)+(40<<28),R2				; XPOS+DEPTH+PITCH+DWIDTH+IWIDTH		1 plan			4=CRY
	;movei		#(zone3D_POSX)+(4<<12)+(1<<15)+(80<<18)+(80<<28),R2				; XPOS+DEPTH+PITCH+DWIDTH+IWIDTH		CRY
	;movei		#(%0101)+(1<<15),R3			; IWIDTH+TRANS			CRY
	movei		#(%0101)+(1<<15),R3			; IWIDTH+TRANS			CRY
	
	move		R11,R12				; R12 = link
	sharq		#3,R0
	addq		#16,R12				; R12 = link 
	shlq		#11,R0
	sharq		#3,R12				; aligné sur une phrase
	
	move		R12,R13
	shlq		#24,R12				; link partie 1
	sharq		#8,R13				; R13 = 2eme partie du link
	or			R0,R13				; DATA+LINK
	or			R12,R1
	store		R13,(R11)
	addq		#4,R11
	store		R1,(R11)
	addq		#4,R11
	store		R3,(R11)
	addq		#4,R11
	store		R2,(R11)
	addq		#4,R11


; inserer zone zone_resultat_scrolling_256c 320x24
	movei		#pointeur_zone_resultat_scrolling_a_modifier,R24
	movei		#((zone_scrolling_POSY)<<3)+(24<<14),R1				; YPOS<<3 + HEIGHT<<14
	load		(R24),R0
	add			R4,R1
	
	movei		#(zone_scrolling_POSX)+(3<<12)+(1<<15)+(40<<18)+(40<<28),R2				; XPOS+DEPTH+PITCH+DWIDTH+IWIDTH		1 plan
	;movei		#(zone3D_POSX)+(4<<12)+(1<<15)+(80<<18)+(80<<28),R2				; XPOS+DEPTH+PITCH+DWIDTH+IWIDTH		CRY
	;movei		#(%0101)+(1<<15),R3			; IWIDTH+TRANS			CRY
	movei		#(%0010)+(1<<15),R3			; IWIDTH+TRANS
	
	move		R11,R12				; R12 = link
	sharq		#3,R0
	addq		#16,R12				; R12 = link 
	shlq		#11,R0
	sharq		#3,R12				; aligné sur une phrase
	
	move		R12,R13
	shlq		#24,R12				; link partie 1
	sharq		#8,R13				; R13 = 2eme partie du link
	or			R0,R13				; DATA+LINK
	or			R12,R1
	store		R13,(R11)
	addq		#4,R11
	store		R1,(R11)
	addq		#4,R11
	store		R3,(R11)
	addq		#4,R11
	store		R2,(R11)
	addq		#4,R11


; remet le logo DUNE dans l'object list

	;movei		#GPU_pointeur_object_list_a_modifier,R10
	;movei		#((logo_DUNE>>3)<<11),R0
	movei		#logo_DUNE,R0
	;load		(R10),R11
	movei		#((logo_DUNE_POSY)<<3)+(240<<14),R1				; YPOS<<3 + HEIGHT<<14
	;addq		#32,R11
	movei		#(logo_DUNE_POSX)+(4<<12)+(1<<15)+(16<<18)+(16<<28),R2				; XPOS+DEPTH+PITCH+DWIDTH+IWIDTH
	add			R4,R1
	;addq		#16,R11
	movei		#(%0001)+(1<<15),R3			; IWIDTH+TRANS
	
	move		R11,R12				; R12 = link
	sharq		#3,R0
	addq		#16,R12				; R12 = link 
	shlq		#11,R0
	sharq		#3,R12				; aligné sur une phrase
	
	move		R12,R13
	shlq		#24,R12				; link partie 1
	sharq		#8,R13				; R13 = 2eme partie du link
	or			R0,R13				; DATA+LINK
	or			R12,R1
	store		R13,(R11)
	addq		#4,R11
	store		R1,(R11)
	addq		#4,R11
	store		R3,(R11)
	addq		#4,R11
	store		R2,(R11)
	addq		#4,R11





; inserer zone 3D
	movei		#pointeur_zone3D_a_modifier,R17
	movei		#((zone3D_POSY)<<3)+(hauteur_zone_3D<<14),R1				; YPOS<<3 + HEIGHT<<14
	load		(R17),R0			; R0=DATA
	add			R4,R1
	movei		#(zone3D_POSX)+(3<<12)+(1<<15)+(40<<18)+(40<<28),R2				; XPOS+DEPTH+PITCH+DWIDTH+IWIDTH		1 plan=0<<12 / 256c : 3<<12  // 05<<18 // 05<<28
	;movei		#(zone3D_POSX)+(4<<12)+(1<<15)+(80<<18)+(80<<28),R2				; XPOS+DEPTH+PITCH+DWIDTH+IWIDTH		CRY
	;movei		#(%0101)+(1<<15),R3			; IWIDTH+TRANS			CRY
	movei		#(%0010)+(1<<15),R3			; IWIDTH+TRANS // %0 pour 1 plan
	
	move		R11,R12				; R12 = link
	sharq		#3,R0
	addq		#16,R12				; R12 = link 
	shlq		#11,R0
	sharq		#3,R12				; aligné sur une phrase
	
	move		R12,R13
	shlq		#24,R12				; link partie 1
	sharq		#8,R13				; R13 = 2eme partie du link
	or			R0,R13				; DATA+LINK
	or			R12,R1
	store		R13,(R11)
	addq		#4,R11
	store		R1,(R11)
	addq		#4,R11
	store		R3,(R11)
	addq		#4,R11
	store		R2,(R11)
	addq		#4,R11


	
	
	
; insert un stop
		moveq	#4,R16
		moveq	#0,R13
		store	R13,(R11)		; 0000
		addq	#4,R11
		store	R16,(R11)		; 0004


; ----------------- fin object liste ------------------




; A2_PIXEL	EQU	BASE + $2230	; A2 PIXEL
; A2_STEP		EQU	BASE + $2234	; A2 Step (Integer)


		.if		SCROLLING_ON=1

; ------------ scrolling -------------
; il faut inserer une colonne de pixels à offset_zone_scrolling-1 et  offset_zone_scrolling+319
; dans  zone_scrolling_dessus_256c_640pixels
; EDZ
		movei		#pointeur_sur_zone_scrolling_a_modifier,R24
		movei		#offset_zone_scrolling,R10
		load		(R24),R20
		load		(R10),R1
		movei		#scrolling_pointeur_actuel_sur_lettre,R11		; = source
		add			R1,R20											; = dest
		load		(R11),R12
		movei		#320,R22
		move		R20,R21
		movei		#640,R23
		add			R22,R21					; + une demi ligne du buffer
		movei		#24,R19
		
copie_colonne_de_pixels_de_la_fonte:		
		loadb		(R12),r0
;edz
		;moveq		#0,R0

		storeb		R0,(R20)			; a gauche
		add			R22,R12				; fonte +320
		add			R23,R20				; buffer+640
		storeb		R0,(R21)			; a droite
		add			R23,R21				; buffer+640
		subq		#1,R19
		jr			ne,copie_colonne_de_pixels_de_la_fonte
		nop
		
; avance dans la lettre
		movei		#GPU__scrolling_pas_nouvelle_lettre,R29
		movei		#scrolling__pixel_actuel_dans_lettre,R10
		moveq		#16,R9
		load		(R10),R1
		movei		#scrolling_pointeur_actuel_sur_lettre,R11
		.if			avancer_le_scrolling=1
		addq		#1,R1
		.endif
		load		(R11),R2
		cmp			R9,R1
		jump		ne,(R29)
		addqt		#1,R2
; il faut gerer une nouvelle lettre ici

		movei		#scrolling__pointeur_actuel_texte_scrolling,R12
		moveq		#0,R1
		load		(R12),R3			; pointeur sur le texte
		addq		#4,R3
		load		(R3),R2				; pointeur sur la nouvelle lettre
		cmpq		#-1,R2
		jr 			ne,GPU__scrolling_pas_fin_du_texte
		nop
		movei		#texte_scrolling_traduit,R3
		load		(R3),R2				; pointeur sur la nouvelle lettre
GPU__scrolling_pas_fin_du_texte:
		store		R3,(R12)		
GPU__scrolling_pas_nouvelle_lettre:
		store		R1,(R10)
		store		R2,(R11)
		

		.if			avancer_le_scrolling=1
; avance scrolling offset
		movei		#offset_zone_scrolling,R10
		movei		#320,R12
		load		(R10),R11
		addq		#1,R11
		cmp			R12,R11
		jr			ne,pas_fin_offset_scrolling
		nop
		moveq		#0,R11
pas_fin_offset_scrolling:
		store		R11,(r10)
		.endif



; copier zone motif dans dest
; motif_fond_scrolling
; zone_resultat_scrolling_256c
; LFU_S

	movei		#A1_BASE,R14				; base du blitter
	movei		#A2_BASE,R15

	.if		1=0
GPU_wait_blitter_copie_motif:
	load 	(R14+($38/4)),R0				; Command Register=$38
	shrq 	#1,R0
	jr 		cc,GPU_wait_blitter_copie_motif
	nop

	;movei	#motif_fond_scrolling,R10				; A2=source
	movei	#zone_scrolling_dessus_256c_640pixels,R10
	movei	#zone_resultat_scrolling_256c,R12		; A1=dest
	movei	#PITCH1|PIXEL8|WID64|XADDPHR,R22		; flags A2
	movei	#PITCH1|PIXEL8|WID64|XADDPHR,R1		; flags A1 & A2
	movei	#((24<<16)|640),R2						; clip A1
	moveq	#0,R0
	store	R2,(R14+((A1_CLIP-A1_BASE)/4))						; _BLIT_A1_CLIP)
	store	R0,(R14+((A1_STEP-A1_BASE)/4))						; _BLIT_A1_STEP)
	store	R0,(R15+((A2_STEP-A2_BASE)/4))						; _BLIT_A1_STEP)
	store	R0,(R14+((A1_FSTEP-A1_BASE)/4))						; _BLIT_A1_FSTEP)
	store	R0,(R14+((A1_FPIXEL-A1_BASE)/4))						; _BLIT_A1_FSTEP)
	
	store	R0,(R14+((A1_INC-A1_BASE)/4))						; _BLIT_A1_FSTEP)
	store	R0,(R14+((A1_FINC-A1_BASE)/4))						; _BLIT_A1_FSTEP)
	
	

	store		R0,(R14+((A1_PIXEL-A1_BASE)/4))						; A1_PIXEL								F0220C				+3
	store		R0,(R15+((A2_PIXEL-A2_BASE)/4))						; A1_PIXEL								F0220C				+3
	
	movei		#$00180000+(320),R3
	store		R1,(R14+((A1_FLAGS-A1_BASE)/4))					; A1_FLAGS								F02204				+1
	store		R22,(R15+((A2_FLAGS-A2_BASE)/4))					; A1_FLAGS								F02204				+1
	store		R12,(R15)
	store		R10,(R14)
	;store		R0,(R15+$1B)				; B_PATD+4								F02268				+1A
	movei		#SRCEN|LFU_S|DSTA2,R4
	store		R3,(R14+((B_COUNT-A1_BASE)/4))				; B_COUNT								F0223C				+0F
	store		R4,(R14+((B_CMD-A1_BASE)/4))				; B_CMD			
	.endif


; 

; pas calé sur phrase : 
; the offset (in the pixel size set) from the phrase boundary written into the X pointer.
	

GPU_wait_blitter_copie_maskage:
	load 	(R14+$E),R0				; Command Register=$38
	btst 	#0,R0
	jr 		eq,GPU_wait_blitter_copie_maskage
	nop

	.if		1=0


	movei	#zone_resultat_scrolling_256c,R10				; A2=dest 
	movei	#zone_scrolling_dessus_256c_640pixels,R12				; A1=source
	movei	#PITCH1|PIXEL8|WID640|XADDINC,R6		; flags A1
	
	movei	#offset_zone_scrolling,R13
	
	movei	#PITCH1|PIXEL8|WID320|XADDPIX,R5		; flags A2
	load	(R13),R16								; entre 0 et 319
	movei	#$00180140,R2						; clip A1 00180140
	move	R16,R17
	moveq	#0,R0
	movei	#$00010001,R7
	moveq	#1,R1
	shrq	#3,R17
	shlq	#32-3,R16			; numero pixel sur 8
	shlq	#3,R17
	shrq	#32-3,R16
	store	R2,(R14+((A1_CLIP-A1_BASE)/4))						; _BLIT_A1_CLIP)
	add		R17,R12
	store	R7,(R14+((A1_STEP-A1_BASE)/4))						; _BLIT_A1_STEP)
	store	R7,(R15+((A2_STEP-A2_BASE)/4))						; _BLIT_A2_STEP)
	store	R0,(R14+((A1_FSTEP-A1_BASE)/4))						; _BLIT_A1_FSTEP)
	store	R0,(R14+((A1_FPIXEL-A1_BASE)/4))						; _BLIT_A1_FPIXEL)
	
	store	R1,(R14+((A1_INC-A1_BASE)/4))						; _BLIT_A1_INC) / inner loop
	store	R0,(R14+((A1_FINC-A1_BASE)/4))						; _BLIT_A1_FINC)
	
	

	store		R16,(R14+((A1_PIXEL-A1_BASE)/4))						; A1_PIXEL								F0220C				+3
	store		R0,(R15+((A2_PIXEL-A2_BASE)/4))						; A2_PIXEL								F0220C				+3
	
	movei		#$00180140,R3
	store		R6,(R14+((A1_FLAGS-A1_BASE)/4))					; A1_FLAGS								F02204				+1
	store		R5,(R15+((A2_FLAGS-A2_BASE)/4))					; A2_FLAGS								F02204				+1
	store		R3,(R14+15)										; B_COUNT								F0223C				+0F
	store		R10,(R15)
	store		R12,(R14)
	;store		R0,(R15+$1B)				; B_PATD+4								F02268				+1A
	movei		#SRCEN|LFU_REPLACE|DSTA2|CLIP_A1|UPDA1|UPDA2|UPDA1F,R4
	store		R4,(R14+((B_CMD-A1_BASE)/4))				; B_CMD			
	
	
	.endif

; version GPU
; copie 24 lignes
; de 320 pixels
; de pointeur_sur_zone_scrolling_a_modifier + offset_zone_scrolling
; dans pointeur_zone_resultat_scrolling_a_modifier

	.if		copie_du_scrolling_au_GPU=1

	movei	#320,R22
	movei	#pointeur_sur_zone_scrolling_a_modifier,R24
	movei	#offset_zone_scrolling,R13
	load	(R24),R10		; source=zone_scrolling_dessus_256c_640pixels
	load	(R13),R16								; entre 0 et 319
	movei	#pointeur_zone_resultat_scrolling_a_modifier,R25
	add		R16,R10
	movei	#GPU_copie_scrolling_au_GPU_pixels,R29
	load	(R25),R12			; R12 = dest multiple de 4
	movei	#GPU_copie_scrolling_au_GPU_ligne,R28
	movei	#24,R18
	
GPU_copie_scrolling_au_GPU_ligne:
	movei	#(320/4),R19
GPU_copie_scrolling_au_GPU_pixels:	
	loadb	(R10),R3
	addq	#1,R10
	shlq	#8,R3
	loadb	(R10),R0
	addq	#1,R10
	or		R0,R3
	shlq	#8,R3
	loadb	(R10),R0
	addq	#1,R10
	or		R0,R3
	shlq	#8,R3
	loadb	(R10),R0
	addq	#1,R10
	or		R0,R3
	store	R3,(R12)
	subq	#1,R19				; nb colonnes de 4 pixels
	jump	ne,(R29)
	addqt	#4,R12
; ligne suivante

	add		R22,R10					; +320

	subq	#1,R18
	jump	ne,(R28)
	nop

	.endif
	


	.if		copie_du_scrolling_au_GPU=0
; version blitter	
; re ecriture
;  


	movei		#pointeur_sur_zone_scrolling_a_modifier,R24
	movei	#offset_zone_scrolling,R13
	load		(R24),R1		; source=zone_scrolling_dessus_256c_640pixels
	;																											movei		#fonte,R1
	load	(R13),R16								; entre 0 et 319
	moveq		#0,R0
	move	R16,R17
	movei		#PIXEL8|XADDINC|PITCH1|WID320,R2
	shrq	#3,R17
	shlq	#32-3,R16			; numero pixel sur 8
	shlq	#3,R17
	shrq	#32-3,R16
	movei		#$00010000,R3
	add		R17,R1
	moveq		#1,R4
	;moveq		#8,R9

;A1_BASE	
	store		R1,(R14)
;A1_PIXEL 	= 220C
	store		R16,(R14+3)
;A1_FLAGS 	= 2204
	store		R2,(R14+1)
;A1_STEP 	= 2210	
	store		R3,(R14+4)
;A1_FSTEP	= 2214
	store		R0,(R14+5)
;A1_INC		= 221C
	store		R4,(R14+7)
;A1_FINC	= $2220
	store		R0,(R14+8)
;A1_FPIXEL	= $2218
	store		R0,(R14+6)
;B_PATD		EQU	BASE + $2268
	store		R0,(R14+$1A)
	store		R0,(R14+$1A+1)
	
	movei		#pointeur_zone_resultat_scrolling_a_modifier,R24
	movei		#PIXEL8|XADDPIX|PITCH1|WID320,R6
	load		(R24),R5		; DEST = zone_resultat_scrolling_256c

;A2_BASE	= 2224
	store		R5,(R15)
;A2_PIXEL	= 2230
	store		R0,(R15+3)
;A2_FLAGS	= 2228
	store		R6,(R15+1)

	movei		#$00180140,R7							; 24 lignes, 320 pixels
	movei		#LFU_REPLACE|SRCEN|DSTA2|UPDA1,R8
	
; B_COUNT	= 223C
	store		R7,(R15+6)
; B_CMD		= 2238
	store		R8,(R15+5)
	.endif
	
	.endif
	
	
	
	.if		CALCS_3D_ON=1
; ------------ transformation -------------
; avancer de la transformation
; >=$80 : plus de transformation
; =$C0 = changement objet
; <$80 : transformation

	movei		#GPU_saut_pas_de_transformation,R29
	movei		#GPU_transformation__changement_objet,R28

	movei		#numero_etape_en_cours_transformation,R10
	.if			nb_etapes_transformation=128
	movei		#nb_etapes_transformation+($40),R1
	.endif
	.if			nb_etapes_transformation=256
	movei		#nb_etapes_transformation+($80),R1
	.endif
	load		(R10),R0
	movei		#nb_etapes_transformation,R2
	addq		#1,R0
	cmp			R1,R0
	jump		eq,(R28)
	store		R0,(R10)
	cmp			R2,R0
	jump		hi,(R29)
	jump		eq,(R29)
	nop
; <$80
; de 0 a 127
; on ajoute la liste d'increments à points_en_cours__en_word
	movei		#increments_transformation,R20
	movei		#points_en_cours__en_word,R21
	movei		#(NBPTS*3),R19
	
GPU_boucle_increment_transformation:
	loadw		(R20),R0
	loadw		(R21),R1
	addq		#2,R20
	add			R0,R1
	storew		R1,(R21)
	subq		#1,R19
	jr			ne,GPU_boucle_increment_transformation
	addqt		#2,R21
	jump		(R29)
	nop

GPU_transformation__changement_objet:
; lire le pointeur sur le nouvel objet
	movei		#pointeur_sur_object_en_cours_dans_liste,R22
	moveq		#0,R0
	load		(R22),R23
	movei		#points_en_cours__en_word,R21
	addq		#4,R23
	store		R0,(R10)
	load		(R23),R20				; R20= points de l'objet
	cmpq		#0,R20					; dernier objet = 0
	jr			ne,GPU_transformation__changement_objet__pas_fin_des_objets
	nop
; fin des objets
	movei		#liste_suite_des_objets,R23
	load		(R23),R20				; R20= points de l'objet
GPU_transformation__changement_objet__pas_fin_des_objets:
	store		R23,(R22)
	movei		#increments_transformation,R24
	movei		#NBPTS*3,R19

GPU_transformation__changement_objet__boucle:
; dest = R24
	loadb		(R20),R1				; coordonnée nouvel objet
	loadb		(R21),R2				; coordonnée ancienne objet
	shlq		#24,R1
	shlq		#24,R2	
	sharq		#24,R1
	sharq		#24,R2
	addq		#2,R21					; 
	sub			R2,R1
	addq		#1,R20
	.if			nb_etapes_transformation=128
	add			R1,R1
	.endif
	subq		#1,R19
	storew		R1,(R24)
	jr			ne,GPU_transformation__changement_objet__boucle
	addqt		#2,R24
	


GPU_saut_pas_de_transformation:
; calculs 3D
; rotations matrice
SX		.equr			R2
CX		.equr			R3
SY		.equr			R4
CY		.equr			R5
SZ		.equr			R6
CZ		.equr			R7


; CY*CZ
; SY
; -(CY*SZ)
; (SX*SZ)-(CX*SY*CZ) 
; CX*CY
; (SX*CZ)+(CX*SY*SZ)
; (CX*SZ)+(SX*SY*CZ)
; -(SX*CY)
; (CX*CZ)-(SX*SY*SZ)

rotation_droite=15

		movei	#SINCOS,R14						; R14 = SIN
		movei	#matrice_rotations,R21
		move	R14,R15
		move	R21,R23
		movei	#$FF,R22					; limite les angles à 0-255

; rotation X
		movei	#ROTX,R10
		addq	#4,R15						; R15 = COS
		movei	#ROTY,R11
		load	(R10),R0					; rot X
		load	(R11),R1					; rot Y
		.if		rotation_en_X>0
		addq	#rotation_en_X,R0
		.endif
		.if		rotation_en_Y>0
		addq	#rotation_en_Y,R1
		.endif
		and		R22,R0
		and		R22,R1
		store	R0,(R10)
		store	R1,(R11)
		addq	#8,R10						; R10 passe à ROIZ
		shlq	#3,R0						; rot X *8
		load	(R10),R8					; R8 = rot Z
		shlq	#3,R1						; rot Y * 8
		load	(R14+R0),SX
		.if		rotation_en_Z>0
		addq	#rotation_en_Z,R8
		.endif
		load	(R15+R0),CX
		and		R22,R8
		load	(R14+R1),SY
		store	R8,(R10)
		load	(R15+R1),CY
		shlq	#3,R8						; rot Z *8
		or		R8,R8
		load	(R14+R8),SZ
		load	(R15+R8),CZ

;R10=CY*CZ
		move	CY,R10
; R11 = -(CY*SZ)
		move	SZ,R11
		imult	CZ,R10
		imult	CY,R11
		sharq	#rotation_droite,R10
		sharq	#rotation_droite,R11
		store	R10,(R21)				; CY*CZ
		NEG		R11
		addq	#4,R21
;R12 = (SX*SZ)-(CX*SY*CZ) 
		move	CX,R12
		store	SY,(R21)				; SY
		imult	SY,R12
		addq	#4,R21
		sharq	#rotation_droite,R12
		store	R11,(R21)				; -(CY*SZ)
		move	SX,R10
		addq	#4,R21
		imult	SZ,R10
		imult	CZ,R12
		sub		R12,R10
; R11=CX*CY
		move	CX,R11
		sharq	#15,R10
		imult	CY,R11
		store	R10,(R21)				; (SX*SZ)-(CX*SY*CZ) 
		sharq	#15,R11
		addq	#4,R21
; R12+R10 = (SX*CZ)+(CX*SY*SZ)
		move	CX,R12
		store	R11,(R21)				; CX*CY
		imult	SY,R12
		addq	#4,R21
		sharq	#rotation_droite,R12
		move	SX,R10
		imult	SZ,R12
		imult	CZ,R10
		move	SX,R11
		add		R12,R10
		imult	SY,R11
		sharq	#rotation_droite,R10
		move	CX,R12
		sharq	#rotation_droite,R11
		store	R10,(R21)				; (SX*CZ)+(CX*SY*SZ)
		imult	CZ,R11
		addq	#4,R21
		imult	SZ,R12
		move	SX,R10
		add		R12,R11
		imult	CY,R10
		sharq	#rotation_droite,R11
		neg		R10
		store	R11,(R21)				; (CX*SZ)+(SX*SY*CZ)
		sharq	#rotation_droite,R10
		addq	#4,R21
		move	SX,R12
		store	R10,(R21)				; -(SX*CY)
		imult	SY,R12
		addq	#4,R21
		sharq	#rotation_droite,R12
		move	CX,R11
		imult	SZ,R12
		imult	CZ,R11
			movei	#points_en_cours__en_word,R25				; source X
		sub		R12,R11
		move	R23,R15
		sharq	#rotation_droite,R11
		move	R25,R26
		store	R11,(R21)
		addq	#2,R26											; source Y
		move	R25,R27
		movei	#stock_points_2D,R28
		addq	#4,R27											; source Z
		movei	#NBPTS,R19
		movei	#GPU_boucle_projection,R29
		movei	#55,R17			; centrage X
		movei	#50,R18			; centrage Y
		
		.EQURUNDEF	SX,CX,SY,CY,SZ,CZ
; R25 = source X
; R26 = source Y
; R27 = source Z
; R15=matrice_rotations		

GPU_boucle_projection:
		loadb	(R25),R0				; X du point, partie entiere
		loadb	(R26),R1				; Y du point, partie entiere
		addq	#2*3,R25
		loadb	(R27),R2				; Z du point, partie entiere

; force les valeurs
		;movei	#$12,R0
		;movei	#$56,R1
		;movei	#$90,R2

		shlq	#24,R0
		shlq	#24,R1
		shlq	#24,R2
		sharq	#24,R0
		sharq	#24,R1
		sharq	#24,R2


		addq	#2*3,R26
		load	(R15),R3				; 	A
		addq	#2*3,R27
		load	(R15+1),R4				; 	B
		load	(R15+2),R5				; C
		
		imultn	R3,R0					; 16 bits
		imacn	R4,R1					; 17 bits
		imacn	R5,R2					; 18 bits
		resmac	R6						; R6=Y

		load	(R15+3),R3				; 	D
		load	(R15+4),R4				; 	E
		load	(R15+5),R5				; 	F
		imultn	R3,R0
		imacn	R4,R1
		imacn	R5,R2
		resmac	R7						; R7=X
		
		load	(R15+6),R3				; 	G
		load	(R15+7),R4				; 	H
		load	(R15+8),R5				; 	I
		imultn	R3,R0
		imacn	R4,R1
		imacn	R5,R2
		resmac	R8						; R8=Z

; R6/R7/R8 >> 15 = north ST

		sharq	#15,R6
		sharq	#15,R8
		movei	#$FA+$16+$80+$C0,R0			; $FA+$16+$80
		sharq	#15,R7
		add		R0,R8					; +$FA

		
		moveq	#1,R9					; R9 = signe du Z
		abs		R8					
		movei	#valeur_zoom,R10
		jr		cc,GPU_projection_Z_positif
		div		R8,R10					; 1/x
		subq	#2,R9					; R9 negatif
GPU_projection_Z_positif:		
		
		imult	R9,R10					; remet le signe
		
		imult	R10,R7					; X/Z
		imult	R10,R6					; Y/Z
		
		sharq	#15,R7
		sharq	#15,R6

; centrage
		add		R17,R7					; centrage X

		store	R7,(R28)
		add		R18,R6					; centrage Y
		addq	#4,R28
		store	R6,(R28)
		
		subq	#1,R19
		jump	ne,(R29)
		addqt	#4,R28
		
		.endif
		
		
;  modif de la zone 3D
; pointeur_zone3D_a_modifier
; GPU_blitter_draw_line : R0-R10 / R14 / R23-R24

;;; r4 - y0
;;; r3 - x0
;;; r2 - color
;;; r1 - y1
;;; r0 - x1

		.if			LIGNES3D_ON=1
	
		movei		#A1_BASE,R14
GPU_wait_blitter_copie_draxline:
	load 	(R14+$E),R0				; Command Register=$38
	btst 	#0,R0
	jr 		eq,GPU_wait_blitter_copie_draxline
	nop	
	
		;movei		#segments+(8*51),R11
		movei		#segments+(8*0),R11
		movei		#stock_points_2D,R13	
		movei		#numero_couleur_ligne_3D_256c,R16
		movei		#264,R17						; 264
		movei		#GPU_RETOUR_trace_lignes,R24
		movei		#GPU_blitter_draw_line,R23
		movei		#GPU_boucle_trace_lignes,R27
GPU_boucle_trace_lignes:
		load		(R11),R12
		move		R13,R15
		subq		#1,R12
		addq		#4,R11
		shlq		#3,R12
		move		R16,R2
		add			R12,R15
		
		load		(R15),r0
		
		load		(R15+1),R1
		load		(R11),R12
		move		R13,R15
		subq		#1,R12
		addq		#4,R11
		shlq		#3,R12
		shlq		#1,R0				; X0*2
		add			R12,R15
		shlq		#1,R1				; Y0*2
		load		(R15),r3
		
		load		(R15+1),R4
		shlq		#1,R3				; X1*2
		shlq		#1,R4				; Y1*2

		jump		(R23)
		nop

GPU_RETOUR_trace_lignes:		
		subq		#1,R17
		jump		ne,(R27)
		nop
		
		.endif


	

;----------------------------------------------
; incremente compteur de VBL au GPU
		movei	#vbl_counter_GPU,R0
		load	(R0),R1
		addq	#1,R1
		store	R1,(R0)

		;movei	#BG,R26
		;moveq	#0,R25				; bleu
		;storew	R25,(R26)

	.if		temps_GPU=1
		movei	#BORD1,R26
		movei	#couleur_de_fond_BORD1,R25				; blanc en haut
		storew	R25,(R26)
	.endif


; synchro avec l'interrupt object list
		movefa	R26,R26
		
GPU_boucle_wait_vsync:
		movefa	R26,R25
		cmp		R25,R26
		jr		eq,GPU_boucle_wait_vsync
		nop

	
; swap les pointeurs d'OL
		movei	#GPU_pointeur_object_list_a_modifier,R0
		movei	#GPU_pointeur_object_list_a_afficher,R1
		load	(R0),R2
		load	(R1),R3				; R3 = pointeur sur l'object list a modifier prochaine frame
		store	R2,(R1)
		movei	#OLP,R4
		;moveta	R3,R3
		rorq	#16,R2
		store	R3,(R0)

		store	R2,(R4)

; swap les pointeurs de zone 3D
		movei	#pointeur_zone3D_a_modifier,R0
		movei	#pointeur_zone3D_a_afficher,R1
		load	(R0),R2
		load	(R1),R3
		store	R2,(R1)
		store	R3,(R0)

; swap les pointeurs de zone scrolling
		;movei	#pointeur_sur_zone_scrolling_a_modifier,R10
		;movei	#pointeur_sur_zone_scrolling_a_afficher,R11
		;load	(R10),R12
		;load	(R11),R13
		;store	R12,(R11)
		;store	R13,(R10)
		movei	#pointeur_zone_resultat_scrolling_a_modifier,R0
		movei	#pointeur_zone_resultat_scrolling_a_afficher,R1
		load	(R0),R2
		load	(R1),R3
		store	R2,(R1)
		store	R3,(R0)



; boucle globale/centrale
		movei	#GPU_loop,R20
		;or		R20,R20
		jump	(R20)
		nop

;--------------------------------------------------------
;
; interruption object processor
;	- libere l'OP
;	- incremente R26
; utilises : R0/R22/R26/R28/R29/R30/R31
;
;--------------------------------------------------------
interrupt_OP:
		storew		R0,(r22)					; R22 = OBF

		load     (R28),r29
		addq     #1,r26							; incremente R26
		load     (R31),r30
		bclr     #3,r29
		addq     #2,r30
		addq     #4,r31
		bset     #12,r29
		jump     (r30)
		store    r29,(r28)


;;; ----------------------------------------
;;; draw
;;;
;;; Register usage: r0-r10, r14
;;;
;;; r4 - y0
;;; r3 - x0
;;; r2 - color
;;; r1 - y1
;;; r0 - x1
GPU_blitter_draw_line:


LR			.equr 	R24
dx			.equr	R10
dy			.equr	R9
m			.equr	R8
cnt			.equr 	R7
dir_x		.equr	R6
step_y		.equr 	R5
a1inc		.equr 	R4
;;; -- parameter
y0			.equr 	R4
x0			.equr 	R3
color		.equr 	R2
y1			.equr 	R1
x1			.equr 	R0

tmp2		.equr	 	R2
tmp1		.equr	 	R1
tmp0		.equr 		R0

blitter		.equr 		R14


	movei		#$f02200,blitter

	.if		1=0
.wait_blitter:
	load 	(blitter+$E),dx											; blitter status register
	btst 	#0,dx
	jr 		eq,.wait_blitter
	nop
	.endif

	
	movei		#((240<<16)|320),dy
;//->	moveq	#0,tmp0
	moveq		#0,dx
	or			dx,dx
	store		dy,(blitter+((A1_CLIP-$f02200)/4))						; _BLIT_A1_CLIP)
	store		dx,(blitter+((A1_STEP-$f02200)/4))						; _BLIT_A1_STEP)
	store		dx,(blitter+((A1_FSTEP-$f02200)/4))						; _BLIT_A1_FSTEP)



.pos1:
	move	y1,dy
	move	x1,dx
	sub		y0,dy
	sub		x0,dx
	moveq	#1,dir_x
	jr		pl,.noswap0
	moveq	#1,step_y

	move	x1,x0
	move	y1,y0
	neg		step_y
.noswap0:
	abs		dy
	jr		cc,.pos
	abs		dx
	neg		step_y
.pos:
	cmpq	#0,dy
	jr		ne,.yno0
	cmp		dy,dx
	moveq	#0,step_y
.yno0:
	move	dx,cnt
	jr		ne,.not_diag
	move	dy,m

	;; dx = dy
	moveq	#0,m
	moveq	#0,dir_x
	shlq	#16,step_y
	jr		.diagonal
	addqt	#1,step_y	; => becomes A1_INC
.not_diag:
	jr	cc,.no_swap
	shlq	#16,m

	shlq	#16,dx
	move	dy,cnt
	move	dx,m
	subq	#2,dir_x	; swap x_inc 1 => y_inc 1
.no_swap:
	div	cnt,m
.diagonal:
	shlq	#16,y0
	movei	#$80008000,tmp1			; start in the middle of the 1st pixel
	or		x0,y0


	.if		1=1
.wait_blitter:
	load 	(blitter+($38/4)),tmp0
	shrq 	#1,tmp0
	jr 		cc,.wait_blitter
	nop
	.endif

	store	color,(blitter+((B_PATD-$f02200)/4))
	movei	#PITCH1|PIXEL8|WID320|XADDINC,tmp0				; pixel1 = 1 plan / pixel8 
	store	color,(blitter+((B_PATD-$f02200+4)/4)) 			;VJ
	

	movei	#pointeur_zone3D_a_modifier,color
	store	tmp0,(blitter+((A1_FLAGS-$f02200)/4))			;(blitter+_BLIT_A1_FLAGS)
	load	(color),color
	or		color,color
	store	color,(blitter)									;_BLIT_A1_BASE

	cmpq	#0,dir_x
	store	y0,(blitter+((A1_PIXEL-$f02200)/4))				; (blitter+_BLIT_A1_PIXEL)			$220C
	jr		eq,.cont_dia
	store	tmp1,(blitter+((A1_FPIXEL-$f02200)/4))			; (blitter+_BLIT_A1_FPIXEL)			$2218
	jr		mi,.xstep
	moveq	#1,a1inc
	imult	step_y,m	; set sign
	shlq	#16,step_y	; test sign
	jr		pl,.cont
	shlq	#16,m

	jr		.cont
	or		step_y,a1inc
.xstep:
	shlq	#16,step_y
.cont_dia:
	move	step_y,a1inc
.cont:
	bset	#16,cnt
	store	a1inc,(blitter+((A1_INC-$f02200)/4))		; (blitter+_BLIT_A1_INC)			$221C
	addq	#1,cnt
	store	m,(blitter+((A1_FINC-$f02200)/4))			; (blitter+_BLIT_A1_FINC)			$2220
	movei	#UPDA1|DSTEN|SRCEN|PATDSEL,tmp1
	store	cnt,(blitter+((B_COUNT-$f02200)/4))			; (blitter+_BLIT_COUNT)
	store	tmp1,(blitter+($38/4))			; (blitter+_BLIT_CMD)
	jump	(LR)
	nop

		
	.phrase

GPU_premiere_ligne:				dc.l		0				; lus 2 fois
GPU_derniere_ligne:				dc.l		0
vbl_counter_GPU:								dc.l		0
GPU_pointeur_object_list_a_modifier:			dc.l			ob_list_1
GPU_pointeur_object_list_a_afficher:			dc.l			ob_list_2
pointeur_zone3D_a_modifier:						dc.l			zone3D_1
pointeur_zone3D_a_afficher:						dc.l			zone3D_2
; scrolling

pointeur_sur_zone_scrolling_a_modifier:			dc.l			zone_scrolling_dessus_256c_640pixels__zone1
pointeur_sur_zone_scrolling_a_afficher:			dc.l			zone_scrolling_dessus_256c_640pixels__zone2

pointeur_zone_resultat_scrolling_a_modifier:	dc.l		zone_resultat_scrolling_256c_zone1
pointeur_zone_resultat_scrolling_a_afficher:	dc.l		zone_resultat_scrolling_256c_zone2


scrolling__pointeur_actuel_texte_scrolling:				dc.l			texte_scrolling_traduit
scrolling__pixel_actuel_dans_lettre:					dc.l			0
scrolling_pointeur_actuel_sur_lettre:				dc.l		fonte+(320*24*3)+(16*16)				; espace
offset_zone_scrolling:			dc.l			0




; transformation
numero_etape_en_cours_transformation:	
		.if			nb_etapes_transformation=128
		dc.l		$C0-1			; L2D874 / $80+$40-1
		.endif
		.if			nb_etapes_transformation=256
		dc.l		$180-1			; L2D874 / $100+$80-1
		.endif

;
; ANGLES DE ROTATION, ETC...
;
ROTX:			dc.L	$20+inc_pos_initiale_X
ROTY:			dc.l	$20+inc_pos_initiale_Y
ROTZ:			dc.l	$20+inc_pos_initiale_Z

matrice_rotations:
				dc.l	0,0,0
				dc.l	0,0,0
				dc.l	0,0,0

;---------------------
; FIN DE LA RAM GPU
GPU_fin:
;---------------------	

GPU_DRIVER_SIZE			.equ			GPU_fin-GPU_base_memoire
	.print	"---------------------------------------------------------------"
	.print	"--- GPU code size : ", /u GPU_DRIVER_SIZE, " bytes / 4096 ---"
	.if GPU_DRIVER_SIZE > 4088
		.print		""
		.print		""
		.print		""
		.print	"---------------------------------------------------------------"
		.print	"          GPU code too large !!!!!!!!!!!!!!!!!! "
		.print	"---------------------------------------------------------------"
		.print		""
		.print		""
		.print		""
		
	.endif



	.68000
	.dphrase
	.text

	.phrase
	.include	"Paula_v15_include.s"

	.phrase
Paula_custom:
channela:	; $dff0a0
; total = 4+2+2+8 = 16
		dc.l	silence			; adresse debut sample .L									00
		dc.w	0				; taille en words du sample .W								04
		dc.w	0				; period/note du canal										06
		ds.b	8				; volume .W + complement / Custom chip canal 0				08
channelb:
		dc.l	silence			;															16
		dc.w	0
		dc.w	0
		ds.b	8		; Custom chip canal 0
channelc:
		dc.l	silence
		dc.w	0
		dc.w	0
		ds.b	8		; Custom chip canal 0
channeld:
		dc.l	silence
		dc.w	0
		dc.w	0
		ds.b	8		; Custom chip canal 0
		
bEndMusicTrigger:	dc.b	0
	.phrase



;        .68000
;		.dphrase
;ob_liste_originale:           				 ; This is the label you will use to address this in 68K code
;        .objproc 							   ; Engage the OP assembler;
		;.dphrase

;        .org    ob_list_courante			 ; Tell the OP assembler where the list will execute
;
;        branch      VC < 0, .stahp    			 ; Branch to the STOP object if VC < 0
;        branch      VC > 241, .stahp   			 ; Branch to the STOP object if VC > 241
;			; bitmap data addr, xloc, yloc, dwidth, iwidth, iheight, bpp, pallete idx, flags, firstpix, pitch
;		bitmap		logo_DUNE,16+46,26+20,80,80,90,4
;        bitmap      ecran1, 16, 26+90, nb_octets_par_ligne/8, nb_octets_par_ligne/8, 246-(26+90),1
;        jump        .haha
;.stahp:
;        stop
;.haha:
;        jump        .stahp
;		
;		.68000
;		.dphrase
;fin_ob_liste_originale:


	.phrase
pointeur_sur_object_en_cours_dans_liste:
		DC.L			FSTOBJ
liste_suite_des_objets:					; L2D87A
	DC.L	OBJ6
	DC.L	OBJ4
	DC.L	OBJ2
	DC.L	OBJ1
	DC.L	OBJ4
	DC.L	OBJ3
	DC.L	OBJ5
	DC.L	OBJ4
FSTOBJ:
	DC.L	OBJ1
	DC.L	0
	
	.phrase
SINCOS:		;TABLE DE SINUS/COSINUS
	dc.l	$0,$7FFF,$324,$7FF5,$647,$7FD7,$96A,$7FA6
	dc.l	$C8B,$7F61,$FAB,$7F08,$12C7,$7E9C,$15E1,$7E1C
	dc.l	$18F8,$7D89,$1C0B,$7CE2,$1F19,$7C29,$2223,$7B5C
	dc.l	$2527,$7A7C,$2826,$7989,$2B1E,$7883,$2E10,$776B
	dc.l	$30FB,$7640,$33DE,$7503,$36B9,$73B5,$398C,$7254
	dc.l	$3C56,$70E1,$3F16,$6F5E,$41CD,$6DC9,$447A,$6C23
	dc.l	$471C,$6A6C,$49B3,$68A5,$4C3F,$66CE,$4EBF,$64E7
	dc.l	$5133,$62F1,$539A,$60EB,$55F4,$5ED6,$5842,$5CB3
	dc.l	$5A81,$5A81,$5CB3,$5842,$5ED6,$55F4,$60EB,$539A
	dc.l	$62F1,$5133,$64E7,$4EBF,$66CE,$4C3F,$68A5,$49B3
	dc.l	$6A6C,$471C,$6C23,$447A,$6DC9,$41CD,$6F5E,$3F16
	dc.l	$70E1,$3C56,$7254,$398C,$73B5,$36B9,$7503,$33DE
	dc.l	$7640,$30FB,$776B,$2E10,$7883,$2B1E,$7989,$2826
	dc.l	$7A7C,$2527,$7B5C,$2223,$7C29,$1F19,$7CE2,$1C0B
	dc.l	$7D89,$18F8,$7E1C,$15E1,$7E9C,$12C7,$7F08,$FAB
	dc.l	$7F61,$C8B,$7FA6,$96A,$7FD7,$647,$7FF5,$324
	dc.l	$7FFF,$0,$7FF5,$FCDB,$7FD7,$F9B8,$7FA6,$F695
	dc.l	$7F61,$F374,$7F08,$F054,$7E9C,$ED38,$7E1C,$EA1E
	dc.l	$7D89,$E707,$7CE2,$E3F4,$7C29,$E0E6,$7B5C,$DDDC
	dc.l	$7A7C,$DAD8,$7989,$D7D9,$7883,$D4E1,$776B,$D1EF
	dc.l	$7640,$CF04,$7503,$CC21,$73B5,$C946,$7254,$C673
	dc.l	$70E1,$C3A9,$6F5E,$C0E9,$6DC9,$BE32,$6C23,$BB85
	dc.l	$6A6C,$B8E3,$68A5,$B64C,$66CE,$B3C0,$64E7,$B140
	dc.l	$62F1,$AECC,$60EB,$AC65,$5ED6,$AA0B,$5CB3,$A7BD
	dc.l	$5A81,$A57E,$5842,$A34C,$55F4,$A129,$539A,$9F14
	dc.l	$5133,$9D0E,$4EBF,$9B18,$4C3F,$9931,$49B3,$975A
	dc.l	$471C,$9593,$447A,$93DC,$41CD,$9236,$3F16,$90A1
	dc.l	$3C56,$8F1E,$398C,$8DAB,$36B9,$8C4A,$33DE,$8AFC
	dc.l	$30FB,$89BF,$2E10,$8894,$2B1E,$877C,$2826,$8676
	dc.l	$2527,$8583,$2223,$84A3,$1F19,$83D6,$1C0B,$831D
	dc.l	$18F8,$8276,$15E1,$81E3,$12C7,$8163,$FAB,$80F7
	dc.l	$C8B,$809E,$96A,$8059,$647,$8028,$324,$800A
	dc.l	$0,$8001,$FCDB,$800A,$F9B8,$8028,$F695,$8059
	dc.l	$F374,$809E,$F054,$80F7,$ED38,$8163,$EA1E,$81E3
	dc.l	$E707,$8276,$E3F4,$831D,$E0E6,$83D6,$DDDC,$84A3
	dc.l	$DAD8,$8583,$D7D9,$8676,$D4E1,$877C,$D1EF,$8894
	dc.l	$CF04,$89BF,$CC21,$8AFC,$C946,$8C4A,$C673,$8DAB
	dc.l	$C3A9,$8F1E,$C0E9,$90A1,$BE32,$9236,$BB85,$93DC
	dc.l	$B8E3,$9593,$B64C,$975A,$B3C0,$9931,$B140,$9B18
	dc.l	$AECC,$9D0E,$AC65,$9F14,$AA0B,$A129,$A7BD,$A34C
	dc.l	$A57E,$A57E,$A34C,$A7BD,$A129,$AA0B,$9F14,$AC65
	dc.l	$9D0E,$AECC,$9B18,$B140,$9931,$B3C0,$975A,$B64C
	dc.l	$9593,$B8E3,$93DC,$BB85,$9236,$BE32,$90A1,$C0E9
	dc.l	$8F1E,$C3A9,$8DAB,$C673,$8C4A,$C946,$8AFC,$CC21
	dc.l	$89BF,$CF04,$8894,$D1EF,$877C,$D4E1,$8676,$D7D9
	dc.l	$8583,$DAD8,$84A3,$DDDC,$83D6,$E0E6,$831D,$E3F4
	dc.l	$8276,$E707,$81E3,$EA1E,$8163,$ED38,$80F7,$F054
	dc.l	$809E,$F374,$8059,$F695,$8028,$F9B8,$800A,$FCDB
	dc.l	$8001,$FFFF,$800A,$324,$8028,$647,$8059,$96A
	dc.l	$809E,$C8B,$80F7,$FAB,$8163,$12C7,$81E3,$15E1
	dc.l	$8276,$18F8,$831D,$1C0B,$83D6,$1F19,$84A3,$2223
	dc.l	$8583,$2527,$8676,$2826,$877C,$2B1E,$8894,$2E10
	dc.l	$89BF,$30FB,$8AFC,$33DE,$8C4A,$36B9,$8DAB,$398C
	dc.l	$8F1E,$3C56,$90A1,$3F16,$9236,$41CD,$93DC,$447A
	dc.l	$9593,$471C,$975A,$49B3,$9931,$4C3F,$9B18,$4EBF
	dc.l	$9D0E,$5133,$9F14,$539A,$A129,$55F4,$A34C,$5842
	dc.l	$A57E,$5A81,$A7BD,$5CB3,$AA0B,$5ED6,$AC65,$60EB
	dc.l	$AECC,$62F1,$B140,$64E7,$B3C0,$66CE,$B64C,$68A5
	dc.l	$B8E3,$6A6C,$BB85,$6C23,$BE32,$6DC9,$C0E9,$6F5E
	dc.l	$C3A9,$70E1,$C673,$7254,$C946,$73B5,$CC21,$7503
	dc.l	$CF04,$7640,$D1EF,$776B,$D4E1,$7883,$D7D9,$7989
	dc.l	$DAD8,$7A7C,$DDDC,$7B5C,$E0E6,$7C29,$E3F4,$7CE2
	dc.l	$E707,$7D89,$EA1E,$7E1C,$ED38,$7E9C,$F054,$7F08
	dc.l	$F374,$7F61,$F695,$7FA6,$F9B8,$7FD7,$FCDB,$7FF5


		.phrase
; LISTE DE TOUS LES POINTS (X,Y,Z) -EN 7 BITS SIGNES-
; 432 octets => 144 points
OBJ1:
	DC.B	6,$A3,$EA,$10,$A3,$F0,$16,$A3
	DC.B	$FA,$16,$A3,6,$10,$A3,$10,6
	DC.B	$A3,$16,$FA,$A3,$16,$F0,$A3,$10
	DC.B	$EA,$A3,6,$EA,$A3,$FA,$F0,$A3
	DC.B	$F0,$FA,$A3,$EA,$C,$AB,$D5,$20
	DC.B	$AB,$E0,$2B,$AB,$F4,$2B,$AB,$C
	DC.B	$20,$AB,$20,$C,$AB,$2B,$F4,$AB
	DC.B	$2B,$E0,$AB,$20,$D5,$AB,$C,$D5
	DC.B	$AB,$F4,$E0,$AB,$E0,$F4,$AB,$D5
	DC.B	$11,$B8,$C2,$2D,$B8,$D3,$3E,$B8
	DC.B	$EF,$3E,$B8,$11,$2D,$B8,$2D,$11
	DC.B	$B8,$3E,$EF,$B8,$3E,$D3,$B8,$2D
	DC.B	$C2,$B8,$11,$C2,$B8,$EF,$D3,$B8
	DC.B	$D3,$EF,$B8,$C2,$14,$C9,$B4,$38
	DC.B	$C9,$C8,$4C,$C9,$EC,$4C,$C9,$14
	DC.B	$38,$C9,$38,$14,$C9,$4C,$EC,$C9
	DC.B	$4C,$C8,$C9,$38,$B4,$C9,$14,$B4
	DC.B	$C9,$EC,$C8,$C9,$C8,$EC,$C9,$B4
	DC.B	$17,$DC,$A9,$40,$DC,$C0,$57,$DC
	DC.B	$E9,$57,$DC,$17,$40,$DC,$40,$17
	DC.B	$DC,$57,$E9,$DC,$57,$C0,$DC,$40
	DC.B	$A9,$DC,$17,$A9,$DC,$E9,$C0,$DC				; point 56/57
	DC.B	$C0,$E9,$DC,$A9,$19,$F3,$A4,$43
	DC.B	$F3,$BD,$5C,$F3,$E7,$5C,$F3,$19
	DC.B	$43,$F3,$43,$19,$F3,$5C,$E7,$F3
	DC.B	$5C,$BD,$F3,$43,$A4,$F3,$19,$A4
	DC.B	$F3,$E7,$BD,$F3,$BD,$E7,$F3,$A4
	DC.B	$19,$D,$A4,$43,$D,$BD,$5C,$D
	DC.B	$E7,$5C,$D,$19,$43,$D,$43,$19
	DC.B	$D,$5C,$E7,$D,$5C,$BD,$D,$43
	DC.B	$A4,$D,$19,$A4,$D,$E7,$BD,$D
	DC.B	$BD,$E7,$D,$A4,$17,$24,$A9,$40
	DC.B	$24,$C0,$57,$24,$E9,$57,$24,$17
	DC.B	$40,$24,$40,$17,$24,$57,$E9,$24
	DC.B	$57,$C0,$24,$40,$A9,$24,$17,$A9
	DC.B	$24,$E9,$C0,$24,$C0,$E9,$24,$A9
	DC.B	$14,$37,$B4,$38,$37,$C8,$4C,$37
	DC.B	$EC,$4C,$37,$14,$38,$37,$38,$14
	DC.B	$37,$4C,$EC,$37,$4C,$C8,$37,$38
	DC.B	$B4,$37,$14,$B4,$37,$EC,$C8,$37
	DC.B	$C8,$EC,$37,$B4,$11,$48,$C2,$2D
	DC.B	$48,$D3,$3E,$48,$EF,$3E,$48,$11
	DC.B	$2D,$48,$2D,$11,$48,$3E,$EF,$48
	DC.B	$3E,$D3,$48,$2D,$C2,$48,$11,$C2
	DC.B	$48,$EF,$D3,$48,$D3,$EF,$48,$C2
	DC.B	$C,$55,$D5,$20,$55,$E0,$2B,$55
	DC.B	$F4,$2B,$55,$C,$20,$55,$20,$C
	DC.B	$55,$2B,$F4,$55,$2B,$E0,$55,$20
	DC.B	$D5,$55,$C,$D5,$55,$F4,$E0,$55
	DC.B	$E0,$F4,$55,$D5,6,$5D,$EA,$10
	DC.B	$5D,$F0,$16,$5D,$FA,$16,$5D,6
	DC.B	$10,$5D,$10,6,$5D,$16,$FA,$5D
	DC.B	$16,$F0,$5D,$10,$EA,$5D,6,$EA
	DC.B	$5D,$FA,$F0,$5D,$F0,$FA,$5D,$EA
OBJ2:
	DC.B	$A8,$A3,0,$B8,$A3,0,$C8,$A3
	DC.B	0,$D8,$A3,0,$E8,$A3,0,$F8
	DC.B	$A3,0,8,$A3,0,$18,$A3,0
	DC.B	$28,$A3,0,$38,$A3,0,$48,$A3
	DC.B	0,$58,$A3,0,$A8,$AB,0,$B8
	DC.B	$AB,$F,$C8,$AB,$F,$D8,$AB,$F
	DC.B	$E8,$AB,$F,$F8,$AB,$F,8,$AB
	DC.B	$F,$18,$AB,$F,$28,$AB,$F,$38
	DC.B	$AB,$F,$48,$AB,$F,$58,$AB,0
	DC.B	$A8,$B8,0,$B8,$B8,$F,$C8,$B8
	DC.B	$1E,$D8,$B8,$1E,$E8,$B8,$1E,$F8
	DC.B	$B8,$1E,8,$B8,$1E,$18,$B8,$1E
	DC.B	$28,$B8,$1E,$38,$B8,$1E,$48,$B8
	DC.B	$F,$58,$B8,0,$A8,$C9,0,$B8
	DC.B	$C9,$F,$C8,$C9,$1E,$D8,$C9,$2D
	DC.B	$E8,$C9,$2D,$F8,$C9,$2D,8,$C9
	DC.B	$2D,$18,$C9,$2D,$28,$C9,$2D,$38
	DC.B	$C9,$1E,$48,$C9,$F,$58,$C9,0
	DC.B	$A8,$DC,0,$B8,$DC,$F,$C8,$DC
	DC.B	$1E,$D8,$DC,$2D,$E8,$DC,$3C,$F8
	DC.B	$DC,$3C,8,$DC,$3C,$18,$DC,$3C
	DC.B	$28,$DC,$2D,$38,$DC,$1E,$48,$DC
	DC.B	$F,$58,$DC,0,$A8,$F3,0,$B8
	DC.B	$F3,$F,$C8,$F3,$1E,$D8,$F3,$2D
	DC.B	$E8,$F3,$3C,$F8,$F3,$4B,8,$F3
	DC.B	$4B,$18,$F3,$3C,$28,$F3,$2D,$38
	DC.B	$F3,$1E,$48,$F3,$F,$58,$F3,0
	DC.B	$A8,$D,0,$B8,$D,$F,$C8,$D
	DC.B	$1E,$D8,$D,$2D,$E8,$D,$3C,$F8
	DC.B	$D,$4B,8,$D,$4B,$18,$D,$3C
	DC.B	$28,$D,$2D,$38,$D,$1E,$48,$D
	DC.B	$F,$58,$D,0,$A8,$24,0,$B8
	DC.B	$24,$F,$C8,$24,$1E,$D8,$24,$2D
	DC.B	$E8,$24,$3C,$F8,$24,$3C,8,$24
	DC.B	$3C,$18,$24,$3C,$28,$24,$2D,$38
	DC.B	$24,$1E,$48,$24,$F,$58,$24,0
	DC.B	$A8,$37,0,$B8,$37,$F,$C8,$37
	DC.B	$1E,$D8,$37,$2D,$E8,$37,$2D,$F8
	DC.B	$37,$2D,8,$37,$2D,$18,$37,$2D
	DC.B	$28,$37,$2D,$38,$37,$1E,$48,$37
	DC.B	$F,$58,$37,0,$A8,$48,0,$B8
	DC.B	$48,$F,$C8,$48,$1E,$D8,$48,$1E
	DC.B	$E8,$48,$1E,$F8,$48,$1E,8,$48
	DC.B	$1E,$18,$48,$1E,$28,$48,$1E,$38
	DC.B	$48,$1E,$48,$48,$F,$58,$48,0
	DC.B	$A8,$55,0,$B8,$55,$F,$C8,$55
	DC.B	$F,$D8,$55,$F,$E8,$55,$F,$F8
	DC.B	$55,$F,8,$55,$F,$18,$55,$F
	DC.B	$28,$55,$F,$38,$55,$F,$48,$55
	DC.B	$F,$58,$55,0,$A8,$5D,0,$B8
	DC.B	$5D,0,$C8,$5D,0,$D8,$5D,0
	DC.B	$E8,$5D,0,$F8,$5D,0,8,$5D
	DC.B	0,$18,$5D,0,$28,$5D,0,$38
	DC.B	$5D,0,$48,$5D,0,$58,$5D,0
OBJ3:
	DC.B	$A8,$40,0,$B8,$3B,0,$C8,$36
	DC.B	0,$D8,$31,0,$E8,$2C,0,$F8
	DC.B	$27,0,8,$22,0,$18,$1D,0
	DC.B	$28,$18,0,$38,$13,0,$48,$E
	DC.B	0,$58,9,0,$A8,$37,$E0,$B8
	DC.B	$33,$E2,$C8,$2F,$E5,$D8,$2A,$E8
	DC.B	$E8,$26,$EA,$F8,$22,$EC,8,$1D
	DC.B	$EF,$18,$19,$F1,$28,$15,$F4,$38
	DC.B	$10,$F6,$48,$C,$F9,$58,7,$FC
	DC.B	$A8,$20,$C9,$B8,$1E,$CD,$C8,$1B
	DC.B	$D1,$D8,$18,$D6,$E8,$16,$DA,$F8
	DC.B	$14,$DE,8,$11,$E3,$18,$F,$E7
	DC.B	$28,$C,$EB,$38,$A,$F0,$48,7
	DC.B	$F4,$58,4,$F9,$A8,0,$C0,$B8
	DC.B	0,$C5,$C8,0,$CA,$D8,0,$CF
	DC.B	$E8,0,$D4,$F8,0,$D9,8,0
	DC.B	$DE,$18,0,$E3,$28,0,$E8,$38
	DC.B	0,$ED,$48,0,$F2,$58,0,$F7
	DC.B	$A8,$E0,$C9,$B8,$E2,$CD,$C8,$E5
	DC.B	$D1,$D8,$E8,$D6,$E8,$EA,$DA,$F8
	DC.B	$EC,$DE,8,$EF,$E3,$18,$F1,$E7
	DC.B	$28,$F4,$EB,$38,$F6,$F0,$48,$F9
	DC.B	$F4,$58,$FC,$F9,$A8,$C9,$E0,$B8
	DC.B	$CD,$E2,$C8,$D1,$E5,$D8,$D6,$E8
	DC.B	$E8,$DA,$EA,$F8,$DE,$EC,8,$E3
	DC.B	$EF,$18,$E7,$F1,$28,$EB,$F4,$38
	DC.B	$F0,$F6,$48,$F4,$F9,$58,$F9,$FC
	DC.B	$A8,$C0,0,$B8,$C5,0,$C8,$CA
	DC.B	0,$D8,$CF,0,$E8,$D4,0,$F8
	DC.B	$D9,0,8,$DE,0,$18,$E3,0
	DC.B	$28,$E8,0,$38,$ED,0,$48,$F2
	DC.B	0,$58,$F7,0,$A8,$C9,$20,$B8
	DC.B	$CD,$1E,$C8,$D1,$1B,$D8,$D6,$18
	DC.B	$E8,$DA,$16,$F8,$DE,$14,8,$E3
	DC.B	$11,$18,$E7,$F,$28,$EB,$C,$38
	DC.B	$F0,$A,$48,$F4,7,$58,$F9,4
	DC.B	$A8,$E0,$37,$B8,$E2,$33,$C8,$E5
	DC.B	$2F,$D8,$E8,$2A,$E8,$EA,$26,$F8
	DC.B	$EC,$22,8,$EF,$1D,$18,$F1,$19
	DC.B	$28,$F4,$15,$38,$F6,$10,$48,$F9
	DC.B	$C,$58,$FC,7,$A8,0,$40,$B8
	DC.B	0,$3B,$C8,0,$36,$D8,0,$31
	DC.B	$E8,0,$2C,$F8,0,$27,8,0
	DC.B	$22,$18,0,$1D,$28,0,$18,$38
	DC.B	0,$13,$48,0,$E,$58,0,9
	DC.B	$A8,$20,$37,$B8,$1E,$33,$C8,$1B
	DC.B	$2F,$D8,$18,$2A,$E8,$16,$26,$F8
	DC.B	$14,$22,8,$11,$1D,$18,$F,$19
	DC.B	$28,$C,$15,$38,$A,$10,$48,7
	DC.B	$C,$58,4,7,$A8,$37,$20,$B8
	DC.B	$33,$1E,$C8,$2F,$1B,$D8,$2A,$18
	DC.B	$E8,$26,$16,$F8,$22,$14,8,$1D
	DC.B	$11,$18,$19,$F,$28,$15,$C,$38
	DC.B	$10,$A,$48,$C,7,$58,7,4
OBJ4:
	DC.B	$A8,$40,0,$B8,$40,0,$C8,$40
	DC.B	0,$D8,$40,0,$E8,$40,0,$F8
	DC.B	$40,0,8,$40,0,$18,$40,0
	DC.B	$28,$40,0,$38,$40,0,$48,$40
	DC.B	0,$58,$40,0,$A8,$37,$E0,$B8
	DC.B	$37,$E0,$C8,$37,$E0,$D8,$37,$E0
	DC.B	$E8,$37,$E0,$F8,$37,$E0,8,$37
	DC.B	$E0,$18,$37,$E0,$28,$37,$E0,$38
	DC.B	$37,$E0,$48,$37,$E0,$58,$37,$E0
	DC.B	$A8,$20,$C9,$B8,$20,$C9,$C8,$20
	DC.B	$C9,$D8,$20,$C9,$E8,$20,$C9,$F8
	DC.B	$20,$C9,8,$20,$C9,$18,$20,$C9
	DC.B	$28,$20,$C9,$38,$20,$C9,$48,$20
	DC.B	$C9,$58,$20,$C9,$A8,0,$C0,$B8
	DC.B	0,$C0,$C8,0,$C0,$D8,0,$C0
	DC.B	$E8,0,$C0,$F8,0,$C0,8,0
	DC.B	$C0,$18,0,$C0,$28,0,$C0,$38
	DC.B	0,$C0,$48,0,$C0,$58,0,$C0
	DC.B	$A8,$E0,$C9,$B8,$E0,$C9,$C8,$E0
	DC.B	$C9,$D8,$E0,$C9,$E8,$E0,$C9,$F8
	DC.B	$E0,$C9,8,$E0,$C9,$18,$E0,$C9
	DC.B	$28,$E0,$C9,$38,$E0,$C9,$48,$E0
	DC.B	$C9,$58,$E0,$C9,$A8,$C9,$E0,$B8
	DC.B	$C9,$E0,$C8,$C9,$E0,$D8,$C9,$E0
	DC.B	$E8,$C9,$E0,$F8,$C9,$E0,8,$C9
	DC.B	$E0,$18,$C9,$E0,$28,$C9,$E0,$38
	DC.B	$C9,$E0,$48,$C9,$E0,$58,$C9,$E0
	DC.B	$A8,$C0,0,$B8,$C0,0,$C8,$C0
	DC.B	0,$D8,$C0,0,$E8,$C0,0,$F8
	DC.B	$C0,0,8,$C0,0,$18,$C0,0
	DC.B	$28,$C0,0,$38,$C0,0,$48,$C0
	DC.B	0,$58,$C0,0,$A8,$C9,$20,$B8
	DC.B	$C9,$20,$C8,$C9,$20,$D8,$C9,$20
	DC.B	$E8,$C9,$20,$F8,$C9,$20,8,$C9
	DC.B	$20,$18,$C9,$20,$28,$C9,$20,$38
	DC.B	$C9,$20,$48,$C9,$20,$58,$C9,$20
	DC.B	$A8,$E0,$37,$B8,$E0,$37,$C8,$E0
	DC.B	$37,$D8,$E0,$37,$E8,$E0,$37,$F8
	DC.B	$E0,$37,8,$E0,$37,$18,$E0,$37
	DC.B	$28,$E0,$37,$38,$E0,$37,$48,$E0
	DC.B	$37,$58,$E0,$37,$A8,0,$40,$B8
	DC.B	0,$40,$C8,0,$40,$D8,0,$40
	DC.B	$E8,0,$40,$F8,0,$40,8,0
	DC.B	$40,$18,0,$40,$28,0,$40,$38
	DC.B	0,$40,$48,0,$40,$58,0,$40
	DC.B	$A8,$20,$37,$B8,$20,$37,$C8,$20
	DC.B	$37,$D8,$20,$37,$E8,$20,$37,$F8
	DC.B	$20,$37,8,$20,$37,$18,$20,$37
	DC.B	$28,$20,$37,$38,$20,$37,$48,$20
	DC.B	$37,$58,$20,$37,$A8,$37,$20,$B8
	DC.B	$37,$20,$C8,$37,$20,$D8,$37,$20
	DC.B	$E8,$37,$20,$F8,$37,$20,8,$37
	DC.B	$20,$18,$37,$20,$28,$37,$20,$38
	DC.B	$37,$20,$48,$37,$20,$58,$37,$20
OBJ5:
	DC.B	$A8,$A8,0,$B8,$A8,0,$C8,$A8
	DC.B	0,$D8,$A8,0,$E8,$A8,0,$F8
	DC.B	$A8,0,8,$A8,0,$18,$A8,0
	DC.B	$28,$A8,0,$38,$A8,0,$48,$A8
	DC.B	0,$58,$A8,0,$A8,$B8,0,$B8
	DC.B	$B8,0,$C8,$B8,0,$D8,$B8,0
	DC.B	$E8,$B8,0,$F8,$B8,0,8,$B8
	DC.B	0,$18,$B8,0,$28,$B8,0,$38
	DC.B	$B8,0,$48,$B8,0,$58,$B8,0
	DC.B	$A8,$C8,0,$B8,$C8,0,$C8,$C8
	DC.B	0,$D8,$C8,0,$E8,$C8,0,$F8
	DC.B	$C8,0,8,$C8,0,$18,$C8,0
	DC.B	$28,$C8,0,$38,$C8,0,$48,$C8
	DC.B	0,$58,$C8,0,$A8,$D8,0,$B8
	DC.B	$D8,0,$C8,$D8,0,$D8,$D8,0
	DC.B	$E8,$D8,0,$F8,$D8,0,8,$D8
	DC.B	0,$18,$D8,0,$28,$D8,0,$38
	DC.B	$D8,0,$48,$D8,0,$58,$D8,0
	DC.B	$A8,$E8,0,$B8,$E8,0,$C8,$E8
	DC.B	0,$D8,$E8,0,$E8,$E8,0,$F8
	DC.B	$E8,0,8,$E8,0,$18,$E8,0
	DC.B	$28,$E8,0,$38,$E8,0,$48,$E8
	DC.B	0,$58,$E8,0,$A8,$F8,0,$B8
	DC.B	$F8,0,$C8,$F8,0,$D8,$F8,0
	DC.B	$E8,$F8,0,$F8,$F8,0,8,$F8
	DC.B	0,$18,$F8,0,$28,$F8,0,$38
	DC.B	$F8,0,$48,$F8,0,$58,$F8,0
	DC.B	$A8,8,0,$B8,8,0,$C8,8
	DC.B	0,$D8,8,0,$E8,8,0,$F8
	DC.B	8,0,8,8,0,$18,8,0
	DC.B	$28,8,0,$38,8,0,$48,8
	DC.B	0,$58,8,0,$A8,$18,0,$B8
	DC.B	$18,0,$C8,$18,0,$D8,$18,0
	DC.B	$E8,$18,0,$F8,$18,0,8,$18
	DC.B	0,$18,$18,0,$28,$18,0,$38
	DC.B	$18,0,$48,$18,0,$58,$18,0
	DC.B	$A8,$28,0,$B8,$28,0,$C8,$28
	DC.B	0,$D8,$28,0,$E8,$28,0,$F8
	DC.B	$28,0,8,$28,0,$18,$28,0
	DC.B	$28,$28,0,$38,$28,0,$48,$28
	DC.B	0,$58,$28,0,$A8,$38,0,$B8
	DC.B	$38,0,$C8,$38,0,$D8,$38,0
	DC.B	$E8,$38,0,$F8,$38,0,8,$38
	DC.B	0,$18,$38,0,$28,$38,0,$38
	DC.B	$38,0,$48,$38,0,$58,$38,0
	DC.B	$A8,$48,0,$B8,$48,0,$C8,$48
	DC.B	0,$D8,$48,0,$E8,$48,0,$F8
	DC.B	$48,0,8,$48,0,$18,$48,0
	DC.B	$28,$48,0,$38,$48,0,$48,$48
	DC.B	0,$58,$48,0,$A8,$58,0,$B8
	DC.B	$58,0,$C8,$58,0,$D8,$58,0
	DC.B	$E8,$58,0,$F8,$58,0,8,$58
	DC.B	0,$18,$58,0,$28,$58,0,$38
	DC.B	$58,0,$48,$58,0,$58,$58,0
OBJ6:
	DC.B	$C1,$C1,0,$CA,$B9,0,$D3,$B2
	DC.B	0,$DF,$AE,0,$EC,$AA,0,$F8
	DC.B	$A8,0,8,$A8,0,$14,$AA,0
	DC.B	$21,$AE,0,$2D,$B2,0,$36,$B9
	DC.B	0,$3F,$C1,0,$B9,$CA,0,$CC
	DC.B	$CC,0,$D4,$C2,0,$DF,$BE,0
	DC.B	$EC,$BA,0,$F8,$B8,0,8,$B8
	DC.B	0,$14,$BA,0,$21,$BE,0,$2C
	DC.B	$C2,0,$34,$CC,0,$47,$CA,0
	DC.B	$B2,$D3,0,$C2,$D4,0,$D3,$D3
	DC.B	0,$DE,$CF,0,$EC,$CB,0,$F8
	DC.B	$C8,0,8,$C8,0,$14,$CB,0
	DC.B	$22,$CF,0,$2D,$D3,0,$3E,$D4
	DC.B	0,$4E,$D3,0,$AE,$DF,0,$BE
	DC.B	$DF,0,$CF,$DE,0,$DF,$DF,0
	DC.B	$EC,$DB,0,$F8,$D8,0,8,$D8
	DC.B	0,$14,$DB,0,$21,$DF,0,$31
	DC.B	$DE,0,$42,$DF,0,$52,$DF,0
	DC.B	$AA,$EC,0,$BA,$EC,0,$CB,$EC
	DC.B	0,$DB,$EC,0,$EA,$EA,0,$F8
	DC.B	$E8,0,8,$E8,0,$16,$EA,0
	DC.B	$25,$EC,0,$35,$EC,0,$46,$EC
	DC.B	0,$56,$EC,0,$A8,$F8,0,$B8
	DC.B	$F8,0,$C8,$F8,0,$D8,$F8,0
	DC.B	$E8,$F8,0,$F8,$F8,0,8,$F8
	DC.B	0,$18,$F8,0,$28,$F8,0,$38
	DC.B	$F8,0,$48,$F8,0,$58,$F8,0
	DC.B	$A8,8,0,$B8,8,0,$C8,8
	DC.B	0,$D8,8,0,$E8,8,0,$F8
	DC.B	8,0,8,8,0,$18,8,0
	DC.B	$28,8,0,$38,8,0,$48,8
	DC.B	0,$58,8,0,$AA,$14,0,$BA
	DC.B	$14,0,$CB,$14,0,$DB,$14,0
	DC.B	$EA,$16,0,$F8,$18,0,8,$18
	DC.B	0,$16,$16,0,$25,$14,0,$35
	DC.B	$14,0,$46,$14,0,$56,$14,0
	DC.B	$AE,$21,0,$BE,$21,0,$CF,$22
	DC.B	0,$DF,$21,0,$EC,$25,0,$F8
	DC.B	$28,0,8,$28,0,$14,$25,0
	DC.B	$21,$21,0,$31,$22,0,$42,$21
	DC.B	0,$52,$21,0,$B2,$2D,0,$C2
	DC.B	$2C,0,$D3,$2D,0,$DE,$31,0
	DC.B	$EC,$35,0,$F8,$38,0,8,$38
	DC.B	0,$14,$35,0,$22,$31,0,$2D
	DC.B	$2D,0,$3E,$2C,0,$4E,$2D,0
	DC.B	$B9,$36,0,$CC,$34,0,$D4,$3E
	DC.B	0,$DF,$42,0,$EC,$46,0,$F8
	DC.B	$48,0,8,$48,0,$14,$46,0
	DC.B	$21,$42,0,$2C,$3E,0,$34,$34
	DC.B	0,$47,$36,0,$C1,$3F,0,$CA
	DC.B	$47,0,$D3,$4E,0,$DF,$52,0
	DC.B	$EC,$56,0,$F8,$58,0,8,$58
	DC.B	0,$14,$56,0,$21,$52,0,$2D
	DC.B	$4E,0,$36,$47,0,$3F,$3F,0


	.phrase
segments:
	dc.l			1,2
	dc.l			2,3
	dc.l			3,4
	dc.l			4,5
	dc.l			5,6
	dc.l			6,7
	dc.l			7,8
	dc.l			8,9
	dc.l			9,$A
	dc.l			$A,$B
	dc.l			$B,$C
	dc.l			$D,$E
	dc.l			$E,$F
	dc.l			$F,$10
	dc.l			$10,$11
	dc.l			$11,$12
	dc.l			$12,$13
	dc.l			$13,$14
	dc.l			$14,$15
	dc.l			$15,$16
	dc.l			$16,$17
	dc.l			$17,$18
	dc.l			$19,$1A
	dc.l			$1A,$1B
	dc.l			$1B,$1C
	dc.l			$1C,$1D
	dc.l			$1D,$1E
	dc.l			$1E,$1F
	dc.l			$1F,$20
	dc.l			$20,$21
	dc.l			$21,$22
	dc.l			$22,$23
	dc.l			$23,$24
	dc.l			$25,$26
	dc.l			$26,$27
	dc.l			$27,$28
	dc.l			$28,$29
	dc.l			$29,$2A
	dc.l			$2A,$2B
	dc.l			$2B,$2C
	dc.l			$2C,$2D
	dc.l			$2D,$2E
	dc.l			$2E,$2F
	dc.l			$2F,$30
	dc.l			$31,$32
	dc.l			$32,$33
	dc.l			$33,$34
	dc.l			$34,$35
	dc.l			$35,$36
	dc.l			$36,$37
	dc.l			$37,$38
	dc.l			$38,$39
	dc.l			$39,$3A
	dc.l			$3A,$3B
	dc.l			$3B,$3C
	dc.l			$3D,$3E
	dc.l			$3E,$3F
	dc.l			$3F,$40
	dc.l			$40,$41
	dc.l			$41,$42
	dc.l			$42,$43
	dc.l			$43,$44
	dc.l			$44,$45
	dc.l			$45,$46
	dc.l			$46,$47
	dc.l			$47,$48
	dc.l			$49,$4A
	dc.l			$4A,$4B
	dc.l			$4B,$4C
	dc.l			$4C,$4D
	dc.l			$4D,$4E
	dc.l			$4E,$4F
	dc.l			$4F,$50
	dc.l			$50,$51
	dc.l			$51,$52
	dc.l			$52,$53
	dc.l			$53,$54
	dc.l			$55,$56
	dc.l			$56,$57
	dc.l			$57,$58
	dc.l			$58,$59
	dc.l			$59,$5A
	dc.l			$5A,$5B
	dc.l			$5B,$5C
	dc.l			$5C,$5D
	dc.l			$5D,$5E
	dc.l			$5E,$5F
	dc.l			$5F,$60
	dc.l			$61,$62
	dc.l			$62,$63
	dc.l			$63,$64
	dc.l			$64,$65
	dc.l			$65,$66
	dc.l			$66,$67
	dc.l			$67,$68
	dc.l			$68,$69
	dc.l			$69,$6A
	dc.l			$6A,$6B
	dc.l			$6B,$6C
	dc.l			$6D,$6E
	dc.l			$6E,$6F
	dc.l			$6F,$70
	dc.l			$70,$71
	dc.l			$71,$72
	dc.l			$72,$73
	dc.l			$73,$74
	dc.l			$74,$75
	dc.l			$75,$76
	dc.l			$76,$77
	dc.l			$77,$78
	dc.l			$79,$7A
	dc.l			$7A,$7B
	dc.l			$7B,$7C
	dc.l			$7C,$7D
	dc.l			$7D,$7E
	dc.l			$7E,$7F
	dc.l			$7F,$80
	dc.l			$80,$81
	dc.l			$81,$82
	dc.l			$82,$83
	dc.l			$83,$84
	dc.l			$85,$86
	dc.l			$86,$87
	dc.l			$87,$88
	dc.l			$88,$89
	dc.l			$89,$8A
	dc.l			$8A,$8B
	dc.l			$8B,$8C
	dc.l			$8C,$8D
	dc.l			$8D,$8E
	dc.l			$8E,$8F
	dc.l			$8F,$90
	dc.l			1,$D
	dc.l			$D,$19
	dc.l			$19,$25
	dc.l			$25,$31
	dc.l			$31,$3D
	dc.l			$3D,$49
	dc.l			$49,$55
	dc.l			$55,$61
	dc.l			$61,$6D
	dc.l			$6D,$79
	dc.l			$79,$85
	dc.l			2,$E
	dc.l			$E,$1A
	dc.l			$1A,$26
	dc.l			$26,$32
	dc.l			$32,$3E
	dc.l			$3E,$4A
	dc.l			$4A,$56
	dc.l			$56,$62
	dc.l			$62,$6E
	dc.l			$6E,$7A
	dc.l			$7A,$86
	dc.l			3,$F
	dc.l			$F,$1B
	dc.l			$1B,$27
	dc.l			$27,$33
	dc.l			$33,$3F
	dc.l			$3F,$4B
	dc.l			$4B,$57
	dc.l			$57,$63
	dc.l			$63,$6F
	dc.l			$6F,$7B
	dc.l			$7B,$87
	dc.l			4,$10
	dc.l			$10,$1C
	dc.l			$1C,$28
	dc.l			$28,$34
	dc.l			$34,$40
	dc.l			$40,$4C
	dc.l			$4C,$58
	dc.l			$58,$64
	dc.l			$64,$70
	dc.l			$70,$7C
	dc.l			$7C,$88
	dc.l			5,$11
	dc.l			$11,$1D
	dc.l			$1D,$29
	dc.l			$29,$35
	dc.l			$35,$41
	dc.l			$41,$4D
	dc.l			$4D,$59
	dc.l			$59,$65
	dc.l			$65,$71
	dc.l			$71,$7D
	dc.l			$7D,$89
	dc.l			6,$12
	dc.l			$12,$1E
	dc.l			$1E,$2A
	dc.l			$2A,$36
	dc.l			$36,$42
	dc.l			$42,$4E
	dc.l			$4E,$5A
	dc.l			$5A,$66
	dc.l			$66,$72
	dc.l			$72,$7E
	dc.l			$7E,$8A
	dc.l			7,$13
	dc.l			$13,$1F
	dc.l			$1F,$2B
	dc.l			$2B,$37
	dc.l			$37,$43
	dc.l			$43,$4F
	dc.l			$4F,$5B
	dc.l			$5B,$67
	dc.l			$67,$73
	dc.l			$73,$7F
	dc.l			$7F,$8B
	dc.l			8,$14
	dc.l			$14,$20
	dc.l			$20,$2C
	dc.l			$2C,$38
	dc.l			$38,$44
	dc.l			$44,$50
	dc.l			$50,$5C
	dc.l			$5C,$68
	dc.l			$68,$74
	dc.l			$74,$80
	dc.l			$80,$8C
	dc.l			9,$15
	dc.l			$15,$21
	dc.l			$21,$2D
	dc.l			$2D,$39
	dc.l			$39,$45
	dc.l			$45,$51
	dc.l			$51,$5D
	dc.l			$5D,$69
	dc.l			$69,$75
	dc.l			$75,$81
	dc.l			$81,$8D
	dc.l			$A,$16
	dc.l			$16,$22
	dc.l			$22,$2E
	dc.l			$2E,$3A
	dc.l			$3A,$46
	dc.l			$46,$52
	dc.l			$52,$5E
	dc.l			$5E,$6A
	dc.l			$6A,$76
	dc.l			$76,$82
	dc.l			$82,$8E
	dc.l			$B,$17
	dc.l			$17,$23
	dc.l			$23,$2F
	dc.l			$2F,$3B
	dc.l			$3B,$47
	dc.l			$47,$53
	dc.l			$53,$5F
	dc.l			$5F,$6B
	dc.l			$6B,$77
	dc.l			$77,$83
	dc.l			$83,$8F
	dc.l			$C,$18
	dc.l			$18,$24
	dc.l			$24,$30
	dc.l			$30,$3C
	dc.l			$3C,$48
	dc.l			$48,$54
	dc.l			$54,$60
	dc.l			$60,$6C
	dc.l			$6C,$78
	dc.l			$78,$84
	dc.l			$84,$90

		.dphrase

logo_DUNE:
; 64*240
		.incbin		"c:/jaguar/Northstar/DUNE_vertical_Jaguar_transparent.png_JAG_CRY"
; 320x200x2
		.dphrase
module_FC:
	; .incbin			"C:\Jaguar\modules\_Tunes\web\Future Composer 1.4\Equinox - Future Combat.fc"			; OK
	;.incbin		"C:/Jaguar/modules/_Tunes/web/Future Composer 1.0 - 1.3/rebels.smod"		; OK
	;.incbin		"C:/Jaguar/modules/_Tunes/web/Future Composer 1.0 - 1.3/Demo-04.fc"			; OK ( depote )
	;.incbin		"C:/Jaguar/modules/_Tunes/web/Future Composer 1.0 - 1.3/Last V8.fc"			; OK ( bof)
	;.incbin		"C:/Jaguar/modules/_Tunes/Rings_of_Medusa.FC4"					; OK
	;.incbin		"C:/Jaguar/modules/_Tunes/Gates_of_Jambala_1-2.FC"			; OK
	; .incbin		"C:/Jaguar/modules/_Tunes/web/jambala.fc"
	;.incbin		"C:\Jaguar\modules\_Tunes\web\Future Composer 1.4\Gates Of Jambala 1-2.fc"		; OK
	;.incbin		"C:\Jaguar\modules\_Tunes\web\Future Composer 1.0 - 1.3\Awesome.fc"				; OK
	;.incbin			"C:\Jaguar\modules\_Tunes\web\Future Composer 1.4\Absence - Reform 33 Intro.fc"			; OK
	;.incbin		"C:/Jaguar/modules/_Tunes/abscence.fc4"				; OK
	 .incbin		"C:/Jaguar/modules/_Tunes/Arcane-Theme.FC"				; OK
	;.incbin		"C:/Jaguar/modules/_Tunes/Amaze 2.fc14"				; OK !
	; .incbin		"C:/Jaguar/modules/_Tunes/Astaroth_1.FC3"   ; OK !
	
	; .incbin		"C:/Jaguar/modules/_Tunes/web/Chambers of Shaolin 1.fc14"									; OK
	;.incbin		"C:\Jaguar\modules\_Tunes\web\Future Composer 1.0 - 1.3\Chambers Of Shaolin 1.fc"		; KO - son bizarre ?

	;.incbin			"C:\Jaguar\modules\_Tunes\web\Future Composer 1.4\Advance.fc"			; OK
	.dphrase


fonte:	
					; 0123456789
					; ABCDEFGHIJKLMNOPQRSTUVWXYZ
					; ?!:;,'()-+. 
						;.incbin	"fonte1.bin"
						;dcb.b		8,0
; A-T
; U-Z0-9,""':
; =+-!? 
	.incbin		"c:/jaguar/Northstar/fonte16x24_1P.png_JAG"
FIN_fonte:
	.phrase

texte_du_scrolling:
debut_scrolling:
	dc.b		"    Another year, another Jaguar demo. Welcome to 2023 with this 60 fps version of the Amiga Northstar Interpol demo, with a very classic Amiga Future Composer tune. Design and graphics were done by Mic. Line rout freely adapted from 42Bastian last Jaguar demo. "
	dc.b		"This very nice demo on Amiga needed a full frame re-coding, so enjoy watching this very fluent 3D objects, so hypnotizing....    and now, Mic will tell you the very old story of an old democrew... "
	.incbin		"c:/jaguar/Northstar/scrolltext.txt"
	dc.b		-1
fin_scrolling:
	.phrase
	
table_traduction_texte_scrolling_direct:
		dc.l	fonte+(3*24*320)+(16*16)	;			032      040    20   00100000       SP    (Space)
		dc.l	fonte+(2*24*320)+(03*16)	;         	033      041    21   00100001        !    (exclamation mark)
        dc.l	fonte+(1*24*320)+(17*16)	; 034      042    22   00100010        "    (double quote)
        dc.l	fonte+(3*24*320)+(16*16)	; 035      043    23   00100011        #    (number sign)
        dc.l	fonte+(3*24*320)+(12*16)	; 036      044    24   00100100        $    (dollar sign)
        dc.l	fonte+(3*24*320)+(16*16)	; 037      045    25   00100101        %    (percent)
        dc.l	fonte+(3*24*320)+(16*16)	; 038      046    26   00100110        &    (ampersand)
        dc.l	fonte+(1*24*320)+(18*16)	; 039      047    27   00100111        '    (single quote)
        dc.l	fonte+(3*24*320)+(14*16)	; 040      050    28   00101000        (    (left opening parenthesis)
        dc.l	fonte+(3*24*320)+(15*16)	;  041      051    29   00101001        )    (right closing parenthesis)
        dc.l	fonte+(3*24*320)+(16*16)	;  042      052    2A   00101010        *    (asterisk)
        dc.l	fonte+(2*24*320)+(01*16)	;  043      053    2B   00101011        +    (plus)
        dc.l	fonte+(1*24*320)+(16*16)	;  044      054    2C   00101100        ,    (comma)
        dc.l	fonte+(2*24*320)+(02*16)	;  045      055    2D   00101101        -    (minus or dash)
        dc.l	fonte+(2*24*320)+(05*16)	;  046      056    2E   00101110        .    (dot)
        dc.l	fonte+(3*24*320)+(13*16)	;  047      057    2F   00101111        /    (forward slash)
        dc.l	fonte+(1*24*320)+(06*16)	;  048      060    30   00110000        0
        dc.l	fonte+(1*24*320)+(07*16)	; 049      061    31   00110001        1
        dc.l	fonte+(1*24*320)+(08*16)	; 050      062    32   00110010        2
        dc.l	fonte+(1*24*320)+(09*16)	; 051      063    33   00110011        3
        dc.l	fonte+(1*24*320)+(10*16)	; 052      064    34   00110100        4
        dc.l	fonte+(1*24*320)+(11*16)	; 053      065    35   00110101        5
        dc.l	fonte+(1*24*320)+(12*16)	; 054      066    36   00110110        6
        dc.l	fonte+(1*24*320)+(13*16)	; 055      067    37   00110111        7
        dc.l	fonte+(1*24*320)+(14*16)	; 056      070    38   00111000        8
        dc.l	fonte+(1*24*320)+(15*16)	; 057      071    39   00111001        9
        dc.l	fonte+(1*24*320)+(19*16)	; 058      072    3A   00111010        :    (colon)
        dc.l	fonte+(3*24*320)+(16*16)	; 059      073    3B   00111011        ;    (semi-colon)
        dc.l	fonte+(3*24*320)+(16*16)	;  060      074    3C   00111100        <    (less than sign)
        dc.l	fonte+(2*24*320)+(00*16)	; 061      075    3D   00111101        =    (equal sign)
        dc.l	fonte+(3*24*320)+(16*16)	; 062      076    3E   00111110        >    (greater than sign)
        dc.l	fonte+(2*24*320)+(04*16)	; 063      077    3F   00111111        ?    (question mark)
        dc.l	fonte+(3*24*320)+(16*16)	; 064      100    40   01000000        @    (AT symbol)
        dc.l	fonte+(0*24*320)+(00*16)	; 065      101    41   01000001        A
        dc.l	fonte+(0*24*320)+(01*16)	; 066      102    42   01000010        B
        dc.l	fonte+(0*24*320)+(02*16)	; 067      103    43   01000011        C
        dc.l	fonte+(0*24*320)+(03*16)	; 068      104    44   01000100        D
        dc.l	fonte+(0*24*320)+(04*16)	; 069      105    45   01000101        E
        dc.l	fonte+(0*24*320)+(05*16)	; 070      106    46   01000110        F
        dc.l	fonte+(0*24*320)+(06*16)	; 071      107    47   01000111        G
        dc.l	fonte+(0*24*320)+(07*16)	; 072      110    48   01001000        H
        dc.l	fonte+(0*24*320)+(08*16)	; 073      111    49   01001001        I
        dc.l	fonte+(0*24*320)+(09*16)	; 074      112    4A   01001010        J
        dc.l	fonte+(0*24*320)+(10*16)	; 075      113    4B   01001011        K
        dc.l	fonte+(0*24*320)+(11*16)	; 076      114    4C   01001100        L
        dc.l	fonte+(0*24*320)+(12*16)	; 077      115    4D   01001101        M
        dc.l	fonte+(0*24*320)+(13*16)	; 078      116    4E   01001110        N
        dc.l	fonte+(0*24*320)+(14*16)	; 079      117    4F   01001111        O
        dc.l	fonte+(0*24*320)+(15*16)	; 080      120    50   01010000        P
        dc.l	fonte+(0*24*320)+(16*16)	; 081      121    51   01010001        Q
        dc.l	fonte+(0*24*320)+(17*16)	; 082      122    52   01010010        R
        dc.l	fonte+(0*24*320)+(18*16)	; 083      123    53   01010011        S
        dc.l	fonte+(0*24*320)+(19*16)	; 084      124    54   01010100        T
        dc.l	fonte+(1*24*320)+(00*16)	; 085      125    55   01010101        U
        dc.l	fonte+(1*24*320)+(01*16)	; 086      126    56   01010110        V
        dc.l	fonte+(1*24*320)+(02*16)	; 087      127    57   01010111        W
        dc.l	fonte+(1*24*320)+(03*16)	; 088      130    58   01011000        X
        dc.l	fonte+(1*24*320)+(04*16)	; 089      131    59   01011001        Y
        dc.l	fonte+(1*24*320)+(05*16)	; 090      132    5A   01011010        Z
        dc.l	fonte+(3*24*320)+(16*16)	; 091      133    5B   01011011        [    (left opening bracket)
        dc.l	fonte+(3*24*320)+(16*16)	; 092      134    5C   01011100        \    (back slash)
        dc.l	fonte+(3*24*320)+(16*16)	; 093      135    5D   01011101        ]    (right closing bracket)
        dc.l	fonte+(3*24*320)+(16*16)	; 094      136    5E   01011110        ^    (caret cirumflex)
        dc.l	fonte+(3*24*320)+(16*16)	; 095      137    5F   01011111        _    (underscore)
        dc.l	fonte+(3*24*320)+(16*16)	; 096      140    60   01100000        `
        dc.l	fonte+(2*24*320)+(06*16)	; 097      141    61   01100001        a
        dc.l	fonte+(2*24*320)+(07*16)	; 098      142    62   01100010        b
        dc.l	fonte+(2*24*320)+(08*16)	; 099      143    63   01100011        c
        dc.l	fonte+(2*24*320)+(09*16)	; 100      144    64   01100100        d
        dc.l	fonte+(2*24*320)+(10*16)	; 101      145    65   01100101        e
        dc.l	fonte+(2*24*320)+(11*16)	; 102      146    66   01100110        f
        dc.l	fonte+(2*24*320)+(12*16)	; 103      147    67   01100111        g
        dc.l	fonte+(2*24*320)+(13*16)	; 104      150    68   01101000        h
        dc.l	fonte+(2*24*320)+(14*16)	; 105      151    69   01101001        i
        dc.l	fonte+(2*24*320)+(15*16)	; 106      152    6A   01101010        j
        dc.l	fonte+(2*24*320)+(16*16)	; 107      153    6B   01101011        k
        dc.l	fonte+(2*24*320)+(17*16)	; 108      154    6C   01101100        l
        dc.l	fonte+(2*24*320)+(18*16)	; 109      155    6D   01101101        m
        dc.l	fonte+(2*24*320)+(19*16)	; 110      156    6E   01101110        n
        dc.l	fonte+(3*24*320)+(00*16)	; 111      157    6F   01101111        o
        dc.l	fonte+(3*24*320)+(01*16)	; 112      160    70   01110000        p
        dc.l	fonte+(3*24*320)+(02*16)	; 113      161    71   01110001        q
        dc.l	fonte+(3*24*320)+(03*16)	; 114      162    72   01110010        r
        dc.l	fonte+(3*24*320)+(04*16)	; 115      163    73   01110011        s
        dc.l	fonte+(3*24*320)+(05*16)	; 116      164    74   01110100        t
        dc.l	fonte+(3*24*320)+(06*16)	; 117      165    75   01110101        u
        dc.l	fonte+(3*24*320)+(07*16)	; 118      166    76   01110110        v
        dc.l	fonte+(3*24*320)+(08*16)	; 119      167    77   01110111        w
        dc.l	fonte+(3*24*320)+(09*16)	; 120      170    78   01111000        x
        dc.l	fonte+(3*24*320)+(10*16)	; 121      171    79   01111001        y
        dc.l	fonte+(3*24*320)+(11*16)	; 122      172    7A   01111010        z
	
table_traduction_texte_scrolling:
		dc.b	"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789,"
		dc.b	'"'
		dc.b	"':=+-!?.abcdefghijklmnopqrstuvwxyz$/() "
		dc.b	-1
	
.phrase
; motif fond scrolling
motif_fond_scrolling:
		;.incbin		"c:/jaguar/Northstar/motif.png_JAG"			; 256 c
		.incbin		"c:/jaguar/Northstar/motif2.png_JAG_CRY"		; CRY
.phrase
table_couleur:
        ; dc.w    0x0000
        dc.w    $9488			; 2
        dc.w    $A490
        dc.w    $A590
        dc.w    $A598
        dc.w    $B5A0
        dc.w    $B6A0
        dc.w    $B6A8
        dc.w    $C6B0
        dc.w    $C7B0
        dc.w    $C7B8
        dc.w    $D7C0
        dc.w    $D8C0
        dc.w    $C7C8
        dc.w    $D8C8
        dc.w    $D8D0
        dc.w    $D8D8
        dc.w    $E9E0
        dc.w    $E9E8
        dc.w    $C7A0
        dc.w    $B690
        dc.w    $B688
        dc.w    $B678
        dc.w    $B670
        dc.w    $A568
        dc.w    $A658
        dc.w    $A560
        dc.w    $A558
        dc.w    $A650
        dc.w    $A450
        dc.w    $9548
        dc.w    $9540
        dc.w    $9538
        dc.w    $7430
        dc.w    $9430
        dc.w    $B010
        dc.w    $C7A8
        dc.w    $9440
        dc.w    $B698
        dc.w    $9550
        dc.w    $B580
        dc.w    $A578
        dc.w    $A668
        dc.w    $9450
        dc.w    $B590
        dc.w    $8448
        dc.w    $A570
        dc.w    $9560
        dc.w    $9460
        dc.w    $A580
        dc.w    $A470
        dc.w    $7578
        dc.w    $A690
        dc.w    $B6B8
        dc.w    $A588
        dc.w    $A678
        dc.w    $9558
        dc.w    $9568
        dc.w    $9480
        dc.w    $9570
        dc.w    $7570
        dc.w    $9470
        dc.w    $6440
.phrase


		.BSS
DEBUT_BSS:

		.phrase
points_en_cours__en_word:
		ds.w			3*NBPTS
increments_transformation:
		ds.w			3*NBPTS

		.phrase
stock_points_2D:
		ds.l		2*NBPTS
	.phrase


_50ou60hertz:	ds.l	1
ntsc_flag:				ds.w		1
a_hdb:          		ds.w		1
a_hde:          		ds.w		1
a_vdb:          		ds.w		1
a_vde:          		ds.w		1
width:          		ds.w		1
height:         		ds.w		1
vbl_counter:			ds.l		1
	even

            .dphrase
; en 1 plan = 10240
pixels_par_octet=1				; 8
						ds.b		(320*50)/pixels_par_octet
.phrase
zone3D_1:				ds.b		(320*256)/pixels_par_octet
						ds.b		(320*50)/pixels_par_octet
.phrase
zone3D_2:				ds.b		(320*256)/pixels_par_octet
						ds.b		(320*50)/pixels_par_octet

.phrase
texte_scrolling_traduit:
		ds.l			(fin_scrolling-debut_scrolling)
		ds.l			1

				
	.phrase
zone_scrolling_dessus_256c_640pixels__zone1:
;640x24
						ds.b		(320*24)*2
	.phrase
zone_scrolling_dessus_256c_640pixels__zone2:
;640x24
						ds.b		(320*24)*2
						
	.phrase
zone_resultat_scrolling_256c_zone1:
; 320x24
						ds.b		(24*320)*2
	.phrase
zone_resultat_scrolling_256c_zone2:
; 320x24
						ds.b		(24*320)*2

; zone du scrolling en 256 c
; 8 pixels de haut
; double largeur
;zone_scrolling1:
;						ds.b		(320*24)
;zone_scrolling2:
;						ds.b		((320*8))*2


FIN_RAM:
