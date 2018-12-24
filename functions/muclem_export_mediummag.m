%function out = muclem_export_mediummag(DBtablepath, chlist, work_dir,...
%    sr, cz_micron, rd, EMscale, mrc_root, included, approved)
% Crops separate cell images out of original data and puts in one folder in
% the original size.
% Substracts background in LM data using function for 12-bit data in the range of
% 0-4095.

%test setings
work_dir = '/Users/yuryb/Documents/phd/test';
DBtablepath = '/Users/yuryb/Documents/phd/test/DBtable1.txt';
EMscale=0.25;
chlist = [2];
mrc_root = 'mm';
cz_micron = 6; % side of the cropped image in microns
sr=2.5; % structured element size for background subtraction, micron
rd = 1; % How much to resize the images compared to the original EM resolution (1)
included = 0;
approved = 0;

%% Hardcoded parameters and names

subtractbg = 1;
showim = 0;
Keytablename = 'Keytable1.txt';
sq_root = 'sq';

% See if need to crop LM
if isempty(chlist)
    dolm = 0;
else
    dolm = 1;
end

%% DBtable and outfolder name

C1 = strsplit(DBtablepath, filesep);
DBname = C1{end}; % name with extension
C2 = strsplit(DBname, '.txt');
DBroot = C2{1}; % name without extension

outfolder = [work_dir, filesep, 'Exported_imgs_', DBroot];
subdir_root = 'LBL_' ; % how to name subfolders to sort cells by labels will be SUBDIR_ROOT followed by lbl digits

%% Read the DB table and count squares and cells that are selected
% DB table: columns: 1 - sq, 2 - cell, 3 - autolabel, 4 - manual label, 
% 5 - excluded (1 is excluded), 6 - approved (1 is approved)

DBtable  = dlmread(DBtablepath);

%kytable  = dlmread(sprintf('%s%s%s', work_dir, filesep,Keytablename));
%sizedb = size(DBtable,1);

% Strainght away merge labels from automatic and manual annotation
% Put them in column 4
DBtable_ml = DBtable;
DBtable_ml(DBtable(:,4)==0,4) = DBtable(DBtable(:,4)==0,3);

% Selecting cells based on approved/included tick boxes
if included && approved
    sel_idx = (~DBtable(:,5)) & DBtable(:,6); % select only approved and not excluded 
    
elseif (~included) && approved
    sel_idx = DBtable(:,6); % select all approved
    
elseif included && (~approved)
    sel_idx = ~DBtable(:,5); % select all not excluded including also not approved
    
elseif (~included) && (~approved)
    sel_idx = ones([size(DBtable,1) 1]); % select all cells in the table
end

sel_idx = logical(sel_idx);

totcells = sum(sel_idx); % total number of cells
sel_sqlist = unique(DBtable(sel_idx, 1)); % list of selected squares
nsq_sel = size(sel_sqlist,2); % number of squares
sel_labels = unique(DBtable_ml(:,4)); % list of all labels 

disp(['Need to crop ', num2str(totcells), ' cells from ', num2str(nsq_sel), ' squares']);

%% Pixelsize

pixelsize = [];
% look for mdoc everywhere, if not found pixelsize remains empty
for n=1:100
    mdoc_file = [work_dir, filesep, sq_root, num2str(n), filesep,...
        mrc_root, num2str(n), '.mrc.mdoc'];
    % find first existing mdoc
    if exist(mdoc_file, 'file')==2
        % retrive pixelsize and exit loop
        datta = textscan(fopen(mdoc_file),'%s');
        pixelsize = str2double(datta{1,1}(3))/10; % First line in the mdoc should be pixel size
        break
    end
end

if isempty(pixelsize)
     % ask user to type the pixel size or exit if no mdoc
        answer = inputdlg(['There are no mdoc files under the name sq*/ or their format is wrong', ...
            mrc_root, '*.mrc.mdoc. Enter the pixelsize (in nm) below or press',...
            ' Cancel and copy mdoc file in one of the sq* folders']);
        if isempty(answer)
            disp('Copy mdoc file in one of the sq* folders and start again.')
            out = 'Failed. Copy mdoc file in one of the sq* folders and start again.';
            return
        else
            pixelsize = eval(answer{1});
        end
end

disp(['Pixel size ', num2str(pixelsize), ' nm'])

% Final cropping size from the MM montage and LM data rescaled to the
% desired resolution (original EM resolutuion X rd factor)
cz = round(rd*1000*cz_micron/(pixelsize));

disp(['Cropped image size: ', num2str(cz), ' pixels / ', num2str(cz_micron), ' nm'])
%% Output folder
%check if output folder exist and eraze if it does
disp(['Creating folder ', outfolder])
if exist(outfolder, 'dir')==0
    mkdir(outfolder);
else
    disp('The folder exists. Overwriting.')
    rmdir(outfolder, 's');
    mkdir(outfolder);
end

% Make subfolders for labels
for lbl=sel_labels
    mkdir([outfolder, filesep, subdir_root, sprintf('%02d', lbl)]);
end


%% Crop for each square

for current_sq=sel_sqlist
    
    % Load data
    % EM montage, keep original size
    emname = [work_dir, filesep, sq_root, num2str(current_sq), filesep,...
        sq_root, num2str(current_sq), '.tif'];
    disp(['Reading EM - square ', num2str(current_sq)])
    EM_raw = imread(emname);
    % resize based on rd parameter
    EM = imresize(EM_raw, rd);
    
    % Centroids load and rescale by rd AND 1/EMscale
    centname = [work_dir, filesep, sq_root, num2str(current_sq), filesep,...
        sq_root, num2str(current_sq), '_Montage_centroids.txt'];
    centroids_lm = dlmread(centname); % original 'EMscaled'
    centroids_em = round(centroids_lm.*(rd/EMscale)); %
    
    % LM (if needed)
    lm_tf = [];
    if dolm==1
       % load channels in a stack
       for c=1:size(chlist,2)
           chname = [work_dir, filesep, sq_root, num2str(current_sq), filesep,...
            sq_root, num2str(current_sq), '_LMtoEM_ch_', num2str(chlist(c)), '.tif'];
        
           disp(['Reading LM channel ', num2str(chlist(c)), ' square ', num2str(current_sq)])
           
           % Read, do not resize
           lm_tf(:,:,c) = imread(chname);
       end
    end
    
    % Select cells, and selection indexes for current square
    DB_sq = DBtable_ml(DBtable_ml(:,1)==current_sq,:);
    sel_sq = sel_idx(DBtable_ml(:,1)==current_sq);
    
    % Make a final selection for cells to crop and their centroids
    DB_sq_sel = DB_sq(sel_sq==1,:);
    centr_sel = centroids_em(sel_sq==1,:);
    
    % Crop
    ncells = size(DB_sq_sel,1);
    disp(['Number of cells to crop: ', num2str(ncells)])
    
    % preallocate array to store image (as a stack of all channels + EM)
    if dolm
        nch = size(lm_tf, 3);
    else
        nch = 0;
    end
    
    I = int16(zeros([cz+1 cz+1 nch+1])); % cz+1 is strange but works 
    
    % For each cell!
    for n=1:ncells
        
        % coordinates for cropping
        croprect_em = [centr_sel(n,1)-round(cz/2)...
            centr_sel(n,2)-round(cz/2) cz cz];
        croprect_lm = round(croprect_em.*(EMscale/rd));
        
        % cell number in the square (ID that never changes)
        cell_id = DB_sq_sel(n,2);
        % Final label
        cell_label = DB_sq_sel(n,4);
        
        % Do with LM if needed
        if dolm
            for c=1:nch
                curr_ch = int16(imcrop(lm_tf(:,:,c), croprect_lm));
                I(:,:,c) = imresize(curr_ch, [size(I,1) size(I,2)]);
            end
        end
        
        % EM - to the last (or only z slice)
        curr_EM = int16(imcrop(EM, croprect_em));
        I(:,:,end) = curr_EM - min(min(curr_EM));
        
        % Construct filename
        imname = sprintf('%s%s%s%02d%ssq_%02d_cell_%03d.tif', ...
             outfolder, filesep, subdir_root, cell_label, filesep, current_sq, cell_id);
        
        saveastiff(I, imname);
        
        % Report progress once in a while
        if mod(n,50)==0
                disp(['Saved cell ', num2str(n), '/', num2str(ncells)])
        end
    end

end

out = sprintf('cells cropped and saved');
%% Old Crop

% 
% cellcount = 0;
% for curent_sq=unique_sq_in_list
%     
%     fprintf('Starting cropping and sorting cells!! Sq%d\n',curent_sq)
%     allct_table{curent_sq} = allCt{curent_sq}.*(1/EMscale);
%     ncells{curent_sq} = size(allct_table{curent_sq}, 1);
%     %[M, lmnorm] = myclem_lm_normalize_raw_image(allLM{curent_sq}, 0);
%     lmnorm = allLM{curent_sq};
%     
%     LM = imresize(lmnorm,(1/EMscale));
%     EM = allEM{curent_sq};
%     
%     for curent_cell=1:size(allct_table{curent_sq}(:,1),1)
%         
%         cell_index_in_the_cropingmatrix = allCtind{curent_sq}(curent_cell,:);
%         %define cropping rectangle; for this we need to find
%         %coordinates in allCt cell array
%         curent_cell_box = [allct_table{curent_sq}(curent_cell,1)-round(cz/2)...
%             allct_table{curent_sq}(curent_cell,2)-round(cz/2) cz cz];
%         clear curent_cell_image_matrix
%         % LM
%         
%         for curent_chanel=1:number_of_chanels
%             clear curent_cell_FM_image_matrix
%             %curent_cell_FM_image_matrix = int16(round(imresize(imcrop(LM(:,:,curent_chanel), curent_cell_box), rd)));
%             curent_cell_FM_image_matrix = int16(imresize(imcrop(LM(:,:,curent_chanel), curent_cell_box), rd));
%             curent_cell_image_matrix(:,:,curent_chanel)= curent_cell_FM_image_matrix;
%         end
%         
%         
%         % EM
%         clear curent_cell_EM_image_matrix
%         % curent_cell_EM_image_matrix = int16(round(imresize(imcrop(EM, curent_cell_box), rd)./256));
%         curent_cell_EM_image_matrix = int16(imresize(imcrop(EM, curent_cell_box), rd));
%         curent_cell_image_matrix(:,:,number_of_chanels+1)= curent_cell_EM_image_matrix;
%         
%         %comb
%         curent_cell_index_in_the_data_base = find(cropingmatrix(:,1)==curent_sq&cropingmatrix(:,2)==cell_index_in_the_cropingmatrix);
%         curent_cell_output_file_name = sprintf('%s%sLB%s%scell_%02d_%03d.tif', ...
%             outfolder,filesep,string(cropingmatrix(curent_cell_index_in_the_data_base,3)),filesep, curent_sq, cell_index_in_the_cropingmatrix);
%         
%         montagematrix{cropingmatrix(curent_cell_index_in_the_data_base,3),counter_matrix(cropingmatrix(curent_cell_index_in_the_data_base,3))} = curent_cell_image_matrix(:,:,number_of_chanels+1);
%         counter_matrix(cropingmatrix(curent_cell_index_in_the_data_base,3)) = counter_matrix(cropingmatrix(curent_cell_index_in_the_data_base,3))+1;
%         saveastiff(curent_cell_image_matrix,curent_cell_output_file_name);
%         
%     end
%     
%     
% end
% %{
%     for curent_id=1:largestunique_id
%         clear montagematrixtemp
%         if counter_matrix(curent_id)~=1
%         for curent_cell=1:(counter_matrix(curent_id)-1)
%         montagematrixtemp(:,:,curent_cell) = montagematrix{curent_id,curent_cell};
%         end
%          combnamwwe = sprintf('%s%scell_LB%s.tif', outfolder,filesep,string(curent_id));
%         saveastiff(montagematrixtemp,combnamwwe);
%         end
%     end
% %}



%end
