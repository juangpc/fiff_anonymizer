function fiff_anonimyzer(fname)
%
%   fiff_anonymizer('fname.fif')
%
%   Change every character in the subject name field by an 'X'.
%
%   Author : Juan García-Prieto, Centre for Biomedical Technology Madrid
%   License : APACHE
%
%   This work was builded on top of the amazing scripts from 
%   Matti Hamalainen, MGH Martinos Center, for fieltrip.
%
%   Revision 0.1  2012/08/02 
%

global FIFF;
if isempty(FIFF)
   FIFF = fiff_define_constants();
end

me='MNE:fiff_open';

[fid,msg] = fopen(fname,'r+','ieee-be');
tag = fiff_read_tag_info(fid);
tag = fiff_read_tag(fid);
dirpos = double(tag.data);

if dirpos > 0
    tag = fiff_read_tag(fid,dirpos);
    dir = tag.data;
else
    k = 0;
    fseek(fid,0,'bof');
    dir = struct('kind',{},'type',{},'size',{},'pos',{});
    while tag.next >= 0
        pos = ftell(fid);
        tag = fiff_read_tag_info(fid);
        k = k + 1;
        dir(k).kind = tag.kind;
        dir(k).type = tag.type;
        dir(k).size = tag.size;
        dir(k).pos  = pos;
    end
end
tree = fiff_make_dir_tree(fid,dir);

subject=fiff_dir_tree_find(tree,FIFF.FIFFB_SUBJECT);

for k = 1:subject.nent
    pos  = subject.dir(k).pos;
    
    pos=pos+11; 
    fseek(fid,pos,'bof');
    
    name_length=fread(fid,1);
    
    pos=pos+5; 
    fseek(fid,pos,'bof');
    
    for i=1:name_length,
        fwrite(fid,88,'uint8',0,'ieee-be');
    end

end

fclose(fid);





