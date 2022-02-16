clc; clear all; Settings = struct(); Settings.LensPresets = struct(); addpath('DropRadiusDetection\functions'); addpath('functions')

%% ABOUT

%{
This program analyzes 

%}


%% TODO
%{
- document code
- check settings and input
- determine time from filename
- what if drop is outside limits?
- create timelapse in the end
- Plot eccentricity, surface area, circularity
- Plot centroids: a tail on the image
- Check if all filenames satisfy TimeIntervalFormat before running code.
I.e. calculate this beforehand, not during the main loop.

%}


%% INPUT


Settings.Source = 'E:\R-t analysis\drop 3\';
% Settings.Source = 'data\rtanalysis_ozlem_drop3_selection';
% Settings.Source  = 'data\testdata\1-02012022151248-538.tiff';
% Settings.Source  = 'data\testdata_small\';
Settings.LensMagnification = 'NikonX4'; % if not set, pixels will be use as unit.
Settings.TimeInterval = 'FromFile'; % either int with timeinterval in seconds, or FromFile to read datetime stamp from filename
    Settings.TimeIntervalFormat = "ddMMyyyyHHmmss";
    Settings.TimeIntervalFilenameFormat = {'-', '-'}; % pattern before and after datetimestring
        % example: 1-02012022152110-1015 -->  {'-', '-'}, with Settings.TimeIntervalFormat = "ddMMyyyyHHmmss"
        % example: recording2022-02-01_15:13:12_image2 --> {'recording','_'}, with Settings.TimeIntervalFormat = "yyyy-MM-dd_HH:mm:ss" 
                % note that it looks for the last occurance of '_'. '_image' would have given the same result.
Settings.ImageCrop = [0 0 0 32]; %top right down left

%% SETTINGS

Settings.CircleFitting = 'always'; %always, never, boundaryonly

Settings.ImageSkip = 1;

% Conversion pix to SI
Settings.LensPresets.ZeisX2 = 677;                  % FLOAT   pixels per mm. Standard presets to use as conversion, assuming in focus. Add like .xMagnification = PixToMm.
Settings.LensPresets.ZeisX5 = 1837;                 % FLOAT   pixels per mm. 
Settings.LensPresets.ZeisX10 = 3679;                % FLOAT   pixels per mm. 
Settings.LensPresets.NikonX2 = 1355;                % FLOAT   pixels per mm. 
Settings.LensPresets.NikonX4 = 2700;                % FLOAT   pixels per mm. 

% Image processing
Settings.ImageProcessing.EnhanceContrast = true;

% Display settings
Settings.Display.IndividualPlots = true;
Settings.Display.TotalPlots = true;

% Plotting 
Settings.Plot_VisualizeCircle = true;
Settings.Plot_TimeVsRadius = true;
    Settings.Plot_TimeVsRadius_LogX = true;
    Settings.Plot_TimeVsRadius_LogY = true;

Settings.PlotFontSize = 15;
Settings.FigureSize = [25 25 1000 800];
Settings.FigureSaveResolution = 300; % dpi

% Saving
Settings.Save_Folder = 'E:\results'; %local path or full path
Settings.Save_Figures = true;
    Settings.Save_PNG = true;
    Settings.Save_TIFF = false;
    Settings.Save_FIG = false;
Settings.Save_Data = true;
Settings.CreateTimelapse = true;
    Settings.CreateTimelapseFrameRate = 15;
    Settings.CreateTimelapseImageCrop = 0.5;
    Settings.CreateTimelapseTimeScale = 'variable';  %supported: variable, min, sec, hrs, auto


global LogLevel
LogLevel = 5;  % Recommended at least 2. To reduce clutter use 5. To show all use 6.
%{
    1, 'ERROR';     % Code cannot continue.
    2, 'ACTION';    % User needs to do something.
    3, 'WARNING';   % Code can continue, but user should note something (decision made by code e.g.).
    4, 'PROGRESS';  % Show user that something is being done now, e.g. when wait is long.
    5, 'INFO';      % Information about code progress. E.g. 'Figures are being saved'.
    6, 'OK';        % just to show progress is going on as planned.
%}

%% 0 - Settings checks and ititialization
clc

