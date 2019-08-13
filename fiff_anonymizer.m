function fiff_anonymizer(inFile)
%
%   fiff_anonymizer('fname.fif')
%
%   Author : Juan Garcia-Prieto, JuanGarciaPrieto@uth.tmc.edu
%            UTHealth - Houston, Tx
%   License : MIT
%
%   Revision 0.3  July 2019

MAX_VALID_VERSION = 1.3;
TAG_INFO_SIZE = 16;
DIRp_KIND = 101;
DIR_KIND = 102;
FREELIST_KIND = 106;

[inFilePath,inFileName,inFileExt] = fileparts(inFile);
outFile = fullfile(inFilePath,[inFileName '_anonymized' inFileExt]);

offsetRegister=[];
%outTagList=[];

[inFid,~] = fopen(inFile,'r+','ieee-be');
[outFid,~] = fopen(outFile,'w+','ieee-be');

inDir=build_tag_dir(inFid);

%read first tag->fileID?->outFile
inTag=read_tag(inFid);
%checking for correct version of fif file format
fileID=parse_fileID_tag(inTag.data);
if(fileID.version>MAX_VALID_VERSION)
  error(['Sorry! This version of fiff_anonymizer only supports' ...
    ' fif files up to version: ' num2str(MAX_VALID_VERSION)]);
end
[outTag,~] = censor_tag(inTag);%offset will be always zero
write_tag(outFid,outTag);

% dirEntry=rmfield(outTag,'data');
% dirEntry.pos=ftell(outFid)-(TAG_INFO_SIZE+dirEntry.size);
% outTagList=cat(1,outTagList,dirEntry);

