 function [normalized_max, normalized_stack] = muclem_norm_lm(raw, plot_histograms)
%  [norm_max, norm_stack] = muclem_norm_lm(RAW, plot_histograms)
%
% The function adjusts contrast in 16-bit images from fluorescent microscopes 
% and turns them into 8 bit for display in MatLab figures. Usually the
% images from the microscopes are not exactly 16 bit and their values 
% do not span from 0 to 65536. In many cases they are actually 12- or 14- bit, 
% so that the saturated value is 4096 (12-bit) or 16384 (14-bit). In our experience the
% most common case is 12-bit with non-useful signal (aggreagates) being saturated to 4096
% and the most useful signal spread around 1000 or less and invisible if
% display contrast is set according to the range (0-4096). This function
% takes such 12-bit data and adjusts the contrast after throwing out the outliers. 
% INPUT: 
%   RAW is a 3d array with channels in dimension 3, 
%   plot_histograms -  plot histograms if passed 1,
% OUTPUT: 
%   norm_max - 8bit image, maximum projection of all normalized channels for
%   correlation purpouses. 
%   norm_stack - stack of all the normalized channels
%
% MultiCLEM scripts
% Yury Bykov and Nir Cohen, 2014-2018

% spacing parameter for a good histogram (default function doesn't work)
spacing=3;

[r, c, nch] = size(raw);


if plot_histograms==1
    breakes = 0:spacing:4095;
    ncounts = size(breakes, 2)-1;
    counts = zeros([ncounts 1]);
    xgrid = zeros([ncounts 1]);
    
    if mod(4095, spacing) ~= 0
    disp('4095/spacing should be integer!!!');
    end
    
    %calculate proper histogram
    
    for n=1:nch
        for i=1:ncounts
            counts(i) = size(find((raw(:,:,n)>breakes(i))&(raw(:,:,n)<=breakes(i+1))), 1);
            xgrid(i) = mean(breakes((breakes>breakes(i))&(breakes<=breakes(i+1))));
        end
        
        
        plot(xgrid, counts)
        hold on
        
    end
    
end

%calculate statistics

%     1 - p5 (5th percentile)
%     2 - p10 (10th percentile)
%     3 - median
%     4 - mean
%     5 - p90 (90th percentile)
%     6 - p95 (95th percentile)

if nch>1
    idx=find(raw(:,:,1)>=0);
else
    idx = find(raw(:,:)>=0);
end

imstats = zeros([nch 6]);
for n=1:nch
    raw1 = raw(:,:,n);
    linraw = raw1(idx);
    imstats(n, 1) = prctile(linraw, 5);
    imstats(n, 2) = prctile(linraw, 10);
    imstats(n, 3) = median(linraw);
    imstats(n, 4) = mean(linraw);
    imstats(n, 5) = prctile(linraw, 90);
    imstats(n, 6) = prctile(linraw, 95);
end


%Normalize

normalized_stack = zeros(size(raw));

% for each channel subtract 5th percentale value and divide by
% interpercentile range
for n=1:nch
    cutmin = raw(:,:,n);
    cutmin(cutmin<imstats(n, 1)) = imstats(n, 1);
    cutmin(cutmin>imstats(n, 6)) = imstats(n, 6);
    normalized_stack(:,:,n) = (cutmin-imstats(n, 1))/(imstats(n,6)-imstats(n, 1));
end

% maximum projection of all channels
lmench_max = max(normalized_stack, [], 3);
normalized_max = uint8(lmench_max.*255);
normalized_stack = uint8(normalized_stack(:,:,:).*255);

% imwrite(normalized_max, 'lm_view_norm_max.tif');
% for n=1:nch
%     imwrite(uint8(normalno(:,:,n).*255), ['lm_view_norm_ch_', num2str(n), '.tif']);
% end

 end
 


