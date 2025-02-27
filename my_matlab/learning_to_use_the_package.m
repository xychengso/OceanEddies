% testing the eddy tracking code:

% data: delayed time. 0.25°, daily 
addpath(genpath('/Users/cirrus/Documents/GitHub/OceanEddies'));
SSH_datadir1 ='/Volumes/GoogleDrive/My Drive/Research/ShallowCumulus/EUREC4A Cloud Winter School/Project_JupyterNoteBook/SLA_data';
SSH_datadir2 = '/Users/cirrus/Documents/MATLAB/shallow_convection/Obsv/SLA_data/';

FN = 'dataset-duacs-rep-global-merged-allsat-phy-l4_1615423042024.nc';

Eddy_destdir = [SSH_datadir2 filesep 'OceanEddies_detected'];
if ~exist(Eddy_destdir,'dir')
    mkdir(Eddy_destdir)
end

% Find all anticyclonic eddies
absFN  = [SSH_datadir2 filesep 'dt_global_twosat_phy_l4_20200109_vDT2021.nc'];
absFN = [SSH_datadir1 filesep FN];
ssh = read_ncfile_to_struct(absFN);   %units = m

landval = max(ssh.sla(:));
ssh.sla(ssh.sla==landval)=NaN;

ssh.longitude(ssh.longitude>=180) = ssh.longitude(ssh.longitude>=180)-360;

% generate area map:
areamap_atomic = generate_area_map(length(ssh.latitude), length(ssh.longitude));

% ssh_slice = ncread(absFN, 'Grid_0001');
% landval = max(ssh_slice(:));
% ssh_slice(ssh_slice == landval) = NaN;
% lat = ncread('ssh_data.nc', 'NbLatitudes');
% lon = ncread('ssh_data.nc', 'NbLongitudes');
% lon(lon >= 180) = lon(lon >= 180)-360;
% load('../data/quadrangle_area_by_lat.mat'); % Load areamap to compute eddies' surface areas
ssh_slice = squeeze(ssh.sla(:,:,1))';
time_slice = ssh.time(1);
eddies = scan_single(ssh_slice, double(ssh.latitude), double(ssh.longitude), time_slice, 'anticyc', 'v2', areamap_atomic,'minimumArea',4,'sshunits','meters');

% test:
[LON, LAT]=meshgrid(ssh.longitude, ssh.latitude);
figure(1);clf;
pcolor(LON,LAT, ssh_slice); shading flat;
hold on;
for i = 1:length(eddies)
    IDs=[eddies(i).Stats.PixelIdxList];
    plot(LON(IDs), LAT(IDs), '+r');
end
axis(atomic_box)


sla = permute(ssh.sla,[2,1,3]);
scan_multi(sla, double(ssh.latitude), double(ssh.longitude), ssh.time, 'anticyc', 'v2', areamap_atomic, Eddy_destdir, 'minimumArea',4);

% visualize the results:
% only show eddies in the selected area:
atomic_box = [-60 -50, 10, 18];
cenNA_box = [-50, -40, 10, 18];
eastNA_box = [-40, -30, 10, 18];

