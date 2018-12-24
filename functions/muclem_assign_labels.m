function [out] = muclem_assign_labels(work_dir, chlist, side, nrws)
% The script to view a subset of cells from each automatic label and assign
% to it which channels are labeled. Asks user to select an ID table created
% as a result of automatic barcode determination. Sorts it by label and
% shows a set of cells with a given label. The user have to judge if a
% particular channel is present in cells with this label and input a code
% like '0 1 0 1' in the dialog box. Then the script shows all assigned
% codes and also checks if some were entered twice. Then it shows another
% subset of cells for each label and ask user to check everything again.
% The results are written in a file Keytable1.txt with number of rows =
% number of barcodes determined earlier by k-means and number of columns =
% 1 + number of channels. First column - label number assigned by k-means
% and other columns are presence or abscence of staining in each channel.
% This all is done so that user can better evaluate the results of
% automatic barcode determination rather than relying on it fully.
%
% 
% MultiCLEM scripts
% Yury Bykov and Nir Cohen, 2018

%test parameters
%{
side = 80; % One little image size in pix - 80-100 is good 
nrws = 12; % ADJUST SO THAT THE IMAGE IS DISPALYED AT 100%!!! max - 12
IDtablename = 'IDtable1.txt';
work_dir = '/net/bstore1/bstore1/briggsgrp/ybykov/yeasthtp/embl_0617/C8';
chlist = [1 2 3 4]; % numbers and order of channels
%}

bord = 3;   % border between the images, pixels
getid = sprintf('%s%s*.txt',work_dir,filesep);

msgbox('Please, select ID table');
IDtablename = uigetfile(getid, 'Select ID Table');
Keytablename = 'Keytable1.txt'; % !!!!!!! should be only one and hardcoded
cropfolder = 'browser_imgs';
%% Initialize - runs only at start

% Read ID table
IDtable = dlmread([work_dir, filesep, IDtablename]);
ncells = size(IDtable, 1);

lbllist = unique(IDtable(:,3))';
nlbls = size(lbllist, 2);
nch = size(chlist, 2);

% Blank images, paddings
blankim = 255+zeros([side side]);
ncol = nch + 2;
pitch = side+bord;
hpad = 255*ones([side bord]);
vpad = 255*ones([bord side*ncol+(ncol-1)*bord]);

% create Key table. Columns: 1 - name, 2 - autolabel, 3 - array of channels
% like [0 0 0 1] etc
% Rows: labels
KT = zeros([nlbls nch]);


%% Do things
iter = 0;
alldone = 0;
while alldone==0
    disp('Startrow')
startrow = 1+iter*nrws;

for l=1:nlbls
    currL = lbllist(l);
    subID = IDtable(IDtable(:,3)==currL,:);
    lblsize = size(subID,1);
    firstrow = startrow;
    
    %% DISPLAY
    I = [];
    % Make a figure
    for n=0:(nrws-1)
        R = [];
        currow = firstrow + n;
        
        if currow>lblsize
            sq = 0;
            celln = 0;
        else
            % Construct the row label
            sq = subID(currow,1);
            celln = subID(currow,2);
        end
        
        % Load images
        %EM
        EMname = [work_dir, filesep, cropfolder, filesep,...
            sprintf('EM_%02d_%03d.tif', sq, celln)];
        if exist(EMname)~=0
            EM = imresize(imadjust(imread(EMname)), [side side]);
        else
            EM = blankim;
        end
        
        %LM - assemble already
        LM = [];
        for c=1:nch
            LMname = [work_dir, filesep, cropfolder, filesep,...
                sprintf('LM_%02d_%03d_%d.tif', sq, celln, chlist(c))];
            if exist(LMname)~=0
                LM = [LM imresize(imadjust(imread(LMname)), [side side]) hpad];
            else
                LM = [LM blankim hpad];
            end
        end
        
        R = [blankim hpad LM EM];
        I = [I; R; vpad];
        
    end
    f=figure('Position', [1 1 1 1]); 
    imshow(I, [ ]);
    % Make labels
    for n=0:(nrws-1)
        currow = firstrow + n;
        if currow>lblsize
            sq = 0;
            celln = 0;
        else
            % Construct the row label
            sq = subID(currow,1);
            celln = subID(currow,2);
        end
        text(5, 10+pitch*n, [num2str(sq), '-', num2str(celln)]);
    end
    title(['Autolabel=', num2str(currL), ' Channels:', num2str(KT(l,:))])
    
    % Input from user
    answer = inputdlg(['Enter the barcode for this group. Try to look for the general'...
        ' pattern for all cells. Type 0 or 1 for each channel.'...
        ' Example for 4 channels: 1 0 1 0. Do not use other symbols except 0,1, and space']);
    
    if isempty(answer)
        answer = KT(l,:);
    elseif isempty(answer{1})
        answer = KT(l,:);
    else
        KT(l,:) = eval(['[', answer{1}, ']']);
    end
    
    close(f)
end
T = [lbllist' KT];
disp('Assigned labels');
disp(T)

% Check if any assignments are identical and warn if they are
lablecount=1;
for l1=1:nlbls
    for l2=(l1+1):nlbls
        if isequal(KT(l1,:),KT(l2,:))
           % warning(['Achtung! Assigments for L-', num2str(lbllist(l1)), ' and L-', num2str(lbllist(l2)), ' are identical. Check this!'])
            wornings{lablecount} = ['Assigments for label ', num2str(lbllist(l1)), ' and label ', num2str(lbllist(l2)), ' are identical. Check this!'];
            lablecount=lablecount+1;
        end
    end
end

% In case of the first iteration ask to check everything the second time,
% in case of higher iteration ask if want to check again
if iter<1
    wornings{lablecount}='Please go through the second subset of cells and check.';
    uiwait(msgbox(wornings, 'warning'));
else
    ButtonName = questdlg('Check again?');
    switch ButtonName
    case 'Yes'
        alldone = 0;
    case 'No'
        alldone = 1;
    end
           
end

iter = iter + 1;

end

% Write output
dlmwrite([work_dir, filesep, Keytablename], [lbllist' KT]) 
out = 'Key Table written!';
ButtonName = questdlg('Join groups with the same label?');
    switch ButtonName
    case 'Yes'
        join = 1;
    case 'No'
        join = 0;
    end
    if join == 1
       muclem_remove_duplicate_labels(IDtablename, work_dir, Keytablename)
    end
end