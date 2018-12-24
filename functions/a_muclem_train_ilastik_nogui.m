if ispc==1
    runfile = 'run-ilastik.bat';
elseif isunix ==1
    runfile = 'run_ilastik.sh';
end

for n=1:app.NumberofsquaresEditField.Value
    if app.RunonlycurrentsquareCheckBox.Value==1
        curr_status = [curr_status sprintf('Starting ilastik training using data from square %d\n', n)];
        app.StatusTextArea.Value = curr_status;
        n=app.NumberofsquaresEditField.Value;
        proj_name = [app.GriddirEditField.Value, filesep, '4ilastik_sq', num2str(n), filesep, 'sq', num2str(n), '.ilp'];
        ri = sprintf('%s%s%s --new_project %s --workflow "Pixel Classification"',app.ilastiksetupfolderEditField.Value, filesep, runfile, proj_name);
        system(ri);
        curr_status = [curr_status sprintf('Training done for square %d', n)];
        app.StatusTextArea.Value = curr_status;
        return
    else
        curr_status = [curr_status sprintf('Starting ilastik training using data from square %d\n', n)];
        app.StatusTextArea.Value = curr_status;
        proj_name = [app.GriddirEditField.Value, filesep, '4ilastik_sq', num2str(n), filesep, 'sq', num2str(n), '.ilp'];
        ri = sprintf('%s%s%s --new_project %s --workflow "Pixel Classification"',app.ilastiksetupfolderEditField.Value, filesep, runfile, proj_name);
        system(ri);
        curr_status = [curr_status sprintf('Training done for square %d', n)];
        app.StatusTextArea.Value = curr_status;
    end
    
end

%% Run ilastic code

cd  Substitutes myclem_run_ilastik_linux_friendly script
           % If many squares are run, there is a checkbox to use .ilp from the first square for all of them
            global curr_status;
            if ispc==1
            
               runfile = 'run-ilastik.bat';
            elseif isunix ==1
                runfile = 'run_ilastik.sh';
            end
            
            runcomm = [app.ilastiksetupfolderEditField.Value, filesep, runfile];
            wd = app.GriddirEditField.Value;
            use_first = app.UsefirstilpforallCheckBox.Value;
            
            for n=1:app.NumberofsquaresEditField.Value
                
                if app.RunonlycurrentsquareCheckBox.Value==1
                    n=app.NumberofsquaresEditField.Value;
                    projname = [wd, filesep, '4ilastik_sq', num2str(n), filesep, 'sq', num2str(n), '.ilp'];
                    in_tiff = [wd, filesep, 'sq', num2str(n), filesep, 'sq', num2str(n), '.tif'];
                    run_this = sprintf('%s --headless --project=%s --output_format=tif --export_source="Simple Segmentation" %s', runcomm, projname, in_tiff);
                    system(run_this);
                    curr_status = [curr_status sprintf('Done with square %d\n', n)];
                    app.StatusTextArea.Value = curr_status;
                    
                    return
                else
                    if use_first==1
                        projname = [wd, filesep, '4ilastik_sq', num2str(1), filesep, 'sq', num2str(1), '.ilp'];
                    else
                        projname = [wd, filesep, '4ilastik_sq', num2str(n), filesep, 'sq', num2str(n), '.ilp'];
                    end
                    in_tiff = [wd, filesep, 'sq', num2str(n), filesep, 'sq', num2str(n), '.tif'];
                    run_this = sprintf('%s --headless --project=%s --output_format=tif --export_source="Simple Segmentation" %s', runcomm, projname, in_tiff);
                    system(run_this);
                    curr_status = [curr_status sprintf('Done with square %d\n', n)];
                    app.StatusTextArea.Value = curr_status;
                    
                end
            end
           