function data=read_data(fid,type,size)

switch type
  case 1
    data=fread(fid,size,'int8');
  case 2
    data=fread(fid,size/2,'int16');
  case 3
    data=fread(fid,size/4,'int32');
  case 4
    data=fread(fid,size/4,'single');
  case 5
    data=fread(fid,size/8,'double');
  case 6
    data=fread(fid,size/4,'int32');
  case 10
    data=fread(fid,size,'char');
  otherwise
    data=fread(fid,size,'int8');
end

end