function [fibers,idx,voxmm,mat,vals]=ea_loadfibertracts(cfile, ref, hemisphere_idx, full_connectome)
if ~exist('ref','var')
    ref = 'mni';
end
if ~exist('hemisphere_idx','var')
    hemisphere_idx = 1;
    disp('Doing only one hemisphere (idx = 1; left?)')
end

if endsWith(cfile, {'.trk', '.trk.gz'})
    ea_trk2ftr(cfile, ref, 1);
    cfile = replace(erase(cfile, '.gz'), '.trk', '.mat');
end

%% Load in file and break out pieces
fibinfo = load(cfile);
if ~isfield(fibinfo,'ea_fibformat')
    ea_convertfibs2newformat(fibinfo,cfile);
    fibinfo = load(cfile);
end


if full_connectome == false
    %check if the hemisphere_idx even exists in fibinfo
    disp(length(fibinfo.fibcell{1,hemisphere_idx}))
    if length(fibinfo.fibcell{1, hemisphere_idx}) == 0
        fibers = 0
        idx = 0
        voxmm = 0
        mat = 0
        vals = 0
        return
    end
    fibers_fibfilt = fibinfo.fibcell{1,hemisphere_idx};
    total_number_of_streamlines = length(fibers_fibfilt);
    usedidx = fibinfo.usedidx{1,hemisphere_idx};
else
    fiber_fibfilt = fibinfo

%% Core Processing
fibers_matrix = [];
%create proper indices here
for stream_idx = 1:total_number_of_streamlines
    streamline = fibers_fibfilt{stream_idx};
    number_of_points = length(streamline);
    fibers_matrix = [fibers_matrix;horzcat(streamline, repmat(stream_idx, number_of_points,1))];
end

[~,repeat_count,which_unique_element]=unique(fibers_matrix(:,4));
%iax = count of how many times it's repeated
%iac = which unique element is this
for fib=1:length(repeat_count)-1
    new_idx(fib,1)=repeat_count(fib+1)-repeat_count(fib);
end
% add last entry
new_idx(fib+1,1)=sum(fibers_matrix(:,4)==max(fibers_matrix(:,4)));
fibers_matrix(:,4)=which_unique_element;

fibers = fibers_matrix;
idx = fibers_matrix(:,4);


%%
% Below is misleading
if isfield(fibinfo,'vals')
    vals=fibinfo.vals;
else
    vals=ones(size(idx));
end

if nargout>2
    if isfield(fibinfo, 'voxmm')
        voxmm = fibinfo.voxmm;
    elseif any(fibers<0,'all')
        voxmm = 'mm';
    else % assume voxel
        voxmm = 'vox';
    end

    if isfield(fibinfo, 'mat')
        mat = fibinfo.mat;
    else
        mat = [];
    end
end


function ea_convertfibs2newformat(fibinfo,cfile)

disp('Converting fibers...');

fn=fieldnames(fibinfo);
if isfield(fibinfo,'normalized_fibers_mm')
    fibers=fibinfo.normalized_fibers_mm;
    voxmm='mm';
elseif isfield(fibinfo,'curveSegCell') % original Freiburg format
    fibers=fibinfo.curveSegCell;
    voxmm='vox';
    freiburgconvert=1;
elseif isfield(fibinfo,'fibs') % original Freiburg format
    fibers=fibinfo.fibs;
    voxmm='mm';
else
    fibers=eval(['fibinfo.',fn{1},';']);
    voxmm='mm';
end

c=size(fibers);
if c(1)<c(2)
    fibers=fibers';
end

[idx,~]=cellfun(@size,fibers);
fibers=cell2mat(fibers);
idxv=zeros(size(fibers,1),1);
lid=1; cnt=1;
for id=idx'
    idxv(lid:lid+id-1)=cnt;
    lid=lid+id;
    cnt=cnt+1;
end
fibers=[fibers,idxv];

if exist('freiburgconvert','var')
    [pth, ~]=fileparts(cfile);
    prefs=ea_prefs('');
    if isempty(pth)
        b0fi=[prefs.b0];
    else
        b0fi=[pth,filesep,prefs.b0];
    end
    try
        ver=str2double(fibinfo.version(2:end));
    catch
        ver=1.1;
    end
    if ver<1.1
        disp('Flip fibers...');

        dim=getfield(spm_vol(b0fi),'dim');

        % Freiburg2World transform: xy-swap and y-flip
        tfibs=fibers;
        tfibs(:,1)=fibers(:,2);
        tfibs(:,2)=dim(2)+1-fibers(:,1);
        fibers=tfibs;
        clear tfibs
    end
    mat=getfield(spm_vol(b0fi),'mat');
    ea_savefibertracts(cfile,fibers,idx,voxmm,mat);
else
    ea_savefibertracts(cfile,fibers,idx,voxmm);
end
