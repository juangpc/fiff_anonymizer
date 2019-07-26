function write_data(fid,data,type)

switch type
  case 1
    fwrite(fid,data,'int8');
  case 2
    fwrite(fid,data,'int16');
  case 3
    fwrite(fid,data,'int32');
  case 4
    fwrite(fid,data,'single');
  case 5
    fwrite(fid,data,'double');
  case 6
    fwrite(fid,data,'int32');
  otherwise
    fwrite(fid,data,'int8');
end

end