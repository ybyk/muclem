function out = muclem_browser(work_dir, side, nrws, chlist)
% This function allows to check quality of FM and EM data and the quality
% of barcode determination. It uses an ID table with labels determined
% automatically to create a database table (DBtable) with additional
% properties for each cell: manually reassigned barcode,
% exclusion/inclusion in subsequent imaging and analysis and a marker of
% approval (was this cell manually evaluated at all). 
%
% A set of cells is demonstrated to the user (number in one figure is determined
% by parameter 'nrws' and size of each panel in pixels by 'side'). The user 
% needs to press keys to exclude/include individual cells from the analysis
% or to open a dialog box to correct the barcode determination. After a set
% of cells was checked the user can 'Approve' it by pressing Space key and
% mobe to the next set of cells. Approval, unlike exclusion and reassignment 
% is not reversible. It is also possible to move around without
% approving by pressing J and K. Z - save and exit, X - jump to the first
% non-approved cell. C - simulate matlab crash (exit without saving)- do
% not press it!
%
% DB table: columns: 1 - sq, 2 - cell, 3 - autolabel, 4 - manual label, 
% 5 - excluded (1 is excluded), 6 - approved (1 is approved)
%
% MultiCLEM scripts
% Yury Bykov and Nir Cohen, 2018
%

%work_dir = 'D:\EM_work_dir';
%EMscale=0.25;
%chlist = [1 2 3 4];
%side = 100; % One little image size in pix - 80-100 is good 
%nrws = 12; % ADJUST SO THAT THE IMAGE IS DISPALYED AT 100%!!! max - 12
bord = 3;   % border between the images, pixels
%IDtablename = 'IDtable1.txt';
%DBtablename = 'DBtable.txt';
Keytablename = 'Keytable1.txt';
%work_dir = '/net/bstore1/bstore1/briggsgrp/ybykov/yeasthtp/embl_0617/C8';
cropfolder = 'browser_imgs';
%chlist = [1 2 3 4]; % numbers and order of channels

%% Initialize - runs only at start
% ASCII codes of keys in use
exclkeys_all = [49 50 51 52 53 54 55 56 57 48 45 61]; % top 12 keys '1' to '=' - press to exclude/include the cell
exclkeys = exclkeys_all(1:nrws); % use only those corresponding to cells displayed

reaskeys_all = [113 119 101 114 116 121 117 105 111 112 91 93]; % bottom 12 keys 'Q' to ']' - press to change the assigned color code
reaskeys = reaskeys_all(1:nrws);

apprkey = 32; % 'Space' key; press to approve assignments and quality of all displayed cells and move down the list
movekeys = [106 107]; % Move up and down the list without approving - keys 'J' and 'K'
jumpto = 120; % jump to first unapproved cell (always runs when a new or not finished DB is opened)
saveexitkey = 122; % press 'Z' to save and exit
%crashtest = 99;
%Key names for display
K = {'1','2','3','4','5','6','7','8','9','0','-','=';...
    'Q','W','E','R','T','Y','U','I','O','P','[',']'};
    
% Check if there is temporary files left the name is 'temp_DBname.txt'
lstr = dir(sprintf('%s%s*.txt', work_dir, filesep));
tempfound = cell([0]);
for n=1:size(lstr,1)
    if strfind(lstr(n).name, 'temp_')==1
        tempfound = [tempfound {lstr(n).name}];
    end
end

if ~isempty(tempfound)
    [Selection,ok] = listdlg('ListString', tempfound, 'SelectionMode', 'single', ...
    'ListSize', [400 300], 'Name', 'Hey...hooman', 'PromptString',...
    'There are some temporary files saved. Choose to recover',...
    'OKString', 'Select', 'CancelString', 'No, start a new DB');
    if ok==0
        recover = 0;
    else
        recover = 1;
        tempname = tempfound{Selection};
        DBtablename = tempname(6:end);
    end
else
    disp('No temporary files found, did not seem to crash before')
    recover = 0;
end


% If finished normally, open/create a DB table, sort it by label and save as temp
if recover==0
    answer = questdlg('Create new database table or open existing?','Hey hooman...', 'New', 'Open', 'New');
    switch answer
        
        case 'New'
            namechecked = 0;
            
            while namechecked==0
                Inpt = inputdlg('Enter just the filename without extension', 'Filename', 1, {'DBtable1'});
                DBtablename = [Inpt{1}, '.txt'];
                if exist(sprintf('%s%s%s', work_dir,filesep,DBtablename))~=0
                    a = questdlg(['The file ', DBtablename, ' exists! What should we do?'],...
                        'Hey hooman...', 'Try another name', 'Overwrite existing',...
                        'Meh, open existing!',  'Try another name');
                    
                    switch a
                        case 'Try another name'
                            namechecked = 0;
                        case 'Overwrite existing'
                            % Create new!
                            delete(sprintf('%s%s%s', work_dir,filesep,DBtablename));
                            namechecked = 1;
                            getid = sprintf('%s%s*.txt',work_dir,filesep);
                            inpt2 = uigetfile(getid, 'Open ID table - result of automatic barcode assignment');
                            IDtablename = sprintf('%s%s%s', work_dir, filesep, inpt2);
                            IDtable = dlmread(IDtablename);
                            ncells = size(IDtable, 1);
                            DBtable= [IDtable zeros([ncells 3])]; % columns: 1 - sq, 2 - cell, 3 - autolabel, 4 - manual label, 5 - excluded, 6 - approved
                            DBsorted = sortrows(DBtable, [3 1 2]);
                            dlmwrite(sprintf('%s%s%s', work_dir,filesep,DBtablename), DBtable);
                            dlmwrite(sprintf('%s%stemp_%s', work_dir,filesep,DBtablename), DBsorted);
                            
                        case 'Meh, open existing!'
                            namechecked = 1;
                            DBtable = dlmread(sprintf('%s%s%s', work_dir, filesep,DBtablename));
                            DBsorted = sortrows(DBtable, [3 1 2]);
                            dlmwrite(sprintf('%s%stemp_%s', work_dir,filesep,DBtablename), DBsorted);
                    end
                else
                    % Create a new DB table from ID table with a new name
                    % identical to 'Overwrite existing' above
                    namechecked = 1;
                    getid = sprintf('%s%s*.txt',work_dir,filesep);
                    inpt2 = uigetfile(getid, 'Open ID table - result of automatic barcode assignment');
                    IDtablename = sprintf('%s%s%s', work_dir, filesep, inpt2);
                    IDtable = dlmread(IDtablename);
                    ncells = size(IDtable, 1);
                    DBtable= [IDtable zeros([ncells 3])]; % columns: 1 - sq, 2 - cell, 3 - autolabel, 4 - manual label, 5 - excluded, 6 - approved
                    DBsorted = sortrows(DBtable, [3 1 2]);
                    dlmwrite(sprintf('%s%s%s', work_dir,filesep,DBtablename), DBtable);
                    dlmwrite(sprintf('%s%stemp_%s', work_dir,filesep,DBtablename), DBsorted);
                end
            end
            
        case 'Open'
            getid = sprintf('%s%s*.txt',work_dir,filesep);
            DBtablename = uigetfile(getid);
            DBtable = dlmread(sprintf('%s%s%s', work_dir, filesep,DBtablename));
            DBsorted = sortrows(DBtable, [3 1 2]);
            DBsorted = sortrows(DBtable, [3 1 2]);
            dlmwrite(sprintf('%s%stemp_%s', work_dir,filesep,DBtablename), DBsorted);
    end

% Recover DBtable from the tempfile
elseif recover == 1
    DBrec = dlmread(sprintf('%s%stemp_%s', work_dir,filesep,DBtablename));
    if exist(sprintf('%s%s%s', work_dir,filesep,DBtablename))~=0
        disp('There is a previous version of the recovered table. Delete.')
        delete(sprintf('%s%s%s', work_dir,filesep,DBtablename));
    end
    DBtable = sortrows(DBrec, [1 2]);    
    DBsorted = DBrec;
    dlmwrite(sprintf('%s%s%s', work_dir,filesep,DBtablename), DBtable);
    dlmwrite(sprintf('%s%stemp_%s', work_dir,filesep,DBtablename), DBsorted);
    
end

% important counts
ncells = size(DBtable, 1);
sqlist = unique(DBtable(:,1))';
nsq = size(sqlist, 2);

% Other stuff
nch = size(chlist, 2);
% Blank images, paddings
blankim = 255+zeros([side side]);
ncol = nch + 4; % total number of columns in the image
pitch = side+bord;
hpad = 255*ones([side bord]);
vpad = 255*ones([bord side*ncol+(ncol-1)*bord]);
%%tell the user about the control keys
infobox = msgbox(['At any time you can approve the displayed cells by pressing the space key or save and exit by pressing z key'...
                    '.'] ,'information','help');
uiwait(infobox) ;
disp(['At any time you can approve the displayed cells by pressing the space key or save and exit by pressing z key. '...
    'Move up and down the list without approving - keys J and K. '...
    'Press X to jump to first unapproved cell (always runs when a new or not finished DB is opened)'])
