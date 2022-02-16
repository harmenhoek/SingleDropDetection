clc; clear all; Settings = struct(); Settings.LensPresets = struct(); addpath('DropRadiusDetection\functions'); addpath('functions')

%% ABOUT
%{
    Harmen Hoek
    February 2022
    https://github.com/harmenhoek/SingleDropDetection

This code detects a single drop from an image file and extracts the radius and other parameters from it.
Input: image file(s) (png, tif(f), jp(e)g, bmp, gif). With single (dark) drop on lighter background. The greater the 
    contrast, the more accurate the results.
Output: Radius vs Time plot, images of circle fit and circle centroid for each image, result data including radius and time, 
    timelapse video of the circle fits. 


One or more images are loaded. Each image is converted to grayscale, then the black-white threshold is determined using 
Otsu's method and the image is converted to a binary image. The holes are filled (transmission holes inside drops). The 
connected components (CC) (groups of pixels that connect (diagonally included)) are determined. If the biggest CC is 2 times 
the size of the second biggest, the biggest CC is assumed to be the drop. From the total number of pixels, the Centroid, 
Area, Eccentricity, Circularity and Equivalent Diameter are determined (regionprops in MATLAB).
If the drop touches the border and `Settings.CircleFitting` is set to `boundaryonly`, or `Settings.CircleFitting` is set to 
`always`, the Equivalent Diameter is not a good estimate of the drop diameter. In that case the edge of the CC (excluding 
the one on the image boundary) is determined, and a circle is fitted to this boundary. This overwrites the Diameter then, 
and sets `Results.CircleFittingUsed` to true for that image (blue datapoint / circle in plots). 
These steps are repeated for all images. The time is either determined using a fixed time interval, or read automatically 
from the filename (see Settings). Data and plots are saved and a timelapse of the images with fitted circles is created.

Recommendation: Set `Settings.CircleFitting` to `always` or `never` to have consistent results.
%}

%% INPUT

% Settings.Source = 'data\rtanalysis_ozlem_drop3_selection';
% Settings.Source  = 'data\testdata\1-02012022151248-538.tiff';             
% Settings.Source  = 'data\testdata_small\';

Settings.Source = 'E:\R-t analysis\drop 3\';            % STRING with (local) path to file or folder with image files.
Settings.LensMagnification = 'NikonX4';                 % STRING optional Choose a lens preset used for this experiment to 
    % automatically determine the lateral conversion factor from pixels to meters. Valid options are: ZeisX2, ZeisX5, 
    % ZeisX10, NikonX2, NikonX4. More options can be added to Settings.
Settings.TimeInterval = 'FromFile';                     % STRING `'FromFile'` or NUMERIC If FromFile, the datetime stamp is 
    % read from the image filename. This datetime is converted to seconds from start automatically. 
    % `Settings.TimeIntervalFormat` and `Settings.TimeIntervalFilenameFormat` must be set. If NUMERIC, give the time in 
    % seconds between each frame.
    Settings.TimeIntervalFormat = "ddMMyyyyHHmmss";     % STRING datetime format. See MATLAB documentation on datetime.
    Settings.TimeIntervalFilenameFormat = {'-', '-'};   % CELL with 2 strings giving the pattern before the 
            % TimeIntervalFormat and after.
       % example: 1-02012022152110-1015 -->  {'-', '-'}, with Settings.TimeIntervalFormat = "ddMMyyyyHHmmss"
       % example: recording2022-02-01_15:13:12_image2 --> {'recording','_'}, with .TimeIntervalFormat = "yyyy-MM-dd_HH:mm:ss" 
                % note that it looks for the last occurance of '_'. '_image' would have given the same result.
Settings.ImageCrop = [0 0 0 32];                        % NUMERIC ARRAY Cropping image before analysis. A must if you have a 
    % death row/column of pixels. [top right down left].

% Settings.ConversionFactorPixToMm = [];                  % STRING optional Manually give the pixels to mm conversion. Only 
    % works if LensMagnification is not set. If LensMagnification and ConversionFactorPixToMm are not set, pixels are used 
    % as lateral unit.

%% SETTINGS

Settings.CircleFitting = 'always'; % STRING, choose `always`, `never`, `boundaryonly`. This determines the method used to 
    % determine the drop radius. Always uses circle fitting of the drop edge that does not  touch the border (drop can be 
    % partially out of frame for still good estimate of the radius). Never always uses the equivalent radius of the area of 
    % drop inside the frame to determine the radius. Boundary only uses circle fitting only when drop is moving out of frame.

Settings.ImageSkip = 1; % INTEGER Skip every ImageSkip frames. E.g. 3 analyzes frames 1 4 7, etc. alphabetical order of 
    % image file names.

% Conversion pix to SI
Settings.LensPresets.ZeisX2 = 677;                  % FLOAT   pixels per mm. Standard presets to use as conversion, assuming 
    % in focus. Add like .xMagnification = PixToMm.
Settings.LensPresets.ZeisX5 = 1837;                 % FLOAT   pixels per mm. 
Settings.LensPresets.ZeisX10 = 3679;                % FLOAT   pixels per mm. 
Settings.LensPresets.NikonX2 = 1355;                % FLOAT   pixels per mm. 
Settings.LensPresets.NikonX4 = 2700;                % FLOAT   pixels per mm. 

% Image processing
Settings.ImageProcessing.EnhanceContrast = true; % BOOLEAN enhance image contrast before analyzing (does not change much, 
    % since bw threshold is determined afterwards).

% Display settings
Settings.Display.IndividualPlots = true; % BOOLEAN Show plots on screen that are created with every iteration (image that 
    % shows the fit). Code asks to turn this off if there are >3 images, since it will flood memory.
Settings.Display.TotalPlots = true; % BOOLEAN Show plots that are created at the end of the code and only once (independent 
    % of number of images present).
Settings.Display.LogoAtStart = true; % BOOLEAN Show fancy logo and basic info at start of running code.

% Plotting 
Settings.Plot_VisualizeCircle = true; % BOOLEAN Plot (image) that shows the fit of and center of drop (a individual plot).
Settings.Plot_TimeVsRadius = true; % BOOLEAN Plot Time vs Radius at the end (a total plot).
    Settings.Plot_TimeVsRadius_LogX = true; % BOOLEAN X scale in log for Time vs Radius plot.
    Settings.Plot_TimeVsRadius_LogY = true; % BOOLEAN Y scale in log for Time vs Radius plot.

Settings.PlotFontSize = 15; % INTERGER Font size used in plots
Settings.FigureSize = [25 25 1000 800]; % NUMERIC ARRAY Figure size of plots shown. Even when plots are not shown, this is 
    % important, as it determines the ratio in which the image is saved. Larger size here does not change final image DPI, 
    % but does change how the FontSize looks.
Settings.FigureSaveResolution = 300; % INTEGER DPI (Pixels Per Inch) of figures that are saved.

% Saving
Settings.Save_Folder = 'E:\results'; % STRING (Local) path of location where data and images are saved.
Settings.Save_Figures = true; % BOOLEAN If true figures are saved automatically, even when not displayed to screen.
    Settings.Save_PNG = true; % BOOLEAN Save figures in PNG format.
    Settings.Save_TIFF = false; % BOOLEAN Save figures in TIFF format (note: slow and large file sizes).
    Settings.Save_FIG = false; % BOOLEAN Save figures in MATLAB FIG format.
Settings.Save_Data = true; % BOOLEAN Save the result data in the end automatically to .mat.
Settings.CreateTimelapse = true; % BOOLEAN If folder with images is analyzed, and the Plot_VisualizeCircle images are saved 
    % (PNG or TIFF), a timelapse can be created from these images, with a timestamp in the topleft.
    Settings.CreateTimelapseFrameRate = 15; % INTERGER Frames per second of the output timelapse.
    Settings.CreateTimelapseImageCrop = 0.5; % FLOAT [0-1] Image crop before making video.
    Settings.CreateTimelapseTimeScale = 'variable';  % STRING `variable`, `min`, `sec`, `hrs` or `auto`. The unit in which 
        % time is shown in the timelapse. Variable changes the unit (so starts at seconds, then switches to minutes and 
        % hours), auto uses one unit most appropriate for the length of the video. 


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

if Settings.Display.LogoAtStart
    clc
    ShowLogo
end

Logging(5, append('Code started on ', datestr(datetime('now')), '.'))

Logging(5, '---- Initialization and checking settings ----')


% Set default plotting sizes
set(0,'defaultAxesFontSize', Settings.PlotFontSize);

%not checked: Settings.TimeIntervalFilenameFormat, Settings.ImageCrop, Settings.FigureSize
status = CheckIfClass('numeric', {'Settings.ImageSkip', 'Settings.PlotFontSize', 'Settings.FigureSaveResolution', ...
    'Settings.CreateTimelapseFrameRate', 'Settings.CreateTimelapseImageCrop', 'Settings.', 'Settings.', 'Settings.'});
status2 = CheckIfClass('logical', {'Settings.EnhanceContrast', 'Settings.Save_Figures', 'Settings.Save_PNG', ...
    'Settings.Save_TIFF', 'Settings.Save_FIG', 'Settings.Display.LogoAtStart', 'Settings.Display.IndividualPlots', ...
    'Settings.Display.TotalPlots', 'Settings.Plot_VisualizeCircle', 'Settings.Plot_TimeVsRadius', ...
    'Settings.Plot_TimeVsRadius_LogX', 'Settings.Plot_TimeVsRadius_LogY', 'Settings.Save_Data', 'Settings.CreateTimelapse'});
status3 = CheckIfClass('char', {'Settings.Source', 'Settings.TimeintervalFormat', 'Settings.CircleFitting', ...
    'Settings.Save_Folder', 'Settings.CreateTimelapseTimeScale', 'Settings.', 'Settings.'});
if min([status, status2, status3]) == 0
    Logging(1, 'Could not continue because of invalid settings (see WARNINGs above).')
else
    Logging(6, 'Settings are all of the right type.')
end
clear status status2 status3

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
elseif CheckIfClass('numeric', {'Settings.TimeInterval'})
    Results.TimeFromStart = (1:Settings.ImageCount) * Settings.TimeInterval;
else
    Logging(1, append('Settings.TimeInterval= ', num2str(Settings.TimeInterval), ' is not a valid option. Choose "FromFile" or an integer.'))
end


%% Main loop

Logging(5, '---- Analyzing images ----')

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

if strcmpi(Settings.DistanceUnit, 'pix')
    Logging(3, 'No distance unit known, result data will not be converted to SI units.')
else
    Results.DiameterMet = Results.DiameterPix / Settings.ConversionFactorPixToMm;
    Results.AreaMet = Results.AreaPix / Settings.ConversionFactorPixToMm;
end

%% Plot Time vs Radius

Logging(5, '---- Plotting Total Plots ----')

if Settings.ImageCount > 1
    f2 = Plot.TimeVsRadius(Settings, struct('Results',Results, 'Settings',Settings));
    SaveFigure(min([Settings.Save_Figures Settings.Plot_TimeVsRadius]), f2, save_extensions, append(basename, '_TimeVsRadius'), Settings.FigureSaveResolution);
    if ~Settings.Display.TotalPlots; close(f2); end % must close, even if not visible, otherwise in memory
end

%% 6 - Save data

Logging(5, '---- Saving data ----')

if Settings.Save_Data
    save(append(basename, '_results.mat'), 'Settings', 'Results')
end

Logging(6, 'Saving finished successfully.')

%% Create TimeLapse Video

if Settings.CreateTimelapse && Settings.ImageCount > 1 && (Settings.Save_PNG == true || Settings.Save_TIFF == true)
    Logging(5, '---- Creating Timelapse ----')
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


%% TODO
%{
- check settings and input
- determine time from filename
- what if drop is outside limits?
- create timelapse in the end
- Plot eccentricity, surface area, circularity
- Plot centroids: a tail on the image
- Check if all filenames satisfy TimeIntervalFormat before running code.
I.e. calculate this beforehand, not during the main loop.

%}