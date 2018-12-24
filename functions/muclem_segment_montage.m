function [out] = muclem_segment_montage(sqnum,EMscale,holesize,wshH,area_min,circ_min,...
    work_dir, mrc_root, lbl_cells, lbl_holes, lbl_black, show_more, r1, dilate)
%based on yury script the sq loop is moved to the GUI  and all of the
%parameters are changed to be the same as the rest of the scripts
% changed to work in a pipline 
% nir april 2017
% Version4 - incorporates all code from separate functions, as inputs uses
%   pixelsize and absolute sizes in um^2 and nm, has option to show all
%   intermediate processing steps. Also includes creation and correction of cell wall masks
%   for intersection with neighbouring cell walls. Excludes transformation
%   to stage coordinates. This should be a separate step.
%   -yura 05.2017
%	V4_1 gets pixelsize from the mdoc file 

% Test parameters
% pixelsize = 5.02; % nm/pix
% sqnum = 1;
% EMscale = 0.2;
% holesize = 0.5; % in microns^2
% wshH = 1;
% area_min = 1.0; % in microns^2
% circ_min = 0.8;
% work_dir = '/net/bstore1/bstore1/briggsgrp/ybykov/yeasthtp/wine/realdata/grid1/sq1_guitest';
% lbl_cells = 1;
% lbl_holes = 2;
% lbl_black = 4;
% show_more = 1;
% r1 = 300;
% dilate = 200;

sq_root = 'sq';

% get pixelsize from mdoc file
sq_path = sprintf('%s%s%s%d', work_dir, filesep, sq_root,sqnum);
mdoc_file_name_new = sprintf('%s%s%s%d%s', sq_path, filesep, mrc_root, sqnum, '.mrc.mdoc');
datta = textscan(fopen(mdoc_file_name_new),'%s');
pixelsize = str2double(datta{1,1}(3))/10;

% Calculate parameters in pixels
holesize_px = round((EMscale^2)*holesize*(10^6)/(pixelsize^2));
area_min_px = round((EMscale^2)*area_min*(10^6)/(pixelsize^2));
r1_px = round((EMscale)*r1/(pixelsize));
dilate_px = round((EMscale)*dilate/(pixelsize));
disp(['Cell wall dilation structural element radius is ', num2str(dilate_px), ' pix'])

% Construct filenames
% read
in_ilastik = [work_dir, filesep, sq_root, num2str(sqnum), filesep, sq_root, num2str(sqnum), '_Simple Segmentation.tif'];
inmontage = [work_dir, filesep, sq_root, num2str(sqnum), filesep, sq_root, num2str(sqnum), '.tif'];
% write
out_im_centroids = [work_dir, filesep, sq_root, num2str(sqnum), filesep, sq_root, num2str(sqnum), '_Montage_centroids.txt'];
out_all_objects = [work_dir, filesep, sq_root, num2str(sqnum), filesep, sq_root, num2str(sqnum), '_All_objects_statistics'];
out_cw_idxs = [work_dir, filesep, sq_root, num2str(sqnum), filesep, sq_root, num2str(sqnum), '_CW_MASK_IDXS'];
out_bin_em = [work_dir, filesep, sq_root, num2str(sqnum), filesep, sq_root, num2str(sqnum), '_watershed.tif'];
corr_em_masks_im = [work_dir, filesep, sq_root, num2str(sqnum), filesep, sq_root, num2str(sqnum), '_all_corr_EM_masks.tif'];
out_bb = [work_dir, filesep, sq_root, num2str(sqnum), filesep, sq_root, num2str(sqnum), '_EMscaled_selected_boundigB.txt'];

%instack = [work_dir, filesep, sq_root, num2str(sqnum), filesep, sq_root, num2str(sqnum), '_stack.tif'];
%mdocname = [work_dir, filesep, sq_root, num2str(sqnum), filesep, mrc_root, num2str(sqnum), '.mrc.mdoc'];
%out_stage_centroids = [work_dir, filesep, sq_root, num2str(sqnum), filesep, sq_root, num2str(sqnum), '_Stage_centroids.txt'];

%% 1.Read in data
% Import segmentation, get binary of each label, resize
disp('Reading segmentation..')
I = imread(in_ilastik);

disp('Making binary image...')
bin_cells = imresize(I==lbl_cells, EMscale);
bin_holes = imresize(I==lbl_holes, EMscale);
bin_black = imresize(I==lbl_black, EMscale);
disp('Done')

%% 2.Smoothen and segent cell image
disp('Finding cells...')

%replaces EMcells = myclem_find_cells_in_em(iCells, r1, r2, holesize, wshH);

% clean up small things inside the cells
cells_cleaned= bwareaopen(~bin_cells, holesize_px);

% smoothen and round the cells with semi-random morphological operations
cells_op = imopen(~cells_cleaned, strel('diamond', r1_px));

if show_more==1
    figure
    imshow(bin_cells, [ ]);
    title('Original from ilastik');
    figure
    imshow(cells_cleaned, [ ]);
    title('Holes cleaned up');
    figure
    imshow(cells_op, [ ]);
    title('Opened');
end

%replaces EMcells = myclem_watershed_seg(dlop_cl_cl4, wshH, 0);
% Distance transform
D = -bwdist(~cells_op, 'euclidean');
% Correct the distance transform
ext_mask = imextendedmin(D, wshH);
D2 = imimposemin(D, ext_mask);
% Do watershed
linii = watershed(D2);
cells_wsh = cells_op;
cells_wsh(linii == 0) = 0;

if show_more == 1
    imtool(cells_wsh)
end

% Write out final segmentation for trouble shooting
imwrite(255.*cells_wsh, out_bin_em);
%% 3.Find objects in segmentation

%replaces [sel_idx, out_ctrs] = myclem_analyze_mm_cells(EMcells, area_min, circ_min, './', 1);

% get info about all objects
STATS = regionprops(cells_wsh, 'Area', 'Centroid', 'MajorAxisLength', 'MinorAxisLength', 'Perimeter', 'PixelIdxList', 'BoundingBox');

% make simpler data out of structure
nobj = size(STATS, 1);
all_area = zeros([nobj 1]);
all_ctrds = zeros([nobj 2]);
all_maja = zeros([nobj 1]);
all_mina = zeros([nobj 1]);
all_perim = zeros([nobj 1]);
all_idx = cell([nobj 1]);
all_bb = zeros([nobj 4]);


for i=1:nobj
    all_area(i) = STATS(i).Area;
    all_ctrds(i,:) = STATS(i).Centroid;
    all_maja(i) = STATS(i).MajorAxisLength;
    all_mina(i) = STATS(i).MinorAxisLength;
    all_perim(i) = STATS(i).Perimeter;
    all_idx{i} = STATS(i).PixelIdxList;
    all_bb(i,:) = STATS(i).BoundingBox;

end

%% 4.Make image of holes and black things 

%Process holes in a way similar to find_cells_in_emto find their outlines
% clean up small things inside the holes
holes_cleaned= bwareaopen(~bin_holes, holesize_px);

% smoothen and round the cells with semi-random morphological operations
holes_op = imopen(~holes_cleaned, strel('diamond', r1_px));

if show_more==1
    figure
    imshow(bin_holes, [ ]);
    title('Original from ilastik');
    figure
    imshow(holes_cleaned, [ ]);
    title('Holes cleaned up');
    figure
    imshow(holes_op, [ ]);
    title('Opened');
end

% clean up small things inside the holes
black_cleaned= bwareaopen(~bin_black, holesize_px);

% smoothen and round the cells with semi-random morphological operations
black_op = imopen(~black_cleaned, strel('diamond', r1_px));

if show_more==1
    figure
    imshow(bin_black, [ ]);
    title('Original from ilastik');
    figure
    imshow(black_cleaned, [ ]);
    title('Holes cleaned up');
    figure
    imshow(black_op, [ ]);
    title('Opened');
end

non_cells = black_op|holes_op;
non_c_op = imclose(non_cells, strel('diamond', r1_px));
noncells_per = bwperim(non_c_op);

noncells_masks = imdilate(noncells_per, strel('diamond', dilate_px));
if show_more==1
    figure
    imshow(noncells_masks)
    title('Outlines of holes')
end

%% 5.Create masks for all objects in case some cells will be later filtered out based on circularity or size

%create cell wall masks and store their indexes for EM-sized image

%De=strel('diamond', erodestrel);
%Dd=strel('diamond', dilatestrel);

tempim = zeros(size(noncells_masks));
tempmask = tempim;
allmasks = tempim;
ncells = size(all_idx, 1);


EM_IDXS = cell([ncells 1]);


disp('Making masks.This will take some time...');

for n=1:ncells
    if n==1 
        tic
    end
    tempim(all_idx{n}) = 1;
    %tempmask=imdilate(tempim, Dd)-imerode(tempim, De);
    tempmask = imdilate(bwperim(tempim), strel('diamond', dilate_px)); % simplified mask (jusy dilating an outline) 
    EM_IDXS{n} = find(tempmask==1); % save indexes
    
    allmasks = allmasks + tempmask;
    
    tempim(:,:) = 0;
    tempmask(:,:) = 0;
    
    % Progress report
    if (mod(n, 50)==0)||(n==ncells)
        a=toc;
        timeleft = (ncells-n)*a/(50);
        disp(['Made mask #', num2str(n), '/', num2str(ncells), '. Est.time left ', num2str(round(timeleft)), ' sec'])
        tic
    end
    
end

% add sum of all cell wall masks and all hole walls
allmasks = allmasks + noncells_masks; % all overlapping things should have value >=2

% find intersections in sum (every pixel >1)
isect_i = find(allmasks>1); 
EM_IDXS_COR = cell([ncells 1]);
all_fin_i = [];
for n=1:ncells
      
    EM_IDXS_COR{n} = setdiff(EM_IDXS{n}, isect_i);      %find mask pixels not overlapping with any intersections
    
    all_fin_i = [all_fin_i; EM_IDXS_COR{n}];            %also join all idxs in array for display
    
    % Progress
    if (mod(n, 100)==0)||(n==1)||(n==ncells)
        disp(['Corrected mask #', num2str(n)])
    end
end

% Make image with all overlapping masks for display
tempim(all_fin_i)=1;

if show_more ==1
    imtool(allmasks)
    imtool(tempim)
end

imwrite(255.*tempim, corr_em_masks_im);
%% Select objects based on size and circularity
%calculate circularity
all_circ = 4*pi*(all_area./(all_perim.^2));

%filter particles by area and circularity
selected_obj = find((all_area>area_min_px)&(all_circ>circ_min));

nselected = size(selected_obj, 1);
disp(['Selected ', num2str(nselected), ' objects out of ', num2str(nobj)]);


% show if needed
if show_more==1
    figure
    disp('Displaying final selection. Reading montage...')
    montage_orig = imresize(imread(inmontage), EMscale);
    imshow(montage_orig);
    hold on
    plot(all_ctrds(selected_obj,1), all_ctrds(selected_obj,2), 'go', 'MarkerSize', 10);% code
    title('Result of segmentation and object selection')
end

% save centroids for selected objects
im_centroids = all_ctrds(selected_obj,:);
dlmwrite(out_im_centroids, im_centroids);

dlmwrite(out_bb, all_bb(selected_obj,:));

% save original non-filtered structure, in case someone likes to look into it
save(out_all_objects, 'STATS');

% select save cell wall indexes 
sel_idx = EM_IDXS_COR(selected_obj);
save(out_cw_idxs, 'sel_idx');

out = ['Finished with cells on square ', num2str(sqnum)];
end













