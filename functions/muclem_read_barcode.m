function out = muclem_read_barcode(slist, chlist, nclusters, work_dir, ...
    EMscale, mrc_root, subtractbg, sr, showim, IDtablename)
    %measures fluorescence intensity of cells walls using previously determined
    %masks, allows measuring many squares at once, accept list of them, and processing all data
    %together, provides flexibility in selecting fluorescent channels in
    %whatver number and order by accepting list of them.To decide on class
    %algorythm uses kmeans. It needs precise number of classes. Afterwards
    %it plots normalized intendity means for each class. Problems arise if
    %some classes are much less frequent. All measurements are written in
    %the square directory, and overwritten without asking
    %All classification results are written out in one file - IDtable, you
    %can set its name, so multiple can exist. It is written in work dir;
    % 1 col - square num, 2 col - cell num, 3 col - label (ID class). The
    % plot is saved as well with the same name as ID table. 
    %   V2 does not have cropping. This should be different function
    %   There is option to subtract background in fluorescent image,
    %   parameter R in microns is readius of structuring element (like
    %   rolling ball in ImageJ). If showim=1 will show before and after
    %   subtraction for each channel for the first square in the list
    % V3 does not have patch measurement method as it proved not very
    % helpful after some testing
    %
    % - yura Jan 2018
    
%Test paramenters
% slist = [1 2 3 4]; % list of squares to be processed, no repeating numbers
% chlist = [1 2 3 4]; % list and order of channels carrying barcodes
% patchsize_pix = 1000; % patchsize
% nclusters = 15;
% work_dir = '/net/bstore1/bstore1/briggsgrp/ybykov/yeasthtp/mutwine/E4_robust';
% mmode = 'simple median';  % 'patches', 'simple median' or other - make a dropdown menu in GUI 
% % you can add more modes, like correlation method, also I had an idea - do
% % many klasses by kmeans, and do hierarchical clustering to get wanted
% % number of classes
% EMscale = 0.25;
% IDtablename = 'IDtable_testV2'; % choose any name, allows to save multiple tables 
% subtractbg=1;
% sr = 2.5;
% showim = 1;
% mrc_root = 'mm';

% hardcoded
sq_root = 'sq';
devmode = 0; % if 1 do not load all the LM data and measure intensities but load already measured intensities
% Read pixel size from mdoc
sq_path = sprintf('%s%s%s%d', work_dir, filesep, sq_root,slist(1));
mdoc_file_name_new = sprintf('%s%s%s%d%s', sq_path, filesep, mrc_root, slist(1), '.mrc.mdoc');
datta = textscan(fopen(mdoc_file_name_new),'%s');
pixelsize = str2double(datta{1,1}(3))/10;

%Calculate pixelsize-dependent parameters
sr = 1000*sr; % from microns to nm
r1_pix = round((EMscale)*sr/(pixelsize)); % Backgroud subtraction element radius

%% Initialize
% A bit more complicated since the script can do many squares together

% Determine square and channel numbers to be processed
nsq = size(slist,2);
nch = size(chlist,2);

% Preallocate cell arrays to store filenames for each square
masksnames = cell([nsq 1]);
lmnames = cell([nsq nch]);
centroidsnames = cell([nsq 1]);
patchintnames = cell([nsq 1]);
cellintnames = cell([nsq 1]);
% Generate names
% squares can go in any order in the list, output will have them correct
for n=1:nsq
   %input
   masksnames{n} = [work_dir, filesep, sq_root, num2str(slist(n)), filesep,...
       sq_root, num2str(slist(n)), '_CW_MASK_IDXS.mat'];
   centroidsnames{n} = [work_dir, filesep, sq_root, num2str(slist(n)), filesep,...
       sq_root, num2str(slist(n)), '_Montage_centroids.txt'];
   %lm
   for c=1:nch
       lmnames{n,c} = [work_dir, filesep, sq_root, num2str(slist(n)), filesep,...
           sq_root, num2str(slist(n)), '_LMtoEM_ch_', num2str(chlist(c)), '.tif'];
   end
   
   %out
   patchintnames{n} = [work_dir, filesep, sq_root, num2str(slist(n)), filesep,...
       sq_root, num2str(slist(n)), '_Patch_intensities.txt'];
   cellintnames{n} = [work_dir, filesep, sq_root, num2str(slist(n)), filesep,...
       sq_root, num2str(slist(n)), '_Cell_intensities.txt'];
end

%out
IDtablefullname = [work_dir, filesep, IDtablename, '.txt']; 
labelplotname = [work_dir, filesep, IDtablename, '_plot.eps'];
%% Check if we are overwriting stuff

% Check ID table
IDtablefullname = [work_dir, filesep, IDtablename, '.txt'];
labelplotname = [work_dir, filesep, IDtablename, '_plot.eps'];
if exist(IDtablefullname, 'file')~=0
    answer = questdlg(['The table ', IDtablename, ' exists'], ...
        'HTEM analyzer','Overwrite', 'Increment name', 'Stop! I change it', 'Overwrite');
    switch answer
        case 'Overwrite'
            delete(IDtablefullname);
            delete(labelplotname);
        case 'Increment name'
            create=1;
            it=1;
            while create==1
                if exist([work_dir, filesep, IDtablename, '_', num2str(it), '.txt'])~=0 % if new name exists already
                    it=it+1;
                else % if it does not exist already
                    IDtablename = [IDtablename, '_', num2str(it)]; %rename, happens only once in loop
                    create=0;
                end
            end
        case 'Stop! I change it'
            out = 'Change the ID table name and try again';
            return
    end
    IDtablefullname = [work_dir, filesep, IDtablename, '.txt'];
    labelplotname = [work_dir, filesep, IDtablename, '_plot.eps'];
end

%% Load data
% Preallocate 
allCW = cell([nsq 1]); %This will be a cell array of cell arrays... (stores cell wall indexes)
allLM = cell([nsq 1]); %Cell array of 3d arrays (stores LM data)
allCt = cell([nsq 1]); %Cell array of 2d arrays (
disp('Loading data...')
% Go square by square
if devmode==0
    for n=1:nsq
        %Masks
        load(masksnames{n});
        allCW{n} = sel_idx;
        
        %LM
        lm_tf = []; % Make one square
        for c=1:nch
            if subtractbg==1
                I = imread(lmnames{n,c});
                lm_tf(:,:,c) = I - imopen(I, strel('disk', r1_pix));
                if showim==1&&n==1
                    imtool([I, lm_tf(:,:,c)]);
                end
            else
                lm_tf(:,:,c) = imread(lmnames{n,c});
            end
        end
        allLM{n} = lm_tf; % write to cell array
        
        % Centroids
        allCt{n} = dlmread(centroidsnames{n});
        
        disp([num2str(n), ' :loaded square ', num2str(slist(n))])
    end
end
disp('That''s it with loading.')
%% Measure and classify

    disp('Simple median mode! Measuring')
    allp_allc = cell([nsq 1]); % will put allmeasurements there
 if devmode==0   
    for n=1:nsq % For each square
        disp(['Statring square ', num2str(slist(n))])
        %extract things from cell arrays
        CWs = allCW{n};
        lm_tf = allLM{n};
        % preallocate temp variables
        ncells = size(CWs, 1);
        allcells = [];
        one_cell = zeros([1 nch]);
        
        %Go over cells
        for N=1:ncells
            for c=1:nch
                C = lm_tf(:,:,c);
                one_cell(1,c) = mean(C(CWs{N}));
            end
            allcells = [allcells; one_cell];
            % Progress
            if mod(N, 50)==0
                disp(['Done with cell ', num2str(N)])
            end
            
        end
        allp_allc{n} =  allcells;
        dlmwrite(cellintnames{n}, allcells);
    end
    
 elseif devmode==1
     % Read existing measurememnts
     for n=1:nsq 
        allp_allc{n} =  dlmread(cellintnames{n});
     end
 end
     
    disp('Measurement done')
    
    % Classification
    disp('Classifying by cell');
    
    %normalize
    cellIDs = []; % array to store cell and square numbers
    normcells = []; % array to store all fluo data for clustering
    for n=1:nsq
        % get only data
        allcells = allp_allc{n};
        ncells = size(allcells,1);
        % normalize chanells - subtract min and divide by inerquartile range, so
        % that range of intensities is roughly the same - this way hisograms will
        % have roughly the same shape
        allcells_chN = (allcells-repmat(min(allcells), ncells, 1))./...
            repmat((quantile(allcells, 0.75)-quantile(allcells, 0.25)), ncells, 1);
        % normalize cells - divide by brightest channel
        allcells_allN = allcells_chN./repmat(max(allcells_chN, [], 2), 1, nch);
        
        % 1 col - sq number; 2 col - cell number
        cellIDs = [cellIDs; zeros([ncells 1])+slist(n) (1:ncells)'];
        normcells = [normcells; allcells_allN];
        
    end
    
    % Correct  bleedthrough (just test)
    %normcells(:,2) = normcells(:,2) - 0.25.*normcells(:,1);
    
    
    % Do kmeans
    clabels = kmeans(normcells, nclusters, 'Replicates', 50);
    
    % measure mean for each cluster
    what2do = normcells; % which array to measure
    msrmt = zeros([nclusters nch]); % array to store mean values for each cluster
    msrmt_sd = zeros([nclusters nch]); % array to store variance (std deviation)
    % measure
    for k=1:nclusters
        for c=1:nch
            
            msrmt(k,c) = median(what2do(clabels==k,c));
            msrmt_sd(k,c) = std(what2do(clabels==k,c));
        end
    end
    msrmt_sum = [sum(msrmt, 2) msrmt  msrmt_sd (1:nclusters)']; % 1 - sum of ...
    % 1:all int for each cluster, 2:nch+1 - measurements, nch+2:2nch+2 = SD
    % for each chennel, last col: initial cluster number
    msrmt_s = sortrows(msrmt_sum, [1 2:(nch+1)]); % sort by total intensity followed by individual channels if needed
    
    % plot
    fig = figure;
    pc = ceil(sqrt(nclusters));
    for k=1:nclusters
        subplot(pc,pc,k)
        bar(msrmt_s(k,2:(nch+1)));
        hold on
        errorbar(msrmt_s(k,2:(nch+1)), msrmt_s(k,(nch+2):(2*nch+1)), '.');
        ylim([0 1.05]);
        Ns = sum(clabels==msrmt_s(k,(2*nch+2)));
        title(['Label ', num2str(msrmt_s(k,(2*nch+2))), ', N=', num2str(Ns)])
    end
    
    %Construct the same array as patch-measurement result columns: 1-sq, 2-cell, 3-label
    plabels = [cellIDs clabels];
    
    % Write the ID table and figure
    dlmwrite(IDtablefullname, plabels);
    saveas(fig, labelplotname);
    disp('ID table and plots saved.') 
    
out = sprintf('Classification done with %d clusters', nclusters);
disp('Done.')
end
