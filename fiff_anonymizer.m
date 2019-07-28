function fiff_anonymizer(inFile)
%
%   fiff_anonymizer('fname.fif')
%
%   Author : Juan Garcia-Prieto, JuanGarciaPrieto@uth.tmc.edu
%            UTHealth - Houston, Tx
%   License : MIT
%
%   Revision 0.2  2019

global FIFF;
if isempty(FIFF)
  FIFF = fiff_define_constants();
end
[inFilePath,inFileName,inFileExt] = fileparts(inFile);
outFile = fullfile(inFilePath,[inFileName '_anonymized2' inFileExt]);

[infid,~] = fopen(inFile,'r+','ieee-be');
[outfid,~] = fopen(outFile,'w+','ieee-be');

inTagDir=[];
outTagDir=[];

followJumps=true;

% posOffset=0;

%read first tag->fileID
inTag.kind = fread(infid,1,'int');
inTag.type = fread(infid,1,'int');
inTag.size = fread(infid,1,'int');
inTag.next = fread(infid,1,'int');
inTagDir=cat(1,inTagDir,inTag);
if(inTag.size>0)
  data=read_data(infid,inTag.type,inTag.size);
end

% nice to verify if fif version is all ok.

while(inTag.next ~= -1)
  
  inTag.kind = fread(infid,1,'int');
  inTag.type = fread(infid,1,'int');
  inTag.size = fread(infid,1,'int');
  inTag.next = fread(infid,1,'int');
  inTagDir=cat(1,inTagDir,inTag);
  if(inTag.size>0)
    data=read_data(infid,inTag.type,inTag.size);
  end
  if(followJumps && inTag.next>0)
    disp('I am jumping!!!!!!!!!!!!!!!!');
    fseek(infid,inTag.next,'bof');
  end
  
    switch(inTag.kind)
      %   case 114
      %     %add modifier
      %
      case 204
        %meas date
        %data=zeros(size(data));
        newData=[0;1];
        newSize=inTag.size;
  
      case 212
        %experimenter
        newStr='anonymous';
        disp(['Experimenter: ' char(data') ' -> ' newStr]);
        newData=double(newStr)';
        newSize=length(newData);
        %   case 400
      case 401
        newStr='anonymous';
        disp(['Subject First Name: ' char(data') ' -> ' newStr]);
        newData=double(newStr)';
        newSize=length(newData);
        %   case 402
        %   case 403
      case 404
        newData=2458029;
        newSize=inTag.size;
      case 405
        disp("hahaha");
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
        newData=data;
        newSize=inTag.size;
    end
  
  if(followJumps)
    newNext=0;
  end
  
  outTag.kind=inTag.kind;
  outTag.type=inTag.type;
  outTag.size=newSize;
  outTag.next=newNext;
  
  %   posOffset=posOffset+inTag.size-newSize; %consider case next is pointing **before** in the file
  %   if(inTag.next>0)
  %    tag.next=tag.next-posOffset;
  %   end
  %
  
  fwrite(outfid,int32(outTag.kind),'int32');
  fwrite(outfid,int32(outTag.type),'int32');
  fwrite(outfid,int32(outTag.size),'int32');
  fwrite(outfid,int32(outTag.next),'int32');
  if(outTag.size>0)
    write_data(outfid,newData,outTag.type);
  end
  
  outTagDir=cat(1,outTagDir,outTag);
  
end

%we need to update the dir in the file!!!!

fclose(infid);
fclose(outfid);

end