%% Do the main loop

% initialize before
alldone = 0;
jumpswitch = 1; % always jump to the first cell when a DB file is opened for the first time
ct = 0;
while alldone==0
    % read current DB
    currDB = dlmread(sprintf('%s%stemp_%s', work_dir,filesep,DBtablename));
    
    % if it is the first time or jump triggered by a key - find the first
    % not approved cell
    if jumpswitch==1
        startrow = min(find(currDB(:,6)==0)); % first not approved row
        if isempty(startrow)
            firstrow = 1;
            disp('All approved int his table. Go to 1.')
        else
            firstrow = startrow; % the row to start the block of images! Important!
        end
        jumpswitch = 0; % switch itself off for now
    end
    
    % check if the firstrow value is within the limits
    if firstrow > (ncells - nrws + 1)
        firstrow = ncells - nrws + 1;
    end
    
    
    I = [];
    % Make a figure
    
    % Key table
    KT = dlmread(sprintf('%s%s%s', work_dir, filesep, Keytablename));
    % Constructing image
    for n=0:(nrws-1)
        R = [];
        currow = firstrow + n;
        sq = currDB(currow,1);
        celln = currDB(currow,2);
                  
        % Load images
        %EM
         EMname = sprintf('%s%s%s%sEM_%02d_%03d.tif',...
              work_dir, filesep, cropfolder, filesep, sq, celln);
        if exist(EMname, 'file')==2
            EM = imresize(imadjust(imread(EMname)), [side side]);
        else
            EM = blankim;
            disp('EM File not found!heh')
            disp(EMname)
        end
        
        %LM - assemble already
        LM = [];
        for c=1:nch
            LMname = sprintf('%s%s%s%sLM_%02d_%03d_%d.tif',...
                work_dir, filesep, cropfolder, filesep, sq, celln, chlist(c));
            if exist(LMname)~=0
                LM = [LM imresize(imadjust(imread(LMname)), [side side]) hpad];
            else
                LM = [LM blankim hpad];
                disp('LM File not found!')
            end
        end
        
        R = [blankim hpad LM EM hpad blankim hpad blankim];
        I = [I; R; vpad];
        
    end
    
    % General plotting and labeling
    fig1 = figure('Position', [1 1 1 1]);
    imshow(I, [ ]);
    title(sprintf('Displaying cells %d to %d out of %d. Approved: %d',...
        firstrow, firstrow+nrws-1, ncells, sum(currDB(:,6))))
    text(5+pitch*(ncol-2), 5, 'To exclude', 'FontSize', 11);
    text(20+pitch*(ncol-2), 25, 'PRESS', 'FontSize', 11);
    text(5+pitch*(ncol-1), 5, 'To reassign', 'FontSize', 11);
    text(20+pitch*(ncol-1), 25, 'PRESS', 'FontSize', 11);
    
    % Make labels for each row
    for n=0:(nrws-1)
        currow = firstrow + n;
        % Construct the row label
        sq = currDB(currow,1);
        celln = currDB(currow,2);
        autoL = currDB(currow,3);
        manuL = currDB(currow,4);
        if manuL ~=0
            channels = KT(manuL,2:end);
        else
            channels = KT(autoL,2:end);
        end
        excl =  currDB(currow,5);
        appr =  currDB(currow,6);
        
        text(5, 10+pitch*n, [num2str(sq), '-', num2str(celln)]);
        if excl==0
            text(5, 25+pitch*n, 'Included', 'Color', 'green');
        else
            text(5, 25+pitch*n, 'Excluded', 'Color', 'red');
        end
        
        if appr==1
            text(5, 40+pitch*n, 'Approved', 'Color', 'green');
        else
            text(5, 40+pitch*n, 'NOT approved', 'Color', 'red');
        end
        
        text(5, 55+pitch*n, ['AL:', num2str(autoL), ' ML:', num2str(manuL)], 'Color', 'blue');
        text(5, 70+pitch*n, num2str(channels));
        text(pitch/2+pitch*(ncol-2), pitch/2+n*pitch, K{1,n+1}, 'FontSize', 14)
        text(pitch/2+pitch*(ncol-1), pitch/2+n*pitch, K{2,n+1}, 'FontSize', 14)
        
    end
    % Display done
    
    %% Get user input
    correct_key = 0;
    while correct_key==0
        CH = getkey;
        
        % ECXLUDE/INCLUDE
        if ismember(CH,exclkeys)
            correct_key = 1;
            % find wich to exclude - resave temp DB
            pos = find(exclkeys==CH);
            ex_i = firstrow + pos - 1; % index of the cell to include/exclude
            currDB(ex_i,5) = ~currDB(ex_i,5); % invert the value of the corresponding row
            dlmwrite(sprintf('%s%stemp_%s', work_dir,filesep,DBtablename), currDB); % save
            firstrow = firstrow; % display at the same position next!
            disp(['Exclude ', num2str(ex_i)]);
            % REASSIGN
        elseif ismember(CH, reaskeys)
            correct_key = 1;
            % find which to reassign - resave temp DB
            pos = find(reaskeys==CH);
            re_i = firstrow + pos - 1; % index of the cell to include/exclude
            
            labelcheck = 0;
            % Ask to type in
            while labelcheck==0
                answer = inputdlg('Which channels are there. Type 1 0 1 0 or so, no other symbols, just 0 or 1 one for each channel separated by Space. Do not mind individual wrongly assigned cells, put in the general pattern.');
                if isempty(answer)
                    % Cancel Key pressed, do not do a thing
                    labelcheck = 1;
                elseif isempty(answer{1})
                    % Nothing typed in, do not do a thing
                    labelcheck = 1;
                else
                    % something typed in
                    newchan = eval(['[', answer{1}, ']']);
                    % find which label is it
                    row = find(ismember(KT(:,2:end), newchan, 'rows')==1);
                    if isempty(row) % no such label!
                        % Two optins - wrongly typed in or a rare label
                        % overlooked by k-means which needs to be added to the
                        % KeyTable
                        nl = size(KT, 1);
                        inpt3 = questdlg(sprintf('There is no such channel combination among the %d labels stored in the Keytable. Add this label to the table or try again and enter another combination of channlels?',nl),...
                            'Hey... hooman', 'Add', 'Try again', 'Try again');
                        switch inpt3
                            case 'Add'
                                % Modify the key table
                                newL = nl + 1; % create new label
                                KT = [KT; newL newchan];
                                dlmwrite(sprintf('%s%s%s', work_dir, filesep, Keytablename), KT);
                                % Modify the DB table
                                currDB(re_i,4) = newL;
                                dlmwrite(sprintf('%s%stemp_%s', work_dir,filesep,DBtablename), currDB); % save
                                firstrow = firstrow; % display at the same position next!
                                labelcheck = 1;
                            case 'Try again'
                                labelcheck = 0; % run the query loop again
                        end
                    else % label exists in the KT
                        labelcheck = 1;
                        % just reassign to another label
                        newL = KT(row,1);
                        currDB(re_i, 4) = newL;
                        dlmwrite(sprintf('%s%stemp_%s', work_dir,filesep,DBtablename), currDB); % save
                        firstrow = firstrow;
                    end
                end
            end
            
            % APPROVE (irreversible), Move forward
        elseif ismember(CH, apprkey)
            correct_key = 1;
            currDB(firstrow:(firstrow+nrws-1),6) = 1;
            firstrow = firstrow + nrws;
            % if tries to move out of the last page
            if firstrow > (ncells - nrws + 1)
                firstrow = ncells - nrws + 1;
            end
            dlmwrite(sprintf('%s%stemp_%s', work_dir,filesep,DBtablename), currDB); % save
            
            % JUST MOVE
        elseif ismember(CH, movekeys)
            correct_key = 1;
            if CH==movekeys(1)
                % backwards
                firstrow = firstrow - nrws;
                if firstrow < 1
                    firstrow = 1;
                    disp('Hoooman stop pressing! This is the 1st cell!')
                end
            elseif CH==movekeys(2)
                firstrow = firstrow + nrws;
                % the check for exceeding number of cells is in the beginning
                % of the display loop
            end
            
        % JUMP to first not approved
        elseif ismember(CH, jumpto)
            jumpswitch = 1;
            alldone = 0;
            disp('Jump to first nonapproved')
            correct_key = 1;
            
        % SAVE and exit    
        elseif ismember(CH, saveexitkey)
            correct_key = 1;
            alldone = 1;
            DBunsorted = sortrows(currDB, [1 2]);
            dlmwrite(sprintf('%s%s%s', work_dir, filesep, DBtablename), DBunsorted);
            delete(sprintf('%s%stemp_%s', work_dir,filesep,DBtablename));
            % save normal DB, delete temp DB
            disp('Save and exit')
            
        %elseif ismember(CH, crashtest)
            
        %    correct_key = 1;
        %    alldone = 1;
        else
            disp('Wrong key. Press the right one.')
        end
    end
    
    % Check where we are? are we done?
    close(fig1)
    
end
out = 'Evaluation completed.';

end