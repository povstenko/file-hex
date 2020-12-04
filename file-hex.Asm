.386
.model flat,STDCALL
option casemap :none  ;case sensitive

include file-hex.inc

.code
Begin:
	call main
	
invoke ExitProcess,NULL

; власна процедура виділення пам'яті
Mem_Alloc PROC Buf_Size:DWORD
	add Buf_Size,4	; виділяємо буфер на 4 байти більший
	invoke GlobalAlloc,GMEM_MOVEABLE or GMEM_ZEROINIT, Buf_Size   ; виділяємо область у динамічній пам'яті
	push eax 	; зберігаємо хендл області виділеного буфера у стек
	invoke GlobalLock,eax ;фіксуємо у реальній
	pop [eax]	;Витягнемо зі стеку значення  і запишемо у перші 4 байта виділеного масиву, 
				;це значення є хенд області виділеної області
				;наступні Buf_Size байт використовуємо як масив
	add eax,4	;зсуваємо вказівних початку масиву на 4 байти, оскільки перші 4 байти 
			;заняті значенням хендлу буфера
	ret	; виходимо з процедури
Mem_Alloc endp

; власна процедура знищення пам'яті.
Mem_Free PROC DATA:DWORD
	mov eax,DATA	;копіюємо значення параметра процедури у регістр eax, параметром є 
					;початкова (робоча) адреса буфера ( початок + 4 байти)
	sub eax,4	;пам'ятаємо, що перших 4 байти масиву  - це хендл буфера
	push [eax]	;беремо чотирьох байтне значення по адресі, що лежить у регістрі eax, заносимо його у стек
	push [eax]	;беремо чотирьох байтне значення по адресі, що лежить у регістрі eax, заносимо його у стек
	call GlobalUnlock	;розблоковуємо пам'ять (всю розміром Buf_Size+4)
	call GlobalFree	;оскільки параметр вже у стеці, викликаємо процедуру без параметрів, за дапомогою інструкції 
					;call (знищуємо хендел буфера)
	ret	;вихід з процедури
Mem_Free endp

read_file proc file_path, pMem:dword
LOCAL hfile, readed:dword	
	invoke CreateFile, file_path, GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0
	cmp eax, -1
	je @F
	mov hfile, eax
	
	invoke ReadFile, hfile, pMem, 4000h, addr readed, 0
	invoke CloseHandle,hfile	
@@:	
	ret

read_file endp

write_file proc file_path, pMem, size_pmem:dword

LOCAL hfile, readed:dword	

	invoke CreateFile, file_path, GENERIC_READ or GENERIC_WRITE, FILE_SHARE_READ, 0,CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0
	cmp eax, -1
	je @F
	mov hfile, eax
	
	invoke WriteFile, hfile, pMem, size_pmem, addr readed, 0
	invoke CloseHandle,hfile	
@@:	
	ret

write_file endp


a2h proc uses edi esi p1,p2:dword 
	mov esi, p1
	mov edi,p2
@@:
	lodsb
	
	test al,al
	jz exit
	mov bl, al
	shr bl, 4
	and al,0fh
	
	
	cmp bl,9
	ja m1
	add bl,'0'
	jmp next
m1:
	add bl,'A'-10
next:
	mov [edi],bl
	
	cmp al,9
	ja m2
	add al,'0'
	jmp next2
m2:
	add al,'A'-10
next2:
	mov [edi+1],al
	add edi,2
	jmp @B
exit:
	
	ret

a2h endp
main proc
;init struct	
	invoke Mem_Alloc, sizeof OPENFILENAME
	mov edi, eax
	assume edi: ptr OPENFILENAME
	
	invoke GetCurrentDirectory, 260, addr initdir
	mov [edi].lStructSize, sizeof OPENFILENAME
	mov [edi].lpstrFile, offset filename
	mov [edi].nMaxFile, 260
	mov [edi].lpstrInitialDir, offset initdir
	
	invoke GetOpenFileName, edi
	cmp eax, 0
	je exit

; ——————————————————————————————————————————————————————————————————————————————————————————————————
;read data
	
	invoke Mem_Alloc, 4000h 
	mov pmem, eax
	
	invoke Mem_Alloc, 4000h 
	mov pmem2, eax
	
	invoke read_file,addr filename,pmem

; ——————————————————————————————————————————————————————————————————————————————————————————————————
;tranform data
	invoke a2h,pmem,pmem2
	invoke MessageBox, 0, pmem2, 0, MB_OK

; ——————————————————————————————————————————————————————————————————————————————————————————————————

;write data	
	invoke GetSaveFileName, edi
	cmp eax, 0
	je exit
	
	invoke lstrlen,pmem2
    invoke write_file,addr filename, pmem2,eax

exit:
;free mem	
	invoke Mem_Free, edi
	assume edi:DWORD
	invoke Mem_Free, pmem
	invoke Mem_Free, pmem2
	
	ret

main endp

end Begin