region_names = {'atomic','cenNA','eastNA'};
nreg = length(region_names);
for k = 1:nreg
    region_name = region_names{k};
    eval(['reg_box =' region_name '_box;']);
    % loop through all the data in the destination directory:
    files = dir([Eddy_destdir filesep 'anticyc*.mat']);
    filenames = {files.name};
    for i = 1:length(filenames)
        matFN = filenames{i};
        load([Eddy_destdir filesep matFN]);
        
        lon_mask = [eddies.Lon]>=reg_box(1) & [eddies.Lon]<=reg_box(2);
        lat_mask = [eddies.Lat]>=reg_box(3) & [eddies.Lat]<=reg_box(4);
        
        region_mask = logical(lon_mask.*lat_mask);
        
        fieldN = fieldnames(eddies);
        for ii = 1:length(fieldN)
            FN = fieldN{ii};
            tmp = [eddies.(FN)];
            
            eddies_atomic{i}.(FN) = tmp(region_mask);
        end
    end
    
    % compile eddy statistics together:
    Nday = length(eddies_atomic);
    MajorAxisLen = [];
    MinorAxisLen = [];
    Orientation = [];
    SurfArea = [];
    PixelArea = [];
    SSH_Amplitude = [];
    MeanGeoSpeed = [];
    Orientation = [];
    
    for i = 1:Nday
        MajorAxisLen = [MajorAxisLen eddies_atomic{i}.Stats.MajorAxisLength];
        MinorAxisLen = [MinorAxisLen eddies_atomic{i}.Stats.MinorAxisLength];
        Orientation = [Orientation eddies_atomic{i}.Stats.Orientation];
        SurfArea = [SurfArea eddies_atomic{i}.SurfaceArea];  % what is the units?? (km^2)
        PixelArea = [PixelArea eddies_atomic{i}.Stats.Area];
        SSH_Amplitude = [SSH_Amplitude eddies_atomic{i}.Amplitude];
        MeanGeoSpeed = [MeanGeoSpeed eddies_atomic{i}.MeanGeoSpeed];
        Orientation = [Orientation eddies_atomic{i}.Stats.Orientation];
    end
    axis_ratio = MajorAxisLen./MinorAxisLen;
    
    ncol=4;
    figure(1); clf;
    subplot(2,ncol,1+ncol)
    %plot([eddies_atomic.Stats.MajorAxisLength]./[eddies_atomic.Stats.MinorAxisLength],'*b');
    % eddies_stat = [eddies.Stats];
    % scatter([eddies_stat.MajorAxisLength],[eddies_stat.MinorAxisLength],[eddies.SurfaceArea]./1E4,...
    %     [eddies.Amplitude],'filled');
    %scatter(MajorAxisLen, MinorAxisLen, SurfArea./1E4, SSH_Amplitude,'filled');
    scatter(SSH_Amplitude, sqrt(SurfArea), 20, axis_ratio,'filled');
    colormap(jet);
    % xlim([0 20]);
    % ylim([0 20]);
    % hold on
    % plot([0:20],[0:20],'--k');
    grid on
    %ylim([0 5])
    set(gca,'xtick',[0:1:5])
    %axis('square')
    xlabel('SLA Amplitude (cm)')
    ylabel('$\sqrt{Area}$ (km)','interpreter','latex')
    ylim([0 2500]);
    hb=colorbar;
    set(get(hb,'xlabel'),'String', 'axis ratio');
    
    subplot(2,ncol,2+ncol)
    scatter(axis_ratio, sqrt(SurfArea), 20, SSH_Amplitude,'filled');
    colormap(jet);
    % xlim([0 20]);
    % ylim([0 20]);
    % hold on
    % plot([0:20],[0:20],'--k');
    grid on
    % ylim([0 5])
     set(gca,'xtick',[1:1:5])
    %axis('square')
    xlabel('axis ratio')
    ylabel('$\sqrt{Area}$ (km)','interpreter','latex')
    hb=colorbar;
    set(get(hb,'xlabel'),'String', 'SLA Amplitude (cm)');
    ylim([0 2500]);
    xlim([0 5])
    
    subplot(2,ncol,3+ncol)
    scatter(axis_ratio, SSH_Amplitude,  20, sqrt(SurfArea),'filled');
    colormap(jet);
    % xlim([0 20]);
    % ylim([0 20]);
    % hold on
    % plot([0:20],[0:20],'--k');
    grid on
    %axis('square')
    xlabel('axis ratio')
    ylabel('SLA Amplitude (cm)')
    ylim([0 5])
    xlim([0 5])
    set(gca,'ytick',[0:1:5],'xtick',[1:5])
    hb=colorbar;
    set(get(hb,'xlabel'),'String', '$\sqrt{Area}$ (km)','interpreter','latex');
    
    
    
    
    % It doesn't seem like that the shape of the eddy is related to the
    % size or magnitude of the eddies.
    
    % compute ratio and check the distribution:
    subplot(2,ncol,2)
    histogram(axis_ratio,[1:0.2:5]);
    axis('square')
    xlim([1 5]);
    xlabel('Major Axis/Minor Axis')
    ylabel('counts')
    title('Eddy Shape');
    set(gca,'xtick',[1:0.5:5]);
    grid on
    
    subplot(2,ncol,1)
    histogram(sqrt(SurfArea),[0:100:max(sqrt(SurfArea))]);
    axis('square')
    %xlim([0 5]);
    xlabel('$\sqrt{Area}$ (km)','Interpreter','latex')
    ylabel('counts')
    title('Eddy Size');
    set(gca,'xtick',[0:250:2000]);
    grid on
    
    subplot(2,ncol,3)
    histogram(SSH_Amplitude,[0:0.2:5]);   % units is likely centimeter.
    axis('square')
    xlim([0 5]);
    xlabel('SLA Amplitude (cm)')
    ylabel('counts')
    title('Eddy Strength');
    set(gca,'xtick',[0:1:5]);
    grid on
    
    subplot(2,ncol,4)
    histogram(Orientation,[-90:10:90]);   % units is likely centimeter.
    axis('square')
    xlim([-90 90]);
    xlabel('orientation (dgr)')
    ylabel('counts')
    title({'Eddy Orientation'; '(0°: East-West)'});
    set(gca,'xtick',[-90:30:90]);
    grid on
    
    figsvdir = './my_matlab/Figs';
    if ~exist(figsvdir, 'dir')
        mkdir(figsvdir)
    end
    locstr = [num2str((reg_box(1))) '_' num2str((reg_box(2))) ...
        '_' num2str((reg_box(3))) '_' num2str((reg_box(4)))];
    figname = [upper(region_name) '_region_eddy_statics_' locstr '.jpg'];
    
    %pause
    xc_savefig(gcf, figsvdir, figname, [0 0 12 6]);
    
end

% interesting, the eddy statics are about the same in these different
% region..


% My main interests are: the size of the eddies (represented by surface area), 
% the SST/ SSH anomalies (amplitude of the eddies), the shape of eddies
% (major axis / minor axis);


% compute the
% most of the eddies are elliptical. get a ratio for the entire month and
% then check to see if the SST map also yields similar shape and size. 
