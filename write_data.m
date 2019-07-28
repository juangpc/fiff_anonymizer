function write_data(fid,data,type)

switch type
  case 3
    fwrite(fid,data,'int32');
  case 4
    fwrite(fid,data,'single');
  case 6
    fwrite(fid,data,'int32');
  case 10
    fwrite(fid,data,'char');
  otherwise
    fwrite(fid,data,'int8');
end

end