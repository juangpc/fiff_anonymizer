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

[inFilePath,inFileName,inFileExt] = fileparts(inFile);
outFile = fullfile(inFilePath,[inFileName '_anonymized' inFileExt]);
offsetRegister=[];

[infid,~] = fopen(inFile,'r+','ieee-be');
[outfid,~] = fopen(outFile,'w+','ieee-be');

tagList=build_tag_info_pos_list(infid);

%read first tag->fileID?->outFile
inTag=read_tag(infid);
%checking for correct version of fif file format
fileID=parse_fileID_tag(inTag.data);
if(fileID.version>MAX_VALID_VERSION)
  error(['Sorry! This version of fiff_anonymizer only supports' ...
    ' fif files up to version: ' num2str(MAX_VALID_VERSION)]);
end
[outTag,~] = censor_tag(inTag);%offset will be always zero
write_tag(outfid,outTag);

while ~feof(infid)
  
  tagPos=find(ftell(infid) == [tagList.pos]', 1);
  goodTag=~isempty(tagPos);
  
  inTag=read_tag(infid);
  if feof(infid)
    break;
  end
  
  if(goodTag)
    [outTag,offset] = censor_tag(inTag);
    write_tag(outfid,outTag);
    if(offset~=0)
      offsetRegister=cat(1,offsetRegister,...
        [ftell(outfid)-(TAG_INFO_SIZE+outTag.size),offset]);
    end
  else
    if(inTag.kind == 102)
      %tag directory->outFile
      disp('writing tag directory');
      dirpos=ftell(outfid);
      write_directory(outfid,tagList);
    else
      disp(['Orfan tag at: ' num2str(ftell(infid)-(TAG_INFO_SIZE+inTag.size))]);
    end
  end
end

fclose(infid);

%we need to update the dir in the file!!!!
fseek(outfid,0,'bof');


fclose(outfid);

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

defaultString = 'Fiff_anonymizer';
defaultTime = datetime(2017,10,2);

switch(inTag.kind)
  case 100 %fileID
    newData=[inTag.data(1:12);0;0;0;1;0;0;0;1];
    %   case 114
  case 204 %meas date
    t = dec2hex(posixtime(defaultTime));
    newData = hex2dec([t(1:2);t(3:4);t(5:6);t(7:8);'00';'00';'00';'01']);
    %   case 206
    %     disp(['Description of an object: ' char(inTag.data') ' -> ' defaultString]);
    %     newData=double(defaultString)';
  case 212 %experimenter
    disp(['Experimenter: ' char(inTag.data') ' -> ' defaultString]);
    newData=double(defaultString)';
    %   case 213 ?????????????
    %   case 400
  case 401
    disp(['Subject First Name: ' char(inTag.data') ' -> ' defaultString]);
    newData=double(defaultString)';
    %   case 402
    %   case 403
  case 404
    newData=juliandate(defaultTime);
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

function tagList = build_tag_info_pos_list(fid)
fseek(fid,0,'bof');
tagList=[];
tag.next=0;
while(tag.next~=-1)
  pos=ftell(fid);
  tag=read_tag(fid,true);
  tag.pos=pos;
  tag=rmfield(tag,'data');
  tagList=cat(1,tagList,tag);
end

fseek(fid,0,'bof');

end

function write_directory(fid,tagList)

for i=1:size(1,tagList)
  fwrite(fid,int32(tagList(i).kind),'int32');
  fwrite(fid,int32(tagList(i).type),'int32');
  fwrite(fid,int32(tagList(i).size),'int32');
  fwrite(fid,int32(tagList(i).pos),'int32');
end

end



