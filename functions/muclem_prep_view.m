function out = muclem_prep_view(chlist, work_dir, sr, panel_size, EMscale, mrc_root)
% Crops separate cell images out of original data and puts in one folder in
% reduced size (determined by panel size in the browser options). It
% searches for all the folders named sq* and in each of them locates
% bleneded EM montage, a file with coordinates for each cell, and transformed
% LM data. All folders that have all of the above files are processed - a
% new folder called 'browser_imgs' is created in the working directory
% (already existing one is overwritten). The function also looks for at
% least one mdoc file to determine pixel size of the EM data. If such file
% doesn't exist, it offers the user to enter the pixel size manually. If you
% don't remember it, try something around 4 for medium magninfication EM.
% Background of the LM data is subtracted with the same parameter as used
% for step 7 (set the structural element radius in panel 7 of the settings
% tab). It shoold be on the scale of one yeast cell (5 micron). The number
% and order of LM channels is determined by the corresponding field in tab
% 7, it should be the same as you used for barcode determination.
% Do not use it to crop images of big size, because all original images are
% read at the same time and stored in memory!
%
%   MultiCLEM scripts
%   Yury Bykov and Nir Cohen, 2018

%work_dir = '/Users/yuryb/Documents/phd/test';
%EMscale=0.25;
%chlist = [1 2 3 4];
%slist = [1 2 3];
%mrc_root = 'mm';
%r1_pix = 100;
%sr = 10; % microns
%panel_size = 120;

%rd = 0.5; % resizing factor for saved images

%% Initialize
% hardcoded parameters and names

cz_micron = 6; % side of the cropped image in microns 
subtractbg = 1;
showim = 0;
outfolder = [work_dir, filesep, 'browser_imgs'];
sq_root = 'sq';

%% Check which squares are there

% make a sq list
pre_slist = [];

for n=1:100 % it can never be more than 100...
    foldername = [work_dir, filesep, sq_root, num2str(n)];
    if exist(foldername, 'dir')==7
        pre_slist = [pre_slist n];
    end
end

% In case of an error
if isempty(pre_slist)
    msg = ['Grid square folders not found in folder ', work_dir];
    disp(msg)
    out = msg;
    return
end

pre_nsq = size(pre_slist,2);
nch = size(chlist,2);

disp(['Found ', num2str(pre_nsq), ' grid square folders.'])
%% Check which folders have which files
% .mdoc file
% _Montage_centroids.txt file
% sqN.tif
% transformed LM for each channel (nch) 

checkfiles = zeros([pre_nsq 3+nch]); % rows - squares, cols - filetypes

for n=1:pre_nsq
    mdocname = [work_dir, filesep, sq_root, num2str(pre_slist(n)), filesep,...
       mrc_root, num2str(pre_slist(n)), '.mrc.mdoc'];
    centrname = [work_dir, filesep, sq_root, num2str(pre_slist(n)), filesep,...
       sq_root, num2str(pre_slist(n)), '_Montage_centroids.txt'];
    emname = [work_dir, filesep, sq_root, num2str(pre_slist(n)), filesep,...
       sq_root, num2str(pre_slist(n)), '.tif'];
   
   checkfiles(n, 1:3) = [exist(mdocname, 'file')==2 ...
       exist(centrname, 'file')==2 ...
       exist(emname, 'file')==2];
   
   lmchk = zeros([1 nch]);
   for c=1:nch
       lmname = [work_dir, filesep, sq_root, num2str(pre_slist(n)), filesep,...
           sq_root, num2str(pre_slist(n)), '_LMtoEM_ch_', num2str(chlist(c)), '.tif'];
       lmchk(c) = exist(lmname, 'file')==2;
   end
    
   checkfiles(n,4:end) = lmchk;
   
end

