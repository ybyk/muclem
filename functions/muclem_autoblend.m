function [out] = muclem_autoblend(sq_num,work_dir,mrc_root,LM_root,nosorting_LM)
%this script blends montage using imod blendmont function using matlab from
%system command line
%nir april 2017
%yura may 2017 (v4)
% new version does not cd to the directory and uses less parameters.
% ilastik folder creation is removed, bug with truncated blendmont command
% fixed (resulted in bad blending)

% %test parameters
% mrc_root = 'sq';
% LM_root = 'lm';
% sq_num = 1;
% work_dir = '/net/bstore1/bstore1/briggsgrp/ybykov/yeasthtp/wine/realdata/grid1/sq1_guitest';
% nosorting_LM = 0;

% hard-coded names and extensions
sq_root = 'sq';

mrcfile_ext = '.mrc';
mdocfile_ext = '.mrc.mdoc';
tiffile_ext = '.tif';

% Filenames before moving
mrc_file_name_old =  sprintf('%s%s%s%d%s', work_dir, filesep, mrc_root, sq_num, mrcfile_ext);

mdoc_file_name_old = sprintf('%s%s%s%d%s', work_dir, filesep, mrc_root, sq_num, mdocfile_ext);

lm_file_name = sprintf('%s%s%s%d%s', work_dir, filesep, LM_root, sq_num, tiffile_ext);

% name of the grid square folder
sq_path = sprintf('%s%s%s%d', work_dir, filesep, sq_root,sq_num);

%Filenames after moving
mrc_file_name_new = sprintf('%s%s%s%d%s', sq_path, filesep, mrc_root, sq_num, mrcfile_ext);

mdoc_file_name_new = sprintf('%s%s%s%d%s', sq_path, filesep, mrc_root, sq_num, mdocfile_ext);

lm_file_name_new = sprintf('%s%s%s%d%s', sq_path, filesep, LM_root, sq_num, tiffile_ext);


%make sq folder and move files, if no sorting option is checked the script
%does not move the LM file
if exist(mrc_file_name_old)&& exist(mdoc_file_name_old) == 2
mkdir (sq_path);
movefile(mrc_file_name_old,mrc_file_name_new, 'f');
movefile(mdoc_file_name_old,mdoc_file_name_new, 'f');
else 
    out = sprintf('no files');
    return 
end    
    
if nosorting_LM == 1
    if exist(lm_file_name) == 2
    movefile(lm_file_name,lm_file_name_new, 'f');
    else
            out = sprintf('no files');
        return
    end
end


% Blend the montage
  % Construct some additional filenames
  piecesList = [sq_path, filesep, sq_root, num2str(sq_num), '.pl'];
  edgesRoot = [sq_path, filesep, sq_root, num2str(sq_num)];
  mrcOutput = [sq_path, filesep, sq_root, num2str(sq_num), '_autoblend', mrcfile_ext];
  tifMontage = [sq_path, filesep, sq_root, num2str(sq_num), tiffile_ext];
  tifStack = [sq_path, filesep, sq_root, num2str(sq_num), '_stack', tiffile_ext];
  
  % Run extractpieces to get .pl file
  extractpieces = sprintf('extractpieces %s %s', mrc_file_name_new, piecesList);
  disp(['Executing ', extractpieces]);
  system(extractpieces);
  
  
  % Run blendmont
  blendmont = sprintf('blendmont -imi %s -plin %s -imout %s -rootname %s -v -ori -robust 1.0',...
      mrc_file_name_new, piecesList, mrcOutput, edgesRoot);
  disp(['Executing ', blendmont]);
  system(blendmont);
  
  
  % Convert to tif the blended montage using system command line
  mrc2tifb = sprintf('mrc2tif %s %s', mrcOutput, tifMontage);
  system (mrc2tifb);
  
  % Convert to tif the initial stack using system command line
  mrc2tifs = sprintf('mrc2tif -s %s %s', mrc_file_name_new, tifStack);
  system (mrc2tifs);
  
  % display it's done in the GUI
   out = sprintf('Blending sq%d is done',sq_num);    
end