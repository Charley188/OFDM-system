clear all
close all

%dur  = 3.2e-6;  
NLOP = 4;    % number of loop
NFFT = 64;      % Number of FFT points
NC   = 48;      % Number of subcarriers
NDS  = 2;        % Number of Data symbol per frame
NS   = NDS*NLOP;   % number of symbols
NP   = 4;        % Number of pilots in symbol -21, -7, 7, and 21
CP   = 16;       % cyclic prefix length
PRE  = 4;        % preamble symbol = 2
MOD  = 0;        % Data modulation 0:QPSK, 1:BPSK, 2:QAM16, 3:QAM64

% data in for TX ==========================================================
switch(MOD)
    case 1,     bit_symbols = round( 1*rand(1, NS*(NC)));       
    case 0,     bit_symbols = round( 3*rand(1, NS*(NC)));  
    case 2,     bit_symbols = round(15*rand(1, NS*(NC))); 
    case 3,     bit_symbols = round(63*rand(1, NS*(NC)));        
end

Len = NC * NDS;
len_data = NS * NC;
bit_symbols_vld(1:len_data)=1;
bit_symbols_last(1:len_data)=0;
bit_symbols_last(NC:NC:end)=1;
bit_slot_last(1:len_data)=0;
bit_slot_last(Len:Len:end)=1;


%write data to file =======================================================
fid = fopen('OFDM_TX_bit_symbols_Len.txt', 'w');
fprintf(fid, '%d ', Len);
fprintf(fid, '%d ', NLOP);
fprintf(fid, '%d ', MOD);
fclose(fid);

fid = fopen('OFDM_TX_bit_symbols.txt', 'w');
fprintf(fid, '%d ', bit_symbols);
fclose(fid);

fid = fopen('RTL_OFDM_TX_bit_symbols.txt', 'w');
fprintf(fid, '%x ', bit_symbols);
fclose(fid);

fid = fopen('RTL_OFDM_TX_bit_symbols_vld.txt', 'w');
fprintf(fid, '%x ', bit_symbols_vld);
fclose(fid);

fid = fopen('RTL_OFDM_TX_bit_symbols_last.txt', 'w');
fprintf(fid, '%x ', bit_symbols_last);
fclose(fid);

fid = fopen('RTL_OFDM_TX_bit_slot_last.txt', 'w');
fprintf(fid, '%x ', bit_slot_last);
fclose(fid);

%write Preamble ===========================================================
preamble_802_11;   
%DL_preamble_nor = DL_preamble ./ max(abs(DL_preamble));
DL_preamble_nor = [short_pre long_pre];

Preamble_rtl = DL_preamble_nor .*(2^15);
Preamble_Re  = typecast(int16(real(Preamble_rtl)),'uint16');
Preamble_Im  = typecast(int16(imag(Preamble_rtl)),'uint16');

Pre = uint32(Preamble_Im) * (2^16) + uint32(Preamble_Re);
fid = fopen('./Pre.txt', 'w');
fprintf(fid, '%8x ', Pre);
fclose(fid);

pilots_802_11;
Pilot_seq = reshape(pils, 1, 4*127);
Pilot_seq = (Pilot_seq(1:128)<0)*1;
Pre = uint32(Preamble_Im) * (2^16) + uint32(Preamble_Re);
fid = fopen('./Pilot_seq.txt', 'w');
fprintf(fid, '%d ', Pilot_seq);
fclose(fid);

fid = fopen('./Pilot_seq.coe','wt');    
%- standard format
fprintf( fid, 'MEMORY_INITIALIZATION_RADIX = 2;\n');                     
fprintf( fid, 'MEMORY_INITIALIZATION_VECTOR =\n');
%- write data in coe file
for i = 1:1:128
    fprintf(fid,'%d\n',Pilot_seq(i));  
end
fclose(fid);
