function [out] = muclem_cutout(sq_num, tlX, tlY, cutsize, interact_cut, work_dir)
% This function takes the big blended montage of one grid square (sq_num) and cuts out
% of it 5 small pieces to be used to train ilastik software for
% segmentation of yeast cells, resin, holes and grid bars. The position of
% the first 4 images is specified by a top left corner coordinates (tlX and
% tlY) of the first one. Other 3 are cut out next to it in a tiled manner.
% The fifth one is cut out exactly in the middle on the monrage. The tiles
% are saved in a separate folder for each grid square named like
% 4ilastik_1, where number is the grid square number. The size of images is
% specified by cutsize (1500-2000 pix is ok). If interact_cut=1, the
% preliminary positions on the first 4 tiles will be shown on the montage.
% The user can adjust the position and sizes of the tiles through the
% dialog box.
%
% (c) EMBL, WIS 2017-2018
% Yury Bykov, Nir Cohen

% hard-coded stuff
sq_root = 'sq';
scaledown = 0.1; 

% Construct names
ilastik_t_folder = [work_dir, filesep, '4ilastik_', sq_root, num2str(sq_num)]; 
montage_file = [work_dir, filesep, sq_root, num2str(sq_num), filesep, sq_root, num2str(sq_num), '.tif'];    
mrc_file = [work_dir, filesep, sq_root, num2str(sq_num), filesep, sq_root, num2str(sq_num), '_autoblend.mrc'];
out_file = [work_dir, filesep, '4ilastik_', sq_root, num2str(sq_num), filesep, sq_root, num2str(sq_num), '_tile'];

mkdir(ilastik_t_folder)

%top left corners of rectangles [x y]
rec1 = [tlX tlY];
rec2 = [tlX+cutsize+1 tlY];
rec3 = [tlX tlY+cutsize+1];
rec4 = [tlX+cutsize+1 tlY+cutsize+1];

%open the sq montage and resize it for display
disp('Reading montage')
I = imread(montage_file); 
prev =  imresize(I, scaledown);
[x1,y1] = size(prev);

%specify additional piece in the centre of the image
bigX = x1/scaledown;
bigY = y1/scaledown;
rec5 = [round(bigX/2)-round(cutsize/2) round(bigY/2)-round(cutsize/2)];

if interact_cut==1
    ok = 0;
    %display 4 rectangles on the montage and ask if its ok if no ask the
    %user for the right X/Y to re cut and ask the user again if OK
    while ok == 0
        close
        
        %make 4 rectangles on the image after resizing it using the same scale as the montage
        
        imshow(prev);
        rectangle('Position',[rec1.*scaledown cutsize*scaledown cutsize*scaledown])
        rectangle('Position',[rec2.*scaledown cutsize*scaledown cutsize*scaledown])
        rectangle('Position',[rec3.*scaledown cutsize*scaledown cutsize*scaledown])
        rectangle('Position',[rec4.*scaledown cutsize*scaledown cutsize*scaledown])
        axis([0 x1 0 y1])
        
        choice = questdlg('Are the images OK?');
        switch choice
            case 'Yes'
                happy = 1;
            case 'No'
                happy = 3;
            case 'Cancel'
                happy = 0;
        end
        if happy==1
            ok = 1;
        elseif happy==3
            ok = 0;
            %we will need to change the title of the X/Y for the new
            %rectangle positions and size
            prompt = {'X','Y','Size'};
            dlg_title = 'change size/position';
            num_lines = 1;
            
            defaultans = {num2str(tlX), num2str(tlY), num2str(cutsize)};
            answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
            disp(answer)
            tlX = str2double(answer(1,1));
            tlY = str2double(answer(2,1));
            cutsize = str2double(answer(3,1));
            
            % re-calculate top-left corners
            rec1 = [tlX tlY];
            rec2 = [tlX+cutsize+1 tlY];
            rec3 = [tlX tlY+cutsize+1];
            rec4 = [tlX+cutsize+1 tlY+cutsize+1];
        else
            return
        end
    end
end

%if the user is happy the script is cuting the training images using
%imod function from system command line

% Calculate extraction ranges for imod [Xstart Xend Ystart Yend]
% Y axis in imod starts from the 
recs = [rec1; rec2; rec3; rec4; rec5];
recs_imod = zeros([4 4]);
for n=1:size(recs,1)
    recs_imod(n,:) = [recs(n,1) recs(n,1)+cutsize size(I,1)-recs(n,2)+2-cutsize size(I,1)-recs(n,2)+1];
end

% Run trimvol
for n=1:size(recs_imod,1)
    trimvol = sprintf('trimvol -x %d,%d -y %d,%d %s %s%d.mrc', recs_imod(n,1), recs_imod(n,2), recs_imod(n,3), recs_imod(n,4), mrc_file, out_file, n);
    system(trimvol);
    %disp(trimvol)
    disp(n)
end


%Convert to tif the ilastik training images and delete the .mrc file

for u=1:size(recs_imod,1)
    mrc2tifil = sprintf('mrc2tif %s%d.mrc %s%d.tif', out_file, u, out_file, u);
    mrc2tdel = sprintf('%s%d.mrc', out_file ,u);
    system (mrc2tifil);
    
    delete(mrc2tdel);
    
end
close
out = sprintf('Cuting square %d for ilastik is done',sq_num);
end
