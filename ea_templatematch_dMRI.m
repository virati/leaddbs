function ea_templatematch_dMRI(config)
    tic;

    if config.preprocess
        disp("Preprocessing input file...")
        input_mat = config.input;
        [~,file_mat,~] = fileparts(input_mat);
        %%PREPROCESSING TRACKS
        %convert tract to nii
        output_nii_from_input_tract = fullfile(config.norm.outfolder,[file_mat,'.nii']);
        ea_ftr2nii(input_mat,'',output_nii_from_input_tract);
        if ~isfield(config,'fwhm_tract')
            smooth = 9;
        else
            smooth = config.fwhm_tract;
        end
        if ~isfield(config,'thresh_tract')
            thresh_tract = 0.001;
        else
            thresh_tract = config.thresh_tract;
        end
        %binarize tract file
        spm_smooth(output_nii_from_input_tract,output_nii_from_input_tract,[smooth,smooth,smooth]);
        tract_nii = ea_load_nii(output_nii_from_input_tract);
        tract_nii.img(tract_nii.img>thresh_tract)=1;
        ea_write_nii(tract_nii);

        %get nifti of start point and end point
        [start_fname,end_fname] = get_start_and_end(input_mat,config.norm.outfolder);

        %%smoothing
        if ~isfield(config,'fwhm')
            fwhm = 3;
        else
            fwhm = config.fwhm;
        end
        

        [smoothed_start_fname,smoothed_end_fname] = smooth_niftis(input_mat,start_fname,end_fname,config.norm.outfolder,fwhm);

        %thresholding
        if ~isfield(config,'thresh')
            thresh = 0.5;
        else
            thresh = config.thresh;
        end
        
        [thresholded_start_fname,thresholded_end_fname] = threshold_niftis(input_mat,smoothed_start_fname,smoothed_end_fname,config.norm.outfolder,thresh);
    
        %warp thresholded nifti files to b0 space
        %define b0 file name
        b0_start_fname = fullfile(config.norm.outfolder,[file_mat,'_startnii_smoothed_ts_b0.nii']);
        config.norm.moving = thresholded_start_fname;
        config.norm.output = b0_start_fname;

        disp("Processing warping of start point");
        warp_nii(config);

        b0_end_fname = fullfile(config.norm.outfolder,[file_mat,'_endnii_smoothed_ts_b0.nii']);
        config.norm.moving = thresholded_end_fname;
        config.norm.output = b0_end_fname;
        disp("Processing warping of end point");
        warp_nii(config);

        %warp nii of tract to b0 space
        output_nii_b0_name = fullfile(config.norm.outfolder,[file_mat,'_b0.nii']);
        config.norm.moving = output_nii_from_input_tract;
        config.norm.output = output_nii_b0_name;
        disp("Processing warping of tract file")
        warp_nii(config)

        % cleanup intermediary files:
        ea_delete(start_fname);
        ea_delete(end_fname);
        ea_delete(smoothed_start_fname);
        ea_delete(smoothed_end_fname);
        ea_delete(thresholded_start_fname);
        ea_delete(thresholded_end_fname);
        ea_delete(output_nii_from_input_tract);
    
    else
        disp("Preprocessing not specified in configFile, skipping...");
    end
    
    
    if config.tracking
        %now you need to actually perform tracking
        basedir = [ea_getearoot,'ext_libs',filesep,'dsi_studio',filesep];
        dsi_studio = ea_getExec([basedir, 'dsi_studio'], escapePath = 1);
        source_file = config.dsi.sourceFile; %this is the .src file, not the .fib.gz file
        if ~isfield(config.dsi,'param0')
            param0 = '0.6';
        else
            param0 = config.dsi.param0;
            if ~isstring(param0)
                param0 = num2str(param0);
            end
        end
       

        if config.preprocess
            %determine type of roi %todo later
            roi1_filename = b0_start_fname; %start nii
            roi2_filename = b0_end_fname; %end nii;
            roi3_filename = output_nii_b0_name; %tract nii
        else
            roi1_filename = config.dsi.Roi1Filename;
            roi2_filename = config.dsi.Roi2Filename;
            roi3_filename = config.dsi.Roi3Filename;
           
        end
        
        if config.preprocess
            [b0path,b0filename,~] = fileparts(output_nii_b0_name);
        else
            [b0path,b0filename,~] = fileparts(roi3_filename);
        end
        
        cmd1 = [dsi_studio ,...
            ' --action=rec',...
            ' --source=',ea_path_helper(source_file), ...
            ' --param0=',param0, ...
            ' --mask=',ea_path_helper(roi3_filename), ...
            ' --output=',ea_path_helper(fullfile(b0path,b0filename)), ...
            ' --method=4'];


        ea_runcmd(cmd1);
        allFiles = regexpdir(b0path,[b0filename,'.*fib.gz'],0);
        tracking_sourcefile = allFiles{1}; %hopefully there is only 1
        output = fullfile(b0path,[b0filename,'.trk.gz']);
        %set additional parameters
        %fibercount
        if ~isfield(config.dsi,'fibercount')
            fc = '500';
        else
            fc = config.dsi.fibercount;
            if ~isstring(fc)
                fc = num2str(fc);
            end
        end
        %seedcount
        if ~isfield(config.dsi,'seedcount')
            sc = '50000';
        else
            sc = config.dsi.seedcount;
            if ~isstring(sc)
                sc = num2str(sc);
            end
        end
        %turning angle
        if ~isfield(config.dsi,'turning_angle')
            turning_angle = '0';
        else
            turning_angle = config.dsi.turning_angle;
            if ~isstring(turning_angle)
                turning_angle = num2str(turning_angle);
            end
        end
        %min length
        if ~isfield(config.dsi,'min_length')
            min_length = '30';
        else
            min_length = config.dsi.min_length;
            if ~isstring(min_length)
                min_length = num2str(min_length);
            end
        end
        %max length
        if ~isfield(config.dsi,'max_length')
            max_length = '300';
        else
            max_length = config.dsi.max_length;
            if ~isstring(max_length)
                max_length = num2str(max_length);
            end
        end
        %otsu threshold
        if ~isfield(config.dsi,'otsu_threshold')
            otsu_threshold = '0.6';
        else
            otsu_threshold = config.dsi.otsu_threshold;
            if ~isstring(otsu_threshold)
                otsu_threshold = num2str(otsu_threshold);
            end
        end
        %smoothing
        if ~isfield(config.dsi,'smoothing')
            smoothing = '0';
        else
            smoothing = config.dsi.smoothing;
            if ~isstring(smoothing)
                smoothing = num2str(smoothing);
            end
        end
       
        %specify command
        cmd2 = [dsi_studio ,...
            ' --action=trk',...
            ' --source=',ea_path_helper(tracking_sourcefile), ...
            ' --roi=',ea_path_helper(roi1_filename), ...
            ' --roi2=',ea_path_helper(roi2_filename), ...
            ' --fiber_count=',fc, ...
            ' --turning_angle=',turning_angle, ...
            ' --min_length=',min_length, ...
            ' --max_length=',max_length, ...
            ' --otsu_threshold=',otsu_threshold, ...
            ' --smoothing=',smoothing, ...
            ' --output=',ea_path_helper(output)];
        
        ea_runcmd(cmd2);

        if exist(output,'file') % tracts generated
            gunzip(output);
            [pth,fn,ext]=fileparts(output);
            ea_delete(fullfile(pth,[ea_stripext(fn),'.mat']));
            [fibers,idx,voxmm,mat,vals]=ea_loadfibertracts(fullfile(pth,fn),config.norm.ref_t2);
            V=spm_vol(config.norm.ref_t2);
            fibersvox=fibers(:,1:3)';
            fibersvox=[fibersvox;ones(1,size(fibersvox,2))];
            fibersvox=V.mat\fibersvox;
            [MNIfibs_mm] = ea_map_coords(fibersvox(1:3,:), ...
                                            config.norm.ref_t2,...
                                            config.norm.inverse.transform,...
                                            fullfile(ea_space,'t1.nii'),...
                                            'ANTS');
            fibers(:,1:3)=MNIfibs_mm';
            ea_savefibertracts(fullfile(pth,[ea_stripext(strrep(fn,'b0','MNI')),'.mat']),fibers,idx,voxmm,mat,vals);
        end



    else
        disp("Tracking not specified in configFile, skipping...")
    end
    if ~isfield(config,'qc')
        if config.preprocess && config.tracking
            config.qc = 1;
        else
            config.qc = 0;
        end
    end
    if config.preprocess && config.tracking
        
        if config.qc
            ref_file = config.norm.b0;
            %first convert the trk to a ftr file
            if endsWith(output,'.gz')
                gunzip(output);
                output = erase(output, '.gz');
            end
            ea_trk2ftr(output,ref_file,1);

            %then convert ftr to mat format
            outputFile_in_matFormat = replace(erase(output, '.gz'), '.trk', '.mat');
            output_nii_from_output_tract = regexprep(outputFile_in_matFormat, '\.mat$', '.nii');
            ea_ftr2nii(outputFile_in_matFormat,ref_file,output_nii_from_output_tract);

            %now calculate dice. The function will binarize the niftis as
            %well.
            dice_value = dice_coeff(output_nii_from_input_tract,output_nii_from_output_tract);
            fprintf("Dice coefficient between the two tracts are %d",dice_value);
        end
    else
        if config.qc
            disp("output files need to be defined properly. Please switch on the preprocessing and tracking steps to get the dice coefficient");
        end
    end

    if config.visualize
        keyboard
    end
    toc;
end

function warp_nii(configFile)
    moving = configFile.norm.moving;
    % first we warp from MNI to the "artificial T2" space
    [path,output1,ext] = fileparts(moving);
    tmp_op = [output1,'_T2',ext];
    output_t2 = fullfile(path,tmp_op);
    ref = configFile.norm.ref_t2;
    inverse_transform = configFile.norm.inverse.transform;
    ea_ants_apply_transforms(0,moving, output_t2, 0, ref, inverse_transform,'NearestNeighbor')

    % now we use a linear transform to the DWI space
    if isfield(configFile.norm,'b02DWI')
        transform_b02DWI = configFile.norm.b02DWI;
        moving = output_t2;
        ref =  configFile.norm.b0;
        ea_ants_apply_transforms(0,moving, output, 0, ref, transform_b02DWI,'NearestNeighbor')
    else % T2 == diffusion space
        output = configFile.norm.output;
        movefile(output_t2,output);
    end
    % finally, we binarize the brain structure
    structure = ea_load_nii(output);
    data = zeros(size(structure.img));
    data(structure.img(:) > 0.5) = 1;  % at p=0.5
    structure.img = data;
    ea_write_nii(structure);

end

function [start_fname,end_fname] = get_start_and_end(input_mat,outfolder)
    [fibers,~,~,~,~] = ea_loadfibertracts(input_mat);
    nii=ea_load_nii([ea_space,'t1.nii']);
    nii.img=zeros(size(nii.img));
    nii.dt=[16,0];
    startnii=nii;
    endnii=nii;
    % will produce fibers and nii
try
    unique(fibers(:,4))';
catch
    keyboard
end
    for tract=unique(fibers(:,4))'
        thistract=fibers(fibers(:,4)==tract,1:3);
        startpt=thistract(1,:);
        endpt=thistract(end,:);
        startfibers_vox = round(ea_mm2vox(startpt, startnii.mat));
        startnii.img(startfibers_vox(1),startfibers_vox(2),startfibers_vox(3))=1;
        endfibers_vox = round(ea_mm2vox(endpt, endnii.mat));
        endnii.img(endfibers_vox(1),endfibers_vox(2),endfibers_vox(3))=1;

    end
    %write out start and end nii
    [path_mat,file_mat,~] = fileparts(input_mat);
    start_fname = fullfile(outfolder,[file_mat,'_start.nii']);
    end_fname = fullfile(outfolder,[file_mat,'_end.nii']);
    
    %add a name to these files
    startnii.fname=start_fname;
    endnii.fname=end_fname;
    %write out the niftis
    ea_write_nii(startnii);
    ea_write_nii(endnii);

    return
end

function [smoothed_start_fname,smoothed_end_fname] = smooth_niftis(input_mat,start_fname,end_fname,outfolder,fwhm)
    if ~exist('fwhm','var')
        fwhm = 2;
    end
    if length(fwhm) > 1
        fwhm_start_nii = fwhm(1);
        fwhm_end_nii = fwhm(2);
    else
        fwhm_start_nii = fwhm;
        fwhm_end_nii = fwhm;
    end
    [path_mat,file_mat,~] = fileparts(input_mat);
    smoothed_start_fname = fullfile(outfolder,[file_mat,'_startnii_smoothed.nii']);
    smoothed_end_fname = fullfile(outfolder,[file_mat,'_endnii_smoothed.nii']);
    
    spm_smooth(start_fname,smoothed_start_fname,[fwhm_start_nii,fwhm_start_nii,fwhm_start_nii]);
    spm_smooth(end_fname, smoothed_end_fname, [fwhm_end_nii,fwhm_end_nii,fwhm_end_nii]);
end

function[thresholded_start_fname,thresholded_end_fname] = threshold_niftis(input_mat,smoothed_start_fname,smoothed_end_fname,outfolder,thresh)
    if ~exist('thresh','var')
        thresh_startname = 0.005;
        thresh_endname = 0.005;
    end
    if length(thresh) > 1
        thresh_startname = thresh(1);
        thresh_endname = thresh(2);
    else
        thresh_startname = thresh(1);
        thresh_endname = thresh(1);
    end
    [path_mat,file_mat,~] = fileparts(input_mat);
    thresholded_start_fname = fullfile(outfolder,[file_mat,'_startnii_smoothed_ts.nii']);
    tssstartnii=ea_load_nii(smoothed_start_fname);
    tssstartnii.img=tssstartnii.img>thresh_startname;
    tssstartnii.fname=thresholded_start_fname;
    ea_write_nii(tssstartnii);

    thresholded_end_fname = fullfile(outfolder,[file_mat,'_endnii_smoothed_ts.nii']);
    tssendnii=ea_load_nii(smoothed_end_fname);
    tssendnii.img=tssendnii.img>thresh_endname;
    tssendnii.fname=thresholded_end_fname;
    ea_write_nii(tssendnii);

end
function dice_value = dice_coeff(nifti1,nifti2)
    
    nii1 = ea_load_nii(nifti1);
    nii2 = ea_load_nii(nifti2);
    
    is1 = ea_isbinary(nii1.img);
    is2 = ea_isbinary(nii2.img);
    
    if ~is1
        nii1.img(nii1.img>0.5)=1;
    end
    
    if ~is2
         nii2.img(nii2.img>0.5)=1;
    end
    
    img1 = nii1.img;
    img2 = nii2.img;
    dice_value = dice(img1,img2);
end


function options=ea_setopts_local
    
    options.earoot=ea_getearoot;
    options.verbose=3;
    options.sides=1:2; % re-check this later..
    options.fiberthresh=1;
    options.writeoutstats=1;
    options.writeoutpm = 0;
    options.colormap=jet;
    options.d3.write=1;
    options.d3.prolong_electrode=2;
    options.d3.writeatlases=1;
    options.macaquemodus=0;
    return
end