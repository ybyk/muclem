function muclem_remove_duplicate_labels(IDtablename, work_dir, Keytablename)
    % Takes KeyTable where two rows have identical list of present channels
    % (in the form of 0s and 1s) and creates a new KeyTable where all
    % labels are sorted according to colors and all get a new number. Then it
    % reassignes numbers in the ID table for each cell according to
    % conversion of old labels to new labels. Old ID and Key tables are
    % saved as _bek.txt files and new tables are copied in their place.
    %
    % MultiCLEM scripts
    % Yury Bykov and Nir Cohen, 2018

IDtable = dlmread([work_dir, filesep, IDtablename]);
IDtablenamedt = split(IDtablename,'.');
IDtablenamebeck = strcat(IDtablenamedt(1), '_bek.', IDtablenamedt(2));
Keytable = dlmread([work_dir, filesep, Keytablename]);
Keytablenamebek = 'Keytable1_bek.txt';

for k=1:size(Keytable,1)
    key(k) = strjoin(string(Keytable(k,2:end)));
end

key=key';
uniqkeys = unique(key);

for old=1:size(Keytable,1)
    [m n] = size(uniqkeys);
    for new=1:m
        if key(old)==uniqkeys(new)
            newlabold{old}=old;
            newlabnew{old}=new;
        end
    end
end

conteniner = containers.Map(newlabold,newlabnew);
[mt nt] = size(IDtable);
for val=1:mt
    IDtable(val,3) = conteniner(IDtable(val,3));
end

for new=1:m
    clear temp
    temp = split(uniqkeys(new))';
    newKtable(new, 1)= new;
    newKtable(new, 2)= temp(1);
    newKtable(new, 3)= temp(2);
    newKtable(new, 4)= temp(3);
    newKtable(new, 5)= temp(4);
end

oldkey =[work_dir, filesep, Keytablename];
oldidb =[work_dir, filesep, IDtablename];

newkey = [work_dir, filesep, Keytablenamebek];
newidb = [work_dir, filesep, char(IDtablenamebeck)];

movefile(oldkey, newkey)
movefile(oldidb, newidb)

dlmwrite([work_dir, filesep, Keytablename], newKtable)
dlmwrite([work_dir, filesep, IDtablename], IDtable)
end
