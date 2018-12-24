function [] = muclem_autoblend_win()
%myclem_auto_blend_mm_winnonv2 
%auto blend for windows using imod and cygwin
%imod 4.7.15 64 bit and cygwin for imod ia attached to the package
%converted of linuxfrendly, multifile version, only mrc file input
%nir cohen 25.3.17
[mrcfile,folder_name] = uigetfile('*.mrc','Select the montage mrc file','MultiSelect','on');
cd(folder_name);
if iscell(mrcfile) == 1
    sizeof = length(mrcfile);
else 
      sizeof = 1;
end

for i=1:sizeof
    if iscell(mrcfile) == 0
    tmrc = mrcfile;
    else 
    tmrc = strjoin(mrcfile(i));
    end
mdocfile = sprintf('%s.mdoc',tmrc);
[token, remain] = strtok(tmrc,'.');
mkdir (token);
new_pathmrc = sprintf('%s%s%s',token,filesep,tmrc);
new_pathmdoc= sprintf('%s%s%s',token,filesep,mdocfile);
movefile( tmrc,new_pathmrc);
movefile( mdocfile,new_pathmdoc);
% Blend the montage cut images for ilastik
  % Blend the montage
  newf = sprintf('%s%s%s',folder_name,filesep,token);
  cd(newf);
  extractpieces = sprintf('extractpieces %s.mrc %s.pl',token,token);
 dos(extractpieces);
  blendmont = sprintf('blendmont -ImageInputFile %s -PieceListInput %s.pl -ImageOutputFile %s_autoblend.mrc -RootNameForEdges %s -SloppyMontage -AdjustOrigin',tmrc,token,token,token);
 dos(blendmont);
  % Convert to tif the blended montage
  mrc2tifb = sprintf('mrc2tif %s_autoblend.mrc %s.tif',token,token);
  dos (mrc2tifb);
  
  % Convert to tif the initial stack
  mrc2tifs = sprintf('mrc2tif -s %s %s_stack.tif',tmrc,tmrc);
  dos (mrc2tifs);
  cd ..
end    