while ~feof(inFid)
  pos=ftell(inFid);
  inTag=read_tag(inFid);
  if feof(inFid)
    break;
  end
  
  %check if orphan tag
  tagPos=find(pos == [inDir.pos]', 1);
  orphanTag=isempty(tagPos);
  
  if(~orphanTag)
    [outTag,offset] = censor_tag(inTag);
    write_tag(outFid,outTag);
    
    % dirEntry=rmfield(outTag,'data');
    % dirEntry.pos=ftell(outFid)-(TAG_INFO_SIZE+dirEntry.size);
    % outTagList=cat(1,outTagList,dirEntry);
    
    if(offset~=0)
      offsetRegister=cat(1,offsetRegister,...
        [ftell(outFid)-(TAG_INFO_SIZE+outTag.size),offset]);
      %sort Register!!!!
    end
  elseif(inTag.kind == DIR_KIND)
    dirTagPos=ftell(outFid);
    write_tag(outFid,inTag);%trick. both in and outTag will be equal size.
  else
    disp(['Warning! Orphan tag at: ' num2str(ftell(inFid)-(TAG_INFO_SIZE+inTag.size))]);
  end
end


fclose(inFid);

update_next_field(outFid,offsetRegister);
outDir=build_tag_dir(outFid);
update_pointer(outFid,outDir,DIRp_KIND,dirTagPos);
update_pointer(outFid,outDir,FREELIST_KIND,-1);%not needed but want to keep here to remind me of this ptr.
write_directory(outFid,outDir,dirTagPos);

fclose(outFid);

end

function tag = read_tag(fid,jump)

if(nargin==1)
  jump=false;
end

tag.kind = fread(fid,1,'int32');
tag.type = fread(fid,1,'int32');
tag.size = fread(fid,1,'int32');
tag.next = fread(fid,1,'int32');
if(tag.size>0)
  tag.data=fread(fid,tag.size,'int8');
else
  tag.data=[];
end

if(jump && tag.next>0)
  fseek(fid,tag.next,'bof');
end


end

function write_tag(fid,tag)

fwrite(fid,int32(tag.kind),'int32');
fwrite(fid,int32(tag.type),'int32');
fwrite(fid,int32(tag.size),'int32');
fwrite(fid,int32(tag.next),'int32');
if(tag.size>0)
  fwrite(fid,int8(tag.data),'int8');
end

end

function fileInfo = parse_fileID_tag(data)

fileInfo.version = (data(1)*16 + data(2)) + (data(3)*16 + data(4))/10;
fileInfo.machineID = data(5:12);
fileInfo.time = data(13)*16^3  + data(14)*16^2 + data(15)*16 + data(16) ...
  + (data(17)*16^3 + data(18)*16^2 + data(19)*16 + data(20))/1e6;

end

function [outTag,sizeDiff] = censor_tag(inTag,varargin)

%add block type to censorer to better identify tag.

defaultString = 'fiff_anonymizer';
defaultTime = datetime(2017,10,2);

switch(inTag.kind)
  case 100 %fileID
    newData=[inTag.data(1:12);0;0;0;1;0;0;0;1];
    % case 113
    % case 114
  case 204 %meas date
    t = dec2hex(posixtime(defaultTime));
    newData = hex2dec([t(1:2);t(3:4);t(5:6);t(7:8);'00';'00';'00';'01']);
    %   case 206
    %     disp(['Description of an object: ' char(inTag.data') ' -> ' defaultString]);
    %     newData=double(defaultString)';
  case 212 %experimenter
    disp(['Experimenter: ' char(inTag.data') ' -> ' defaultString]);
    newData=double(defaultString)';
    %   case 400
  case 401
    disp(['Subject First Name: ' char(inTag.data') ' -> ' defaultString]);
    newData=double(defaultString)';
    %   case 402
    %   case 403
  %case 404
    %newData=juliandate(defaultTime);
    %   case 405
    %   case 406
    %   case 407
    %   case 408
    %   case 409
    %   case 410
    %   case 500
    %   case 501
    %   case 502
    %   case 503
    %   case 504
  otherwise
    newData=inTag.data;
end

outTag.kind=inTag.kind;
outTag.type=inTag.type;
outTag.size=length(newData);
outTag.next=inTag.next;
outTag.data=newData;

sizeDiff = (outTag.size - inTag.size);

end

function tagDir = build_tag_dir(fid)
filePos=ftell(fid);
fseek(fid,0,'bof');

tagDir=[];
next=0;
while(next~=-1)
  pos=ftell(fid);
  tag=read_tag(fid,true);
  tag.pos=pos;
  next=tag.next;
  tag=rmfield(tag,'data');
  tag=rmfield(tag,'next');
  tagDir=cat(2,tagDir,tag);
end

fseek(fid,filePos,'bof');
end

function write_directory(fid,dir,dirpos)
filePos=ftell(fid);

fseek(fid,dirpos+TAG_INFO_SIZE,'bof');
for i=1:size(dir,1)
  fwrite(fid,int32(dir(i).kind),'int32');
  fwrite(fid,int32(dir(i).type),'int32');
  fwrite(fid,int32(dir(i).size),'int32');
  fwrite(fid,int32(dir(i).pos),'int32');
end

fseek(fid,filePos,'bof');
end

function count=update_pointer(fid,dir,tagKind,newAddr)
filePos=ftell(fid);

tagPos=find(tagKind == [dir.kind]', 1);
if ~isempty(tagPos)
  fseek(fid,dir(tagPos).pos+TAG_INFO_SIZE,'bof');
  count=fwrite(fid,int32(newAddr),'int32');
else
  count=0;
end

fseek(fid,filePos,'bof');
end

function newAddr=update_addr(addr,offsetRegister)

offset=0;
i=1;
while addr>offsetRegister(i,1) && i<=size(offsetRegister,1)
  offset=offset+offsetRegister(i,2);
  i=i+1;
end
newAddr=addr+offset;
end

function update_next_field(fid,offsetRegister)
filePos=ftell(fid);
fseek(fid,0,'bof');

pos=ftell(fid);
tag=read_tag(fid);
while(tag.next~=-1)
  if tag.next>0
    tag.next=update_addr(tag.next,offsetRegister);
    fseek(fid,pos,'bof');
    write_tag(fid,tag);
    fseek(fid,tag.next,'bof');
  end
  pos=ftell(fid);
  tag=read_tag(fid);
end

fseek(fid,filePos,'bof');
end



