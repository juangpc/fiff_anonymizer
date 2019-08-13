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

[inFilePath,inFileName,inFileExt] = fileparts(inFile);
outFile = fullfile(inFilePath,[inFileName '_anonymized' inFileExt]);

[inFid,~] = fopen(inFile,'r+','ieee-be');
[outFid,~] = fopen(outFile,'w+','ieee-be');

outDir=[];
jump=true;

%read first tag->fileID?->outFile
inTag=read_tag(inFid,jump);

%checking for valid fiff file.
if(inTag.kind ~= 100)
  fclose(inFid);
  fclose(outFid);
  delete(outFile)
  error('Sorry! This is not a valid FIFF file');
end

%checking for correct version of fif file format
fileID=parse_fileID_tag(inTag.data);
if(fileID.version>MAX_VALID_VERSION)
  error(['Sorry! This version of fiff_anonymizer only supports' ...
    ' fif files up to version: ' num2str(MAX_VALID_VERSION)]);
end

[outTag,~] = censor_tag(inTag);%offset will be always zero
outTag.next=0;
outDir=add_entry_to_tagDir(outDir,outTag,ftell(outFid));
write_tag(outFid,outTag);

while (inTag.next ~= -1)
  inTag=read_tag(inFid,jump);
  
  [outTag,~] = censor_tag(inTag);
  if (outTag.next > 0)
    outTag.next=0;
  end
  outDir=add_entry_to_tagDir(outDir,outTag,ftell(outFid));
  write_tag(outFid,outTag);
  
end
fclose(inFid);

outDir=add_final_entry_to_tagDir(outDir);
outDirAddr=ftell(outFid);
write_directory(outFid,outDir,outDirAddr);

ptrDIR_KIND = 101;
ptrFREELIST_KIND = 106;
update_pointer(outFid,outDir,ptrDIR_KIND,outDirAddr);
update_pointer(outFid,outDir,ptrFREELIST_KIND,-1);

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

function tagDir = add_entry_to_tagDir(tagDir,tag,pos)
tag=rmfield(tag,'data');
tag=rmfield(tag,'next');
tag.pos=pos;
tagDir=cat(2,tagDir,tag);
end

function tagDir = add_final_entry_to_tagDir(tagDir)
tag.kind=-1;
tag.type=-1;
tag.size=-1;
tag.pos=-1;
tagDir=cat(2,tagDir,tag);
end

function write_directory(fid,dir,dirpos)
% TAG_INFO_SIZE = 16;
numTags=size(dir,2);

fseek(fid,dirpos,'bof');
fwrite(fid,int32(102),'int32');
fwrite(fid,int32(32),'int32');
fwrite(fid,int32(16*numTags),'int32');
fwrite(fid,int32(-1),'int32');

for i=1:numTags
  fwrite(fid,int32(dir(i).kind),'int32');
  fwrite(fid,int32(dir(i).type),'int32');
  fwrite(fid,int32(dir(i).size),'int32');
  fwrite(fid,int32(dir(i).pos),'int32');
end

end

function count=update_pointer(fid,dir,tagKind,newAddr)
TAG_INFO_SIZE = 16;
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

