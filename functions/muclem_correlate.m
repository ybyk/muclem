function [out] = muclem_correlate(sqnum, work_dir, EMscale, dev_mode, transformtype, custom_norm, lmroot, do_em2lm, fliplm)
% yura_correlate_yeast_and_make_masks(montagename, lmname, EMscale, nchannels, transformtype, custom_norm)
%   The function just calls standard matlab control point selection tool and registration functions to
%   correlate light microscopy image of the grid square with the EM map.
%   Saves picked points as text files, em-to-lm transform object as
%   tform_em2lm.mat, and the transformed em image as . For better contrast use EM montage converted to 8 bit,
%   run the script from the square subdirectory. Transformtype: try 'affine'
%   LM data should be tiff stack with number of slices equal to
%   nchannels; the script just reads those sequentially.
%   If custom_norm=1 data should be 16-bit (actually 12) with the range of intensities 0-4095
%   The script will normalize the data for viewving (only! no meausurements on those, please) and save as
%   8-bit images for separate channels and maximum projection for the whole
%   stack.
%   If custom_norm=0 the script will just use the image provided as is and
%   will display its maximum projections. no images will be saved
%
% -Yura, Nov 2016
%   added transform LM and save to tif files
%   the the LM save part were changed to tiff lib to allow save of multi
%   color image
%      -nir april 2017
%   v4: proper file names added (no need to cd), added option to do EM->LM 
%   transform (in this case loads cell wall masks .mat file and transforms it too),
%   option to flip LM data, conversion of EM data to 8 bit for nice display
%   all data is saved as 16-bit
%       -yura june 2017
%
%

%% Initialize
% Test parameters
% sqnum=1;
% custom_norm = 1;
% transformtype = 'affine';
% nchannels = 4;
% EMscale = 0.25;
% lmroot = 'lm';
% work_dir = '/net/bstore1/bstore1/briggsgrp/ybykov/yeasthtp/wine/realdata/grid1/sq1_guitest';
% do_em2lm = 1;
% fliplm = 0;

sq_root = 'sq';

% Input filenames
montagename = [work_dir, filesep, sq_root, num2str(sqnum), filesep, sq_root, num2str(sqnum), '.tif'];
lmname = [work_dir, filesep, sq_root, num2str(sqnum), filesep, lmroot, num2str(sqnum), '.tif'];
% if exists
cw_idxs = [work_dir, filesep, sq_root, num2str(sqnum), filesep, sq_root, num2str(sqnum), '_CW_MASK_IDXS.mat']; 
corr_em_masks_im = [work_dir, filesep, sq_root, num2str(sqnum), filesep, sq_root, num2str(sqnum), '_all_corr_EM_masks.tif'];

% Output filenames
norm_lm_name = [work_dir, filesep, sq_root, num2str(sqnum), filesep, lmroot, num2str(sqnum), '_norm_ch_'];
empointsname = [work_dir, filesep, sq_root, num2str(sqnum), filesep, sq_root, num2str(sqnum), '_picked_EM_points.txt'];
lmpointsname = [work_dir, filesep, sq_root, num2str(sqnum), filesep, sq_root, num2str(sqnum), '_picked_LM_points.txt'];
transformname1 = [work_dir, filesep, sq_root, num2str(sqnum), filesep, sq_root, num2str(sqnum), '_tform_lm2em'];
transformname2 = [work_dir, filesep, sq_root, num2str(sqnum), filesep, sq_root, num2str(sqnum), '_tform_em2lm'];
em_tr_name = [work_dir, filesep, sq_root, num2str(sqnum), filesep, sq_root, num2str(sqnum), '_EMtoLM.tif'];
lm_tr_root = [work_dir, filesep, sq_root, num2str(sqnum), filesep, sq_root, num2str(sqnum), '_LMtoEM_ch_'];

%% Read and normalize data for viewing
disp('Reading EM montage...');
emmontage = imresize(imread(montagename), EMscale);
em_display = uint8(round(255.*double(emmontage-min(min(emmontage)))./double(max(max(emmontage))))); % 8bit version for display

disp('Reading LM data...')
%LM: check size, and number of channels
infostructlm = imfinfo(lmname);
lmw = infostructlm(1).Width;
lmh = infostructlm(1).Height;
[emh, emw] = size(emmontage);
nchannels = size(imfinfo(lmname),1);
% Read LM data
lm = zeros([lmh lmw nchannels]);
 for c = 1:nchannels
     lm(:,:,c) = imread(lmname, c);
 end
 
% Normalize if needed or just calculate max projection of all channels
if custom_norm==1
    [lmn, normalno] = muclem_norm_lm(lm, 0); % this function does something simple in a very complicated way... can be improved
    % [normalized max projection, norm by channel (stack)]
    
    % Write each channel of normalized image
    for n=1:nchannels
        imwrite(normalno(:,:,n), [norm_lm_name, num2str(n), '.tif']);       
    end
    
else
    lmn = max(lm, [], 3); % max projection
    normalno = lm; % stack
end
    
% Flip LM image if required
% i add a 8bit convertion 
if fliplm==1
   normalno = rot90(fliplr(normalno),2);
   lmn = rot90(fliplr(lmn),2);
   lm = rot90(fliplr(lm),2);
   disp('LM image was flipped')
end

disp('Reading cell wall masks...');
if exist(corr_em_masks_im, 'file')~=0
    all_cw = imread(corr_em_masks_im)==255; % convert to logical from start
    disp('Image with all masks found!')
else
    disp('No image with all masks')
    all_cw = [];
end

if do_em2lm==1
    disp('To do EM->LM we will also need the .mat file!')
    if exist(cw_idxs, 'file')~=0
        load(cw_idxs);
        CW_IDX = sel_idx;
        disp('Cell wall index .mat file found');
    else
        disp('No cell wall index .mat file');
        CW_IDX = [];
    end
end

disp('Done reading');

%% Launch control point selection and correlate!
 docorr = 1;
 while docorr==1     
     if dev_mode == 1  
     choice = questdlg('Load ready transforms or correlate?', 'Question', 'Load', 'Correlate', 'Exit', 'Exit');
     % Handle response
     switch choice
         case 'Load'
             loadtransforms = 1;
         case 'Correlate'
             loadtransforms = 0;
         case 'Exit'
             disp('Exit')
             
             break
     end
     elseif dev_mode == 0
         loadtransforms = 0;
     end
     
     if loadtransforms == 0
     % open cpselect interface and calculate transforms
     [lm_points, em_points] = cpselect(lmn, em_display, 'Wait', true);
     
     % In case testing needed, run it once with dlmwrite uncommented and
     % then use the written files
     %dlmwrite(lmpointsname, lm_points);
     %dlmwrite(empointsname, em_points);
     %lm_points=dlmread(lmpointsname);
     %em_points=dlmread(empointsname);
       
     % transform steps, LM->EM is default
     % 1.Creae transform object
     tform_lm2em = fitgeotrans(lm_points,em_points, transformtype);
     
     
     elseif loadtransforms == 1
         % load tfransform saved in a .mat file
         [transformfile,didir] = uigetfile(work_dir);
         tform_lm2em_str = load([didir, transformfile]);
         tform_lm2em = tform_lm2em_str.(char(string(fieldnames(tform_lm2em_str))));
     end
     % 2. Create size reference object
     emrefobj = imref2d([emh emw]); % create size reference object
     % 3. Transform original channel stack and max projection
     lmstack_tr = imwarp(lm, tform_lm2em, 'FillValues', 0, 'OutputView', emrefobj);
     lmmax_tr = imwarp(lmn, tform_lm2em, 'FillValues', 0, 'OutputView', emrefobj);
     % show the result, add cell wall masks if they exist
     if ~isempty(all_cw)
        masksoutl = bwperim(all_cw);
        [r, c] = find(masksoutl==1);
        fi = figure;
        imshowpair(lmmax_tr, em_display, 'falsecolor', 'colorChannels', [1 2 2])
        hold on
        plot(c, r, 'y.', 'MarkerSize', 3)
     else
        imshowpair(lmmax_tr, em_display, 'falsecolor', 'colorChannels', [1 2 2])
     end
     
     % optional EM->LM
     if do_em2lm==1
         if loadtransforms == 0
        tform_em2lm = fitgeotrans(em_points, lm_points, transformtype);
         elseif loadtransforms == 1
             tform_em2lm = tform_lm2em;
         end
        lmrefobj = imref2d([lmh lmw]);
        em_tr = imwarp(emmontage, tform_em2lm, 'FillValues', 0, 'OutputView', lmrefobj);
        em_tr_disp = imwarp(em_display, tform_em2lm, 'FillValues', 0, 'OutputView', lmrefobj);
        figure
        imshowpair(lmn, em_tr_disp, 'falsecolor')
     end

     % Ask if it's ok          
     choice = questdlg('Are you happy? (with correlation)');
     % Handle response
     switch choice
         case 'Yes'
             docorr = 0;
         case 'No'
             docorr = 1;
             disp('Trying again!')
         case 'Cancel'
             disp('Exited without saving any files.')
             break
     end
     
          
 end
 
 %% Convert maks from EM to LM coordinates if option EM->LM was selected

 if do_em2lm==1 && docorr==0
     % pre-initialize blank images and array
     ncells = size(CW_IDX, 1);
     LM_IDXS = cell([ncells 1]);
     temp_em = zeros(size(emmontage));
     temp_lm = zeros(size(lmn));
     allmasks_lm = zeros(size(lmn));
     
     
     for n=1:ncells
         % draw mask on EM-sized image, transform to LM and find
         % indexes again, add to the image of all masks
         temp_em(CW_IDX{n}) = 1;
         temp_lm = imwarp(temp_em, tform_em2lm, 'FillValues', 0, 'OutputView', lmrefobj);
         LM_IDXS{n} = find(temp_lm>=0.90);
         allmasks_lm = allmasks_lm + temp_lm>=0.9;
         %set images to 0
         temp_lm(:,:) = 0;
         temp_em(:,:) = 0;
         
         
         if (mod(n, 50)==0)||(n==1)||(n==ncells)
             disp(['Converted mask #', num2str(n)])
         end
         
     end
     figure
     imshowpair(lmn, bwperim(allmasks_lm), 'falsecolor')
     
     choice = questdlg('And now?');
     % Handle response
     switch choice
         case 'Yes'
             docorr = 0;
         case 'No'
             docorr = 1;
         case 'Cancel'
             disp('Exit')
             %break;
     end
     
 end
 %% save files only if the user is happy with correlation
 if docorr==0 
     if dev_mode == 0 
      dlmwrite(empointsname, em_points);
      disp(['Clicked EM points saved as ', empointsname]) 
      dlmwrite(lmpointsname, lm_points);
      disp(['Clicked LM points saved as ', lmpointsname]) 
      
      save(transformname1, 'tform_lm2em');
      disp(['Transformation object saved as ', transformname1, '.mat'])
     else
     end
      % if EM->LM option was selected
      if do_em2lm==1
          % transform .mat
          save(transformname2, 'tform_em2lm');
          disp(['Transformation object saved as ', transformname2, '.mat'])
          % image
          t = Tiff(em_tr_name,'w');
          t.setTag('ImageLength',double(lmh));
          t.setTag('ImageWidth',double(lmw));
          t.setTag('Photometric',Tiff.Photometric.MinIsBlack);
          t.setTag('Compression',Tiff.Compression.None);
          t.setTag('BitsPerSample',16);
          t.setTag('PlanarConfiguration',Tiff.PlanarConfiguration.Chunky);
          t.write(uint16(em_tr));
          t.close();
      end
      
      % LM image, each channel
      for n=1:nchannels
          t = Tiff([lm_tr_root, num2str(n), '.tif'],'w');
          t.setTag('ImageLength',double(emw));
          t.setTag('ImageWidth',double(emh));
          t.setTag('Photometric',Tiff.Photometric.MinIsBlack);
          t.setTag('Compression',Tiff.Compression.None);
          t.setTag('BitsPerSample',16);
          t.setTag('PlanarConfiguration',Tiff.PlanarConfiguration.Chunky);
          t.write(uint16(round(lmstack_tr(:,:,n))));
          t.close();
      end
      disp('Output saved');
      
 end
 out = sprintf('correlation for square %d is done',sqnum);
end