disp('Files: Sq / mdoc / centr / MM / LM ')
disp([pre_slist' checkfiles])

%% Find pixelsize

if sum(checkfiles(:,1))==0
    answer = inputdlg(['There are no mdoc files under the name sq*/', ...
        mrc_root, '*.mrc.mdoc. Enter the pixelsize (in nm) below or press',...
        ' Cancel and copy mdoc file in one of the sq* folders']);
    if isempty(answer)
        disp('Copy mdoc file in one of the sq* folders and start again.')
        out = 'Failed. Copy mdoc file in one of the sq* folders and start again.';
        return
    else
        pixelsize = eval(answer{1});
    end
    
else
    % Find the first existing mdoc file
    havemdocs = pre_slist((checkfiles(:,1)==1)');
    first = havemdocs(1);
    mdoc_file = [work_dir, filesep, sq_root, num2str(first), filesep,...
       mrc_root, num2str(first), '.mrc.mdoc'];
   
   % retrive pixelsize
    datta = textscan(fopen(mdoc_file),'%s');
    pixelsize = str2double(datta{1,1}(3))/10;
    
end

disp(['Pixel size ', num2str(pixelsize), ' nm'])
%% Calculate pixelsize-dependent parameters
% After reading the data they are to be immediately downscaled to the same
% resolution as final cropped images
% MM montage needs to be downscaled from original size to a factor that
% makes 6 micron hard-coded crop size to span for panel_size
% All other things are to be downscaled less (divide by EMscale)

cz = round(panel_size); % crop size in pixels will be exactly panel_size
target_ps = cz_micron*1000/cz; % Pixel size of the final cropped image

% Resizing factors
MMfactor = pixelsize/target_ps; % To resize the original EM montage
LMfactor = (pixelsize/EMscale)/target_ps; % To resize all other images and cell coordinates 

% LM Backgroud subtraction element radius (after resizing LM to target_ps)
r1_pix = round(sr*1000/(target_ps)); 

%% Decide which squares to crop

needfiles = size(checkfiles, 2)-1; % how many files needed for cropping (mdoc not needed)
have_all = sum(checkfiles(:,2:end), 2) == needfiles;

% final list of squares
slist = pre_slist(have_all');

if isempty(slist)
    msg = ['The image files were not found in the folder ', work_dir,...
        '. Check if all filenames are correct'];
    disp(msg);
    msgbox(msg);
    out = msg;
    return
else
    disp('Will crop images for squares:')
    disp(slist)
end

%% Preallocate cell arrays to store filenames for each square

nsq = size(slist,2);
lmnames = cell([nsq nch]);
centroidsnames = cell([nsq 1]);
emnames = cell([nsq 1]);

% Store names for data to read
for n=1:nsq
% squares can go in any order in the list, output will have them correct
   %Centroids
   centroidsnames{n} = [work_dir, filesep, sq_root, num2str(slist(n)), filesep,...
       sq_root, num2str(slist(n)), '_Montage_centroids.txt'];
   % EM
   emnames{n} = [work_dir, filesep, sq_root, num2str(slist(n)), filesep,...
       sq_root, num2str(slist(n)), '.tif'];
   % LM
   for c=1:nch
       lmnames{n,c} = [work_dir, filesep, sq_root, num2str(slist(n)), filesep,...
           sq_root, num2str(slist(n)), '_LMtoEM_ch_', num2str(chlist(c)), '.tif'];
   end
   
end

%% Read data
% Preallocate variables to store data

allLM = cell([nsq 1]); %Cell array of 3d arrays (stores LM data)
allCt = cell([nsq 1]); %Cell array of 2d arrays (stores centroids)
allEM = cell([nsq 1]);

% Read square images and already resize to final resolution and rescale
% centroids too using LMfactor and MMfactor (EM only)
for n=1:nsq
   
    %LM
    lm_tf = []; % Make one square
    for c=1:nch
        
        disp(['Reading LM - square ', num2str(slist(n)), ' channel ', num2str(c)])
        
        % read and resize
        I = imresize(imread(lmnames{n,c}), LMfactor);
        
        % subtract background
        if subtractbg==1
            lm_tf(:,:,c) = I - imopen(I, strel('disk', r1_pix));
            if showim==1&&n==1
                imtool([I, lm_tf(:,:,c)]);
            end
        else
            lm_tf(:,:,c) = I;
        end
    end
    
    allLM{n} = lm_tf; % write to cell array
    
    % Centroids
    allCt{n} = dlmread(centroidsnames{n}).*LMfactor;
    
    % EM
    disp(['Reading EM - square ', num2str(slist(n))])
    EM_tmp = imresize(imread(emnames{n}), MMfactor);
    allEM{n} = EM_tmp; 
    disp([num2str(n), ' :loaded square ', num2str(slist(n))])
end


%% Check if folder to store the images exists and rewrite it in case it does
if exist(outfolder)==0
    mkdir(outfolder);
else
    disp('The folder exists. Overwriting.')
    system(['rm -rf ', outfolder]);
    mkdir(outfolder);
end

%% Cropping

disp('Starting cropping and sorting cells!!!11')
cellcount = 0;

for s=1:nsq
    allct_table = allCt{s}; % all centroids for the suqare
    ncells = size(allct_table, 1);
    [M, LM] = muclem_norm_lm(allLM{s}, 0);
    EM = allEM{s};
    
    for n=1:ncells
        %define cropping rectangle; for this we need to find
        %coordinates in allCt cell array
        croprect = [allct_table(n,1)-round(cz/2)...
            allct_table(n,2)-round(cz/2) cz cz];
        
        % LM
        
        for c=1:nch
            clear I2
            I2 = uint8(round(imcrop(LM(:,:,c), croprect)));
            lmname = sprintf('%s%sLM_%02d_%03d_%d.tif', ...
                outfolder, filesep, slist(s), n, chlist(c));
            imwrite(I2,lmname);
        end
        
        
        % EM
        clear I1
        % crop
        I1_crop = double(imcrop(EM, croprect));
        
        %contrast
        immax = max(max(I1_crop));
        immin = min(min(I1_crop));
        imrange = immax - immin;
        I1_contr = ((I1_crop-immin)./imrange).*255;
        
        % 8 bit
        I1 = uint8(round(I1_contr));
        
        % save
        emname = sprintf('%s%sEM_%02d_%03d.tif', ...
            outfolder, filesep, slist(s), n);
        imwrite(I1,emname);
        if mod(n,50)==0
                disp(['Saved cell ', num2str(n), '/', num2str(ncells)])
        end
    end
    
end

out = sprintf('%d cells cropped and saved for squares %2d', ncells, slist);
disp('Finished cropping')
end