Logging(5, append('Code started on ', datestr(datetime('now')), '.'))

% Set default plotting sizes
set(0,'defaultAxesFontSize', Settings.PlotFontSize);

if isfolder(Settings.Source)
    Settings.AnalyzeFolder = true;
    Logging(5, 'Source is a folder, multiple images will be analyzed.')
elseif isfile(Settings.Source)
    Settings.AnalyzeFolder = false;
    Logging(5, 'Source is a file, this single image will be analyzed.')
else
    Logging(1, append('Entered Source "', string(Settings.Source), '" is not a folder nor file.'))
end


% List all images in selected folder.
if Settings.AnalyzeFolder
    if ~strcmp(Settings.Source(end), '\')
        Settings.Source = append(Settings.Source, '\');
    end
    Settings.Source_ImageList = {};  % list with all the images found in the folder. Settings.Analysis_ImageList is the list of images that will be analyzed (selection of prior).
    for ext = {'.tif', '.tiff', '.png', '.jpg', '.jpeg', '.bmp', '.gif'} %check for images of this type in source folder and append to imagelist if they exist.
        images = dir(append(Settings.Source, '*', ext{1}));
        images_fullpath = cellfun(@(x) append(x.folder, '\', x.name), num2cell(images), 'UniformOutput', false);
        Settings.Source_ImageList = [Settings.Source_ImageList, images_fullpath];
    end
    Settings.Source_ImageList = natsortfiles(Settings.Source_ImageList); % Stephen (2022). Natural-Order Filename Sort (https://www.mathworks.com/matlabcentral/fileexchange/47434-natural-order-filename-sort), MATLAB Central File Exchange. Retrieved January 27, 2022. 
    Settings.Analysis_ImageList = Settings.Source_ImageList(1:Settings.ImageSkip:length(Settings.Source_ImageList));

    if isempty(Settings.Source_ImageList)
        Logging(1, 'No images found in Source folder.')
    else
        Logging(5, append(num2str(length(Settings.Source_ImageList)), ' images found in Source folder, ', num2str(length(1:Settings.ImageSkip:length(Settings.Source_ImageList))), ' will be analyzed (every ', num2str(Settings.ImageSkip), ' image(s)).'))
    end

    Settings.ImageCount = length(Settings.Analysis_ImageList);
    Settings.ImageCount_SourceFolder = length(Settings.Source_ImageList);

    if ~isfield(Settings, 'TimeInterval')
        Logging(1, 'TimeInterval is not set. Add "Settings.Timeinterval" to your settings.')
    elseif strcmpi(Settings.TimeInterval, 'FromFile')
        Logging(5, 'Timeintervals will be determined from filenames.')
    elseif CheckIfClass('numeric', {'Settings.TimeInterval'})
        Settings.TimeRange = 0:Settings.TimeInterval:Settings.TimeInterval*Settings.ImageCount_SourceFolder;
        Settings.TimeRange = Settings.TimeRange(1:Settings.ImageSkip:Settings.ImageCount_SourceFolder);
    else
        Logging(1, append('No valid setting Settings.TimeInterval= ', num2str(Settings.TimeInterval), '. Should be numeric time interval, or "FromFile".'))
    end

else %input is single file
    % Check if Settings.Source file is supported format
    [~, ~, ext] = fileparts(Settings.Source);
    if ~any(strcmp({'.tif', '.tiff', '.png', '.jpg', '.jpeg', '.bmp', '.gif'}, ext))
        Logging(1, 'File format not a supported image.')
    end
    Settings.Source_ImageList = {Settings.Source};
    Settings.Analysis_ImageList = Settings.Source_ImageList;
    Settings.ImageCount = 1;
end

% Set save folder and naming for figures and data
save_extensions = NaN;
basename = '';
if Settings.Save_Figures || Settings.Save_Data
    [fldr, name, ~] = fileparts(Settings.Source_ImageList{1});
    fldr_last = split(fldr, '\');
    fldr_last = fldr_last{end};
    stamp = append(fldr_last, '_PROC',  datestr(now, 'YYYY-mm-dd-HH-MM-SS'));
    savefolder_sub = append(Settings.Save_Folder, '\', stamp);
    
    [status, msg] = mkdir(savefolder_sub);
    if status == 0
        Logging(1, append('Folder creation for image saving "', strrep(savefolder_sub, '\', '\\'), '" failed! Error: ', msg))
    else
        Logging(5, append('Created folder for image saving "', strrep(savefolder_sub, '\', '\\'), '" successfully.' ))
    end
    
    % Create subfolder for VisualizeCircle images.
    if Settings.ImageCount > 1
        savefolder_sub_VisualizeCircle = append(savefolder_sub, '\VisualizeCircle');
    	[status, msg] = mkdir(savefolder_sub_VisualizeCircle); 
        if status == 0
            Logging(1, append('Folder creation for image saving "', strrep(savefolder_sub_VisualizeCircle, '\', '\\'), '" failed! Error: ', msg))
        else
            Logging(5, append('Created folder for image saving "', strrep(savefolder_sub_VisualizeCircle, '\', '\\'), '" successfully.' ))
        end
         basename_VisualizeCircle = append(savefolder_sub_VisualizeCircle, '\', stamp);
    else
        basename_VisualizeCircle = append(savefolder_sub, '\', stamp);
    end

    basename = append(savefolder_sub, '\', stamp);
   
    
    clear stamp savefolder_sub
end

if Settings.CreateTimelapse && ~Settings.Save_PNG && ~Settings.Save_TIFF
    Logging(3, 'CreateTimelapse is turned on, but images are not saved as PNG or TIFF. Timelapse cannot be created.')
    Logging(2, 'Do you want to turn on Save_PNG to create a timelapse?')
    x = input('Y (make timelapse) / N (continue without timelapse) [Y]  ','s');
    if isempty(x) || strcmpi(x, 'Y')
        Settings.Save_PNG = true;
        Logging(5, 'Save_PNG is turned on, timelapse will be created.')
    elseif strcmpi(x, 'N')
        Logging(3, 'Timelapse will not be created.')
    else
        Logging(1, 'No valid input')
    end
    clear x
end

if Settings.Save_Figures
    if ~Settings.Save_PNG && ~Settings.Save_TIFF && ~Settings.Save_FIG
        Settings.Save_Figures = false;
        Logging(3, 'Settings.Save_PNG, Settings.Save_TIFF, Settings.Save_FIG are all set to false. No figures will be saved.')
    else
        extensions = {'png', 'tiff', 'fig'};
        save_extensions = extensions([Settings.Save_PNG, Settings.Save_TIFF, Settings.Save_FIG]);
    end
else
    Logging(3, 'Figures will not be saved!')
end


% Determine if to plot individual plots or not
    %TODO include timer. If no choice is made in 60s, start without showing plots.
if Settings.Display.IndividualPlots && length(Settings.Analysis_ImageList) > 2
    Logging(2, 'There are more than 2 images in the selected folder, and Show_Plots is on. This can significantly slow down your computer. Do you wish to continue, or turn off Show_Plots?')
    x = input('Y (keep on) / N (turn off) [N]  ','s');
    if isempty(x) || strcmpi(x, 'N')
        Settings.Display.IndividualPlots = false;
        Logging(5, 'Showing plots to screen is turned off.')
    elseif strcmpi(x, 'Y')
        Logging(3, 'Showing plots is still on. This can significantly slow down your computer.')
    else
        Logging(1, 'No valid input')
    end
    clear x
end

% Determine conversion factor and unit for distance scale
Settings.DistanceUnit = 'mm'; % the standard  (µm)
if ~isfield(Settings, 'LensMagnification') && ~isfield(Settings, 'ConversionFactorPixToMm')
    Settings.ConversionFactorPixToMm = 1;
    Settings.DistanceUnit = 'pix';
elseif isfield(Settings, 'LensMagnification')
    if isfield(Settings.LensPresets, Settings.LensMagnification)
        Settings.ConversionFactorPixToMm = getfield(Settings.LensPresets, Settings.LensMagnification);
    else
        Logging(1, append('Lens preset ', Settings.LensMagnification, ' does not exist. Valid options are: ', strjoin(fields(Settings.LensPresets), ', '), '. Or add as new to Settings.LensPresets.'))
    end    
end

if ~Settings.Save_Data
    Logging(3, 'Data will not be saved!')
end

Logging(6, 'Settings checked and all valid.')
tic

%% Init

% Init Results struct
Results = struct();
Results.AreaPix = nan(1,Settings.ImageCount);
Results.DiameterPix = nan(1,Settings.ImageCount);
Results.Eccentricity = nan(1,Settings.ImageCount);
Results.Circularity = nan(1,Settings.ImageCount);
Results.CircleFittingUsed = nan(1,Settings.ImageCount);
Results.Time = {};
Results.Centroid = {};


% Determine time
if strcmpi(Settings.TimeInterval, 'FromFile')
    Logging(5, 'Timestamps are read from image files ...')
    for i = 1:Settings.ImageCount 
        Image = Settings.Analysis_ImageList{i};
        [~, datetimestamp, ext] = fileparts(Image);
        try
            datetimestamp_sub = ExtractSubstrFromString(datetimestamp, Settings.TimeIntervalFilenameFormat);
        catch
            Logging(1, append('It seems like not all images have the right filename to extract the datetime stamp from it. It could not be determined for: ', datetimestamp, ext, '.'))
        end
        Results.Time{i} = datetime(datetimestamp_sub, 'InputFormat', Settings.TimeIntervalFormat); 
    end
    Results.TimeFromStart = cellfun(@(x) seconds(time(between(Results.Time{1}, x, 'time'))), Results.Time);
else % todo: if numeric, else error
    Results.TimeFromStart = (1:Settings.ImageCount) * Settings.TimeInterval;
end


%% Main loop

%Initiate time remaining display. Account for timelapse making, PNG vs TIFF.
TimeRemaining = TimeTracker;
if Settings.CreateTimelapse && Settings.ImageCount > 1 && Settings.Save_PNG
    extratime = Settings.ImageCount*.1716 + 1.8; %TODO BETTER ESTIMATES: this is 6 image estimate
elseif Settings.CreateTimelapse && Settings.ImageCount > 1 && Settings.Save_TIFF
    extratime = Settings.ImageCount*.1607 + 1.8; %TODO BETTER ESTIMATES: this is 6 image estimate
else
    extratime = 0;
end
TimeRemaining = Initiate(TimeRemaining,  length(Settings.Analysis_ImageList), extratime);

for i = 1:Settings.ImageCount
    TimeRemaining = StartIteration(TimeRemaining);
    Image = Settings.Analysis_ImageList{i};

    Logging(6, append('Image ', num2str(i), ' now being analyzed.'))
 
    I_or = imread(Image);
    I_or = I_or(:,:,1:3); %incase x4 tiff
    crp = Settings.ImageCrop;
    dx = size(I_or, 2);
    dy = size(I_or, 1);
    I_or = imcrop(I_or, [crp(4), crp(1), dx-crp(2)-crp(4), dy-crp(1)-crp(3)]);
    clear crp dx dy
    I = rgb2gray(I_or);
    
    if Settings.ImageProcessing.EnhanceContrast
        I = adapthisteq(I);
    end
    
    I_bi = imbinarize(I);

    CC = bwconncomp(imcomplement(I_bi));
    
    [CC2, idx] = sort(cellfun(@numel,CC.PixelIdxList), 'descend');
    
    if CC2(1) < 2*CC2(2) %todo: still save image.
        Logging(3, 'No discrete solution found.')
    else
        CC3 = CC; %get the main pixellist
        CC3.PixelIdxList = CC3.PixelIdxList{idx(1)};
        
        I2 = zeros(size(I_bi));
        I2(CC3.PixelIdxList) = 1;
        I2 = imfill(I2, 'holes');
    
        Results.Centroid{i} = regionprops(I2, 'Centroid').Centroid;
        Results.AreaPix(i) = regionprops(I2, 'Area').Area;
        Results.Eccentricity(i) = regionprops(I2, 'Eccentricity').Eccentricity;
        Results.Circularity(i) = regionprops(I2, 'Circularity').Circularity;
        Results.DiameterPix(i) = regionprops(I2, 'EquivDiameter').EquivDiameter;
        
        % determine if touching boundary of image
        TouchingBoundary = false;
        extrema = regionprops(I2, 'Extrema').Extrema; % [top-left top-right right-top right-bottom bottom-right bottom-left left-bottom left-top].
        if min(floor(extrema(:,1))) == 0 || max(floor(extrema(:,1))) == size(I2,2) ||  min(floor(extrema(:,2))) == 0 || max(floor(extrema(:,2))) == size(I2,1)
            Logging(6, 'Droplet is toching one of the borders')
            TouchingBoundary = true;
        end
            
        if strcmpi(Settings.CircleFitting,'always') || (strcmpi(Settings.CircleFitting,'boundaryonly') && TouchingBoundary)
            Results.CircleFittingUsed(i) = true;
            boundary = bwboundaries(I2);
            boundary = boundary{1};
            boundary(boundary(:,2) <= 1, :) = [];
            boundary(boundary(:,2) >= (size(I2,2)-1), :) = [];
            boundary(boundary(:,1) <= 1, :) = []; 
            boundary(boundary(:,1) >= (size(I2,1)-1), :) = [];
            
            [xc, yc, R] = circfit(boundary(:,2), boundary(:,1));
            Results.Centroid{i} = [xc, yc];
            Results.DiameterPix(i) = 2*R;              
        else
            Results.CircleFittingUsed(i) = false;
        end
        
        
        f1 = Plot.VisualizeCircle(Settings, struct('I',I_or, 'Centroid',Results.Centroid{i}, 'DiameterPix',Results.DiameterPix(i), 'CircleFittingUsed',Results.CircleFittingUsed(i)));
        SaveFigure(min([Settings.Save_Figures Settings.Plot_VisualizeCircle]), f1, save_extensions, append(basename_VisualizeCircle, '_VisualizeCircle_', num2str(i)), Settings.FigureSaveResolution);
        if ~Settings.Display.IndividualPlots; close(f1); end % must close, even if not visible, otherwise in memory
    end

    [TimeRemaining, TimeLeft] = EndIteration(TimeRemaining);
    if TimeLeft
        Logging(5, TimeLeft)
    end
end

%% Post

if strcmpi(Settings.DistanceUnit, 'pix')
    Logging(3, 'No distance unit known, result data will not be converted to SI units.')
else
    Results.DiameterMet = Results.DiameterPix / Settings.ConversionFactorPixToMm;
    Results.AreaMet = Results.AreaPix / Settings.ConversionFactorPixToMm;
end

%% Plot Time vs Radius

if Settings.ImageCount > 1
    f2 = Plot.TimeVsRadius(Settings, struct('Results',Results, 'Settings',Settings));
    SaveFigure(min([Settings.Save_Figures Settings.Plot_TimeVsRadius]), f2, save_extensions, append(basename, '_TimeVsRadius'), Settings.FigureSaveResolution);
    if ~Settings.Display.TotalPlots; close(f2); end % must close, even if not visible, otherwise in memory
end

%% 6 - Save data

Logging(5, '---- Saving data started.')

if Settings.Save_Data
    save(append(basename, '_results.mat'), 'Settings', 'Results')
end

Logging(6, 'Saving finished successfully.')

%% Create TimeLapse Video

if Settings.CreateTimelapse && Settings.ImageCount > 1 && (Settings.Save_PNG == true || Settings.Save_TIFF == true)
    Logging(5, '---- Timelapse creation started.')
    CreateTimeLapseFunc(savefolder_sub_VisualizeCircle, basename, Settings.CreateTimelapseFrameRate, Settings.CreateTimelapseImageCrop, Results.TimeFromStart, Settings.CreateTimelapseTimeScale)
    Logging(6, 'Timelapse creation finished successfully.')
end

%% 7 - Finish

elapsedtime = toc;
Logging(5, append('Code finished successfully in ', num2str(round(elapsedtime)), ' seconds.'))

clear elapsedtime


%% Functions

function SaveFigure(saving_on, fig, extensions, name, resolution)
    % Do some checks? isfig?
    if saving_on
        Logging(6, 'Figure saving in progress ...')
        for i = 1:length(extensions)
            if strcmpi(extensions{i}, 'fig')
                saveas(fig, name, extensions(i))
            else
                exportgraphics(fig, append(name, '.', extensions{i}), 'Resolution', resolution)
            end
        end
        Logging(6, 'Figure saved successfully.')
    end
end