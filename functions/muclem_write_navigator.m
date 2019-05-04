function muclem_write_navigator(work_dir, nav_in, nav_out, sq_list, DBname,...
    Incl, Appr, mrcroot, EMscale, SpeedScale, addmode, transformtype, acquire)
%   Function reads navigator file and first determines if it is an old
%   format (tab separated table with header on the second line and one item
%   per row starting from the third line), or whether is is a new format
%   (from SerialEM 3.6, like mdoc file). It will look in the navigator entries 
%   to match map items with the map name root provided by user, then will 
%   compare list of squares provided with available maps and will import
%   points for maps found in the navigator.
%
%   For old format it will import
%   points by transforming them using geometric transformation specified
%   ('affine', 'projective', 'similarity') and registration points derived
%   from tile center coordinates in the microscope (derived from mdoc) and
%   tile coordinates from the blended montage (derived by
%   cross-correlations with original stack). These coordinates will match
%   cells on the map, when loaded to SerialEM only if the stage movements
%   during mappimg were very percise, but most likely they will be
%   displaced. This should be corrected manualy (takes some time). To aid
%   this guide images for each gris square are saved in the working
%   directory. On the image each cell is marked with its ID
%   (squarenum-cellnum) to aid repositioning of points correctly. It is
%   important cells do not get mixed up.
%
%   For new format navigator you need to choose import mode. For new format and
%   SerialEM 3.6 you have to choose the same mode as for the old navigator (1).
%   However for 3.7 you can choose 2 or 3; 3 is the most precise, choose it.
%   Mode 3 (CoordinatesInPieces) will also identify individual tiles in the
%   montage, like mode 1. You will need to remove tiles without cells. Tiles with cells,
%   but slightly displaced should stay. No transformations will be made. 
%
%   Positions of cells are written in the navigator along with Acquire tag,
%   Z position of the map on which they are and mapID.
%   All cells on the same square get the same GroupID. This can be used to
%   adjust their z-height alltogether, and is important when the grid is
%   re-inserted in the microscope, and eucentric height changes.
%
%       -yura June 2017
%
%   Version 3 has a possibilty to select which cells to add by uploading a
%   DB table which is the result of manual dataset evaluation (stage 10.
%   Browse/Select).
%       -yura Jan 2018
%
%   When SerialEM 3.7 becomes widespread, options or old Navigator files
%   should be removed.
%
% MultiCLEM scripts
% Yury Bykov and Nir Cohen, 2018

%Test parameters
% nav_in = 'nav2.nav';
% nav_out = 'nav2_manytest3.nav';
% excludelist_name = '';
% work_dir='/net/bstore1/bstore1/briggsgrp/ybykov/yeasthtp/mutwine/E4_robust';
% sq_list=[1 2 4 9];
% mrcroot = 'mm'; % How map files are named; script will look for mm1.mrc,mm2.mrc,etc
% EMscale = 0.25;
% SpeedScale = 0.1;
% addmode = 3; % 1-Transform to stage using tiles as reg points, 2 - CoordsInMap, 3 - CoordsInPiece
% transformtype = 'similarity';
% acquire=1;

%Hard-coded
% How do old or new nav files start
oldstart = 'Version';
newstart = 'AdocVersion'; % Starting from SerialEM 3.6
sq_root = 'sq';
%% Read navigator
inname = [work_dir, filesep, nav_in];
outname = [work_dir, filesep, nav_out];

% Open file and get the first line
if exist(inname, 'file')==2
    f = fopen(inname);
else
    disp('Navigator file does not exist.')
    return
end
tline = fgetl(f);
% determine navigator type
navtype = 0;
pos = strfind(tline, oldstart);
if ~isempty(pos)
    if pos==1
        disp('This is old navigator format');
        disp('Advanced features of external point addition are not supported')
        disp('You would need to corret cell centers on the map')
        navtype = 1;
        addmode = 1;
    else
        disp('This is new navigator format')
        navtype=2;
    end
else
   disp('Something is wrong. Return')
   return                               % add dialog or something to specify type by hand
    
end

% read new nav by section first
NAV = cell([1 0]);
tempc = cell([1 0]);

if navtype==2
    
    %Find the first line of the first item
    while ischar(tline)
        posstr = strfind(tline, '[Item =');
        if ~isempty(posstr)
            disp('First item found')
            break
        end
        tline = fgetl(f);
    end
    
    item=1;
    tempc = [tempc; tline];
    tline = fgetl(f);
     while ischar(tline)
        % check if the new line is new item
        posstr = strfind(tline, '[Item =');
        if ~isempty(posstr)
            %disp('More item found')
            %if yes add previous item to cell array
            NAV{item}=tempc;
            %reset temporary array
            tempc = cell([1 0]);
            item=item+1;
        end
        NAV{item}=tempc;
        % Add lines
        tempc = [tempc; tline];
        tline = fgetl(f);
     end
     
    nitems = size(NAV,2);
    disp(['There are ', num2str(size(NAV,2)), ' entries'])
    fclose(f);

% Read the old navigator by line
elseif navtype==1
    % get the second line containing header 
    tabheader = fgetl(f);
    item=1;
    % Read all other lines-item
    tline=fgetl(f);
     while ischar(tline)
         NAV{item}=tline;
         item=item+1;
         tline = fgetl(f);
     end
     
    nitems = size(NAV,2);
    disp(['There are ', num2str(size(NAV,2)), ' entries'])
    fclose(f);
end

%% Find our maps among entries
if navtype==1
    ourmaps = [];
    for n=1:nitems
        % Take one entry
        C = textscan(NAV{n}, '%s', 'Delimiter', '\t');
        if str2num(C{1}{11})==2 % It's a maaap!!
            % Does it match our pattern?
            % Extract file name from path
            E = textscan(C{1}{28}, '%s', 'Delimiter', '\');
            mapfile = E{end}{end};
            if ~isempty(regexp(mapfile, [mrcroot, '\d*.mrc'], 'once')) %If yes, save item position(index), number from map name, ID, Z value
                formt_str = [mrcroot, '%d.mrc']; % format string to look for square number in filename
                sqnum_mrc = sscanf(mapfile, formt_str); % square number from file name, number should be before .mrc!
                ourmaps = [ourmaps; n sqnum_mrc, str2double(C{1}{29}), str2double(C{1}{5})];
            end
        end
    end
    % summarize results
    if ~isempty(ourmaps)
        maplist = unique(ourmaps(:,2));
        nmapstot = size(maplist,1);
        fprintf('Matching maps (Int32 display):\n\t #\t  sqnum\t      MapID\t      MapZ\n--------------------------------------------------\n')
        disp(int32(ourmaps))
    else
        disp('No matching maps. Return.')
        return
    end
    
elseif navtype==2
    %Go and find maps with filenames matching our set
    ourmaps = []; % we need in this table: Item number in array (col1), square number (2col), MapID (3col), Zvalue (4col)
    for n=1:nitems
        ismap=0;
        %extract and item and determine if its a map
        It = NAV{n};
        nfields = size(It,1);
        % Determine if a map
        for k=1:nfields
            mapmatch=strfind(It{k}, 'Type = 2');
            if ~isempty(mapmatch)
                %disp([num2str(n), ' is a map'])
                ismap=1;
            end
        end
        
        % If a map, extract parameters and decide if its a map we are
        % looking for
        if ismap==1
            % Filename
            for k=1:nfields
                mapmatch=strfind(It{k}, 'MapFile = ');
                if ~isempty(mapmatch)
                    C = textscan(It{k}, '%s', 'Delimiter', '\');
                    mapfile = C{end}{end};
                end
            end
            
            % MapID
            for k=1:nfields
                mapmatch=strfind(It{k}, 'MapID = ');
                if ~isempty(mapmatch)
                    C = textscan(It{k}, 'MapID = %d');
                    mapID = C{end};
                end
            end
            
            % Zvalue
            for k=1:nfields
                mapmatch=strfind(It{k}, 'StageXYZ = ');
                if ~isempty(mapmatch)
                    C = textscan(It{k}, 'StageXYZ = %f %f %f', 'Delimiter', ' ');
                    mapZ = C{end};
                end
            end
                        
            % If the filename matches our convention, store information in
            % the table
            if ~isempty(regexp(mapfile, [mrcroot, '\d*.mrc'], 'once'))
                ourmaps = [ourmaps; n str2double(regexp(mapfile, '\d*', 'match')), double(mapID), double(mapZ)];
            end
            
        end
             
    end
    
    % summarize results
     maplist = unique(ourmaps(:,2));
        nmapstot = size(maplist,1);
        if nmapstot ~=0
            fprintf('Matching maps (Int32 display):\n\t  #\t  sqnum\t      MapID\t      MapZ\n--------------------------------------------------\n')
            disp(int32(ourmaps))
        else
            disp('No matching maps. Return.')
            return
        end
        
        
end
%% Compare found maps with requested
% Generate new square list
newsqlist = sq_list(ismember(sq_list, ourmaps(:,2)));
disp('You requested to add points from the following squares:')
disp(sq_list)
disp('Maps for the following squares you requested were found:')
disp(newsqlist)
disp('Points from these squares will be added')

% Generate filenames for each square to be added 
nsq = size(newsqlist,2);
for n=1:nsq
    % Montage
    IM{n} =  [work_dir, filesep, sq_root, num2str(newsqlist(n)), filesep, sq_root, num2str(newsqlist(n)), '.tif'];
    % Stack
    IS{n} = [work_dir, filesep, sq_root, num2str(newsqlist(n)), filesep, sq_root, num2str(newsqlist(n)), '_stack.tif'];
    % mdoc
    MDOC{n} = [work_dir, filesep, sq_root, num2str(newsqlist(n)), filesep, mrcroot, num2str(newsqlist(n)), '.mrc.mdoc'];
    % Montage centroids
    MCn{n} = [work_dir, filesep, sq_root, num2str(newsqlist(n)), filesep, sq_root, num2str(newsqlist(n)), '_Montage_centroids.txt'];
    % Out guide image name
    G{n} = [work_dir, filesep, 'Guide_for_square_', num2str(newsqlist(n)), '.png'];
end

%% If required find pieces within the montage (old code)

if addmode==1||addmode==3
    
    % Both modes require cross-correlation between map and separate tiles
    SC = cell([0 1]); % stage centroids for each square
    CoordsInPiece = cell([0 1]); % cell array of arrays (for each square). Each array has 3 columns - tile No, X in tile, Y in tile for each cell
    
    % for each square
    for n=1:nsq
        sqnum = newsqlist(n);
        
        inmontage = IM{n};
        instack = IS{n};
        mdocname = MDOC{n};
        in_points = MCn{n};
        
        % Read positions from .mdoc
        if exist(mdocname, 'file')
            f = fopen(mdocname);
        else
            disp(['.mdoc file not found, square - ', num2str(sqnum)])
            disp('return');
            return
        end
        
        StagePos = zeros([0 2]);
        tline = fgetl(f);
        while ischar(tline)
            
            posstr = strfind(tline, '[ZValue = ');
            if ~isempty(posstr)
                while ischar(tline)&&(~strcmp(tline, ''))
                    C = textscan(tline, 'StagePosition = %f %f');
                    StagePos = [StagePos; C{1} C{2}];
                    tline = fgetl(f);
                end
            end
            
            tline = fgetl(f);
        end
        fclose(f);
        disp(['Found ', num2str(size(StagePos, 1)), ' tiles in .mdoc'])
        
        % Number of tiles according to *.mdoc
        ntiles = size(StagePos, 1);
        
        % Read the big guy
        disp('Reading montage...')
        montage = imresize(imread(inmontage), SpeedScale);
        ImSize = size(montage);
        
        figure
        imshow(montage, [ ])
        hold on
        TileCentrs = zeros([ntiles 2]);
        
        % read montage coordinates of cells
        points = dlmread(in_points);
        % Find tile coordinates (takes a while)
        
        for k=1:ntiles
            disp(['Looking for tile #', num2str(k), '...']);
            
            % Load
            tile = imresize(imread(instack, k), SpeedScale);
            tilesize = size(tile);
            
            % Find the center
            C = normxcorr2(tile, montage);
            [r, c] = find(C==max(max(C))); % peak position in CC
            TileCentrs(k, :) = [c-0.5*tilesize(:,2) r-0.5*tilesize(:,1)];
            
            %Plot
            rectangle('Position', [TileCentrs(k, 1)-floor(tilesize(:,2)/2) TileCentrs(k, 2)-floor(tilesize(:,1)/2) ...
                tilesize(:,2) tilesize(:,1)], 'EdgeColor', 'y', 'LineWidth', 1)
            text(TileCentrs(k, 1), TileCentrs(k, 2), num2str(k), 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'r')
            
        end
        
        % Rescale Tile center coordinates to ones used in processing
        TileCentrs = (TileCentrs./SpeedScale).*EMscale;
        ImSize = (ImSize./SpeedScale).*EMscale;
        
        TileSize = (tilesize./SpeedScale).*EMscale; % recaled tilesize
        
        
        
        % Exclude tiles with wrong positions
        happy=0;
        while (happy==0)
            % Ask for tiles to exclude (copied from matlab help)
            if addmode==1
                usmessage = 'Exclude tiles that have large displacements, or/and include a lot of grid bar. Try to have perfect grid.';
            elseif addmode==3
                usmessage = 'Exclude tiles that have no cells. Do not forget to exclude misplaced tiles that ended up somewhere within the good ones!';
            end
            x = inputdlg(usmessage,'HTEM analyzer', [1 50]);
            excludelist = str2num(x{:});
            excludelist = sort(excludelist, 'descend');
            
            % Exclude rows
            TileCentrs_e = TileCentrs;
            TileNums_e = (0:(size(TileCentrs,1)-1))'; % Imod indexes for each tile, starts from 0
            StagePos_e = StagePos;
            
            for k=1:size(excludelist, 2)
                disp(['Exclude ', num2str(excludelist(1,k))])
                TileCentrs_e(excludelist(1,k),:)=[];
                StagePos_e(excludelist(1,k),:)=[];
                TileNums_e(excludelist(1,k))=[];
            end
            
            % Convert coordinates to imod style
            Tiles_imod = [TileCentrs_e(:,1) ImSize(1)-TileCentrs_e(:,2)]; % Reverse Y coordinates
            points_imod = [points(:,1) ImSize(1)-points(:,2)];
            
            % Here the common part for two modes ends
            
            % TRANSFORM TO STAGE MODE
            if addmode==1
                % Calculate transform
                tform = fitgeotrans(Tiles_imod, StagePos_e, transformtype);
                % Transform reference points to check quality
                Theor_tiles = tform.transformPointsForward(Tiles_imod);
                
                % Plot transformed reference points to check the precision
                figure
                plot(Theor_tiles(:,1), Theor_tiles(:,2),  'ro', 'MarkerSize', 5)
                hold on
                plot(StagePos_e(:,1), StagePos_e(:,2), 'bo', 'MarkerSize', 10)
                % Ask user 
                choice = questdlg('Good enough?');
                % Handle response
                switch choice
                    case 'Yes'
                        happy = 1;
                        SC{n} = tform.transformPointsForward(points_imod); %OUT
                        out = ['Points transformed for square ', num2str(sqnum)];
                        % make a guide image
                        figure;
                        g = imshow(montage, [ ]);
                        ncells = size(points,1);
                        for c=1:ncells
                            text(points(c,1).*(SpeedScale/EMscale), points(c,2).*(SpeedScale/EMscale), ['\bullet',num2str(c)]);
                        end
                        saveas(g, G{n});
                        close
                        m = msgbox('Achtung! Coordinates were transfered to the navigator in suboptimal way, and may be off cell centers. Before acquisition correct point positions manualy using the guide image saved for this square');
                    case 'No'
                        happy = 0;
                    case 'Cancel'
                        happy = 1;
                        out = ['Exit. Nothing saved for square ', num2str(sqnum)];
                        break;
                end
                
            % MODE: CoordsInPiece
            elseif addmode==3
                %Find for each cell
                XYintile = zeros(size(points_imod));
                ncells = size(points_imod,1);
                closeTileName = zeros([ncells 1]);
                for l=1:ncells
                    % calculate distance matrix between point and tiles
                    D = pdist([points_imod(l,:); Tiles_imod]);
                    closestT = find(D==min(D)); % Index of the closest tile
                    closestT = closestT(1); %it happened once that there are two liles with the same minimal distance! We need only one!
                    XYintile(l,1) = points_imod(l,1)-(Tiles_imod(closestT,1)-TileSize(2)/2); % coords in tile = in montage - origin pos
                    XYintile(l,2) = points_imod(l,2)-(Tiles_imod(closestT,2)-TileSize(1)/2);
                    closeTileName(l) = TileNums_e(closestT);
                end
                CoordsInPiece{n} = [closeTileName XYintile];
            happy=1;
            end
        end
    end
elseif addmode==2
    % We don't really have to do anything
         
end



%% Figure out selection

DBnamefull = sprintf('%s%s%s', work_dir, filesep, DBname);
SV = cell([nsq 0]); % vectors to be put here; vector is 1 or 0 for each cell

if exist(DBnamefull, 'file')==2&&(Appr||Incl) % If the file exists and at least one of the checkboxes ('Included' or 'Included') are selected
    % read DB table and find which squares are there
    disp('DB Table found.')
    DBtable = dlmread(DBnamefull);
    areinDB = ismember(newsqlist, unique(DBtable(:,1)));
    disp(['Out of ', num2str(size(newsqlist,2)), ' squares selected and having maps'])
    disp([num2str(sum(areinDB)), ' are in DBtable. They will be added. Others not.'])
    slist_fin = newsqlist(areinDB);
    nsq = size(slist_fin, 2); % Number of squares might change!
    
    % For each square create a selection vector based on which option is
    % selected
    for n=1:nsq
        subDB = DBtable(DBtable(:,1)==slist_fin(n),:);
        currNc = size(subDB,1);
        if Appr&&(~Incl)
            % All approved  cells, ignore inclusion tag
            SV{n} = subDB(:,6);
            disp(['Square ', num2str(slist_fin(n)), ': Approved ', num2str(sum(SV{n})), ' of ', num2str(currNc)])
        elseif (~Appr)&&Incl
            % All included cells, ignore approval tag
            SV{n} = ~subDB(:,5); %not sure that's very useful option
            disp(['Square ', num2str(slist_fin(n)), ': Included ', num2str(sum(SV{n})), ' of ', num2str(currNc)])
        elseif Appr&&Incl
            SV{n} = (~subDB(:,5))&subDB(:,6); % Not excluded cells AND approved
            disp(['Square ', num2str(slist_fin(n)), ': Included&Approved ', num2str(sum(SV{n})), ' of ', num2str(currNc)])
        end
    end
    
else
    if exist(DBnamefull, 'file')==0&&(Appr||Incl) % If checkboxes selected but DB not found
        disp('DB table not found! Adding all cells from selected squares')
    end
    
    % If nothing is selected, DB file is irrelevant
    slist_fin = newsqlist;
    disp('Neither of ''Approved'' or ''Included'' checkboxes is selected, so the DB Table will not be used. All cells from selected squares will be added');
    for n=1:nsq
        tempt = dlmread([work_dir, filesep, sq_root, num2str(slist_fin(n)), filesep, sq_root,...
            num2str(slist_fin(n)), '_Montage_centroids.txt']);
        ncells = size(tempt,1);
        SV{n} = ones([ncells 1]);
    end
end

%% Add points to the navigator

%OLD NAVIGATOR - only transformation mode is supported
if navtype==1
    copyfile(inname, outname);
    f=fopen(outname, 'a');
    for N=1:nsq
        sqnum=slist_fin(n);
        itnum=ourmaps(ourmaps(:,2)==sqnum,1); %item number of the square map
        sc = SC{N}; % stage centroids list
        z = ourmaps(ourmaps(:,2)==sqnum,4);
        ncells = size(sc,1);
        sel_vector = SV{N};
        for n=1:ncells
            nav_label = [num2str(sqnum), '-', num2str(n)];     % cell's individual label
            
            if sel_vector(n)==1                                                                                 % yeah, that's ugly
            fprintf(f, '%s\t0\t%.3f\t%.3f\t%.3f\t1\t0\t1\t0\t1\t0\t\t%d\t\t\t\t\t\t\t\t\t\t\t\t%.0f\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t%.3f\t%.3f\n',...
                nav_label, sc(n,1), sc(n,2), z, 10000+itnum, acquire, sc(n,1), sc(n,2));
                                                                                                                                                                    % ooooh....
            end
            
        end
    end
    fclose(f);
    disp('Navigator written')
%NEW NAVIGATORE    
elseif navtype==2 
    copyfile(inname, outname);
    f=fopen(outname, 'a');
    fprintf(f, '\r\n');
    
    % TRANSFORM TO STAGE MODE
    if addmode==1
        % for each square
        for N=1:nsq
            sqnum=slist_fin(N);
            sqID = ourmaps(ourmaps(:,2)==sqnum,3);
            sqZ = ourmaps(ourmaps(:,2)==sqnum,4);
            itnum=ourmaps(ourmaps(:,2)==sqnum,1); %item number of the square map
            % Transformed stage positions
            sc = SC{N};
            ncells = size(sc,1);
            sel_vector = SV{N};
            for n=1:ncells
                if sel_vector(n)==1  
                fprintf(f, '[Item = %d-%d]\r\n', sqnum, n);
                fprintf(f, 'Color = %d\r\n', 0);
                fprintf(f, 'StageXYZ = %.3f %.3f %.3f\r\n', sc(n,1), sc(n,2), sqZ);
                fprintf(f, 'NumPts = 1\r\n');
                fprintf(f, 'Regis = 1\r\n');
                fprintf(f, 'Type = 0\r\n');
                fprintf(f, 'GroupID = %d\r\n', 10000+itnum);
                fprintf(f, 'Acquire = %d\r\n', acquire);
                fprintf(f, 'DrawnID = %d\r\n', sqID);
                fprintf(f, 'PtsX = %.3f\r\n', sc(n,1));
                fprintf(f, 'PtsY = %.3f\r\n', sc(n,2));
                fprintf(f, '\r\n');
                end
            end
        end
        fclose(f);
        disp('Navigator written')
        
        % CoordsInMap OPTION
    elseif addmode==2
        % for each square
        for N=1:nsq
            sqnum=slist_fin(N);
            sqID = ourmaps(ourmaps(:,2)==sqnum,3);
            sqZ = ourmaps(ourmaps(:,2)==sqnum,4);
            itnum=ourmaps(ourmaps(:,2)==sqnum,1); %item number of the square map
            % Positions in blended montage, divide by EMscale
            mc = dlmread([work_dir, filesep, sq_root, num2str(sqnum), filesep, sq_root,...
                num2str(sqnum), '_Montage_centroids.txt'])./EMscale;
            ncells = size(mc,1);
            
            % Find real map pixel dimensions to convert Y coordinate to imod style (bottom left)
            Ii = imfinfo(IM{N});
            Ydim = Ii.Height;
            sel_vector = SV{N};
            for n=1:ncells
                if sel_vector(n)==1  
                fprintf(f, '[Item = %d-%d]\r\n', sqnum, n);
                fprintf(f, 'Color = %d\r\n', 0);
                fprintf(f, 'CoordsInMap = %.0f %.0f %.3f\r\n', mc(n,1), Ydim-mc(n,2), sqZ);
                fprintf(f, 'NumPts = 0\r\n');
                fprintf(f, 'Regis = 1\r\n');
                fprintf(f, 'Type = 0\r\n');
                fprintf(f, 'GroupID = %d\r\n', 10000+itnum);
                fprintf(f, 'Acquire = %d\r\n', acquire);
                fprintf(f, 'Imported = 1\r\n');
                fprintf(f, 'DrawnID = %d\r\n', sqID);
                fprintf(f, '\r\n');
                end
            end
        end
        fclose(f);
        disp('Navigator written')
        
    % CoordsInPiece OPTION    
    elseif addmode==3
        % for each square
        for N=1:nsq
            sqnum=slist_fin(N);
            sqID = ourmaps(ourmaps(:,2)==sqnum,3);
            sqZ = ourmaps(ourmaps(:,2)==sqnum,4);
            itnum=ourmaps(ourmaps(:,2)==sqnum,1); %item number of the square map
            % Positions in Pieces
            pc = CoordsInPiece{N};
            ncells = size(pc,1);
            % Adjust for scaling
            pc(:,2:3)=pc(:,2:3)./EMscale;
            sel_vector = SV{N};
            for n=1:ncells
                if sel_vector(n)==1  
                fprintf(f, '[Item = %d-%d]\r\n', sqnum, n);
                fprintf(f, 'Color = %d\r\n', 0);
                fprintf(f, 'CoordsInPiece = %.0f %.0f %.3f\r\n', pc(n,2), pc(n,3), sqZ);
                fprintf(f, 'PieceOn = %d\r\n', pc(n,1));
                fprintf(f, 'NumPts = 0\r\n');
                fprintf(f, 'Regis = 1\r\n');
                fprintf(f, 'Type = 0\r\n');
                fprintf(f, 'GroupID = %d\r\n', 10000+itnum);
                fprintf(f, 'Acquire = %d\r\n', acquire);
                fprintf(f, 'Imported = 1\r\n');
                fprintf(f, 'DrawnID = %d\r\n', sqID);
                fprintf(f, '\r\n');
                end
            end
        end
        fclose(f);
        disp('Navigator written')
    end
    
end
end   %function end

