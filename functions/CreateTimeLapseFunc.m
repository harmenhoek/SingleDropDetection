function CreateTimeLapseFunc(SourceFolder, OutputFile, FrameRate, Resize, TimeInterval, TimeUnit)
    addpath('functions')

    Settings = struct();
    Settings.ImageSkip = 1;
    Settings.FrameRate = FrameRate;
    Settings.Resize = Resize;
	Settings.Time.Interval = TimeInterval;
    Settings.Time.ShowTime = true;
    Settings.Time.FontSize = 40;
    Settings.Time.Round = 0;
    Settings.Time.Unit = TimeUnit;
    Settings.Source = SourceFolder;


    %% Load Files

    tic
    Settings.Source_ImageList = {};
    if ~isempty(dir(append(Settings.Source, '\*', '.png'))) % prefer png over tiff
        ext = '.png';
    elseif ~isempty(dir(append(Settings.Source, '\*', '.tiff')))
        ext = '.tiff';
    elseif ~isempty(dir(append(Settings.Source, '\*', '.tif')))
        ext = '.tif';
    else
        Logging(3, 'No valid images found to create timelapse, timelapse not created.')
        return
    end
    images = dir(append(Settings.Source, '\*', ext));
    images_fullpath = cellfun(@(x) append(x.folder, '\', x.name), num2cell(images), 'UniformOutput', false);
    Settings.Source_ImageList = [Settings.Source_ImageList, images_fullpath];
    
    Settings.Source_ImageList = natsortfiles(Settings.Source_ImageList); % Stephen (2022). Natural-Order Filename Sort (https://www.mathworks.com/matlabcentral/fileexchange/47434-natural-order-filename-sort), MATLAB Central File Exchange. Retrieved January 27, 2022. 
    Settings.Analysis_ImageList = Settings.Source_ImageList(1:Settings.ImageSkip:length(Settings.Source_ImageList));

    % Check maximum frame size in folder
    % Reference dimensions
    % Matlab does not save the file in the save dimensions every time, for
    % some weird reason (depends on screen resolution ...). Matlab is
    % stupid, we know that already. The point is that we set the first
    % image as a reference size, and resize all other images to match this
    % one. We could determine the maximum image size of all images, but
    % that takes waaaaay toooo looonnggg.
    ImageDimensions_Reference = [imfinfo(Settings.Analysis_ImageList{1}).Width, imfinfo(Settings.Analysis_ImageList{1}).Height]; % use first image as a reference




    %% Create video
    
    TimeRemaining = TimeTracker;
    TimeRemaining = Initiate(TimeRemaining,  length(Settings.Analysis_ImageList), 0);

    outputVideo = VideoWriter(OutputFile);
    outputVideo.FrameRate = Settings.FrameRate;
    
    open(outputVideo)
    for ii = 1:length(Settings.Analysis_ImageList)
        TimeRemaining = StartIteration(TimeRemaining);
        Image = Settings.Analysis_ImageList{ii};
        
        img = imread(Settings.Analysis_ImageList{ii});

        ImageDimensions = [imfinfo(Image).Width, imfinfo(Image).Height];
        if ~min(ImageDimensions_Reference == ImageDimensions) %resize image
            img = imresize(img, [ImageDimensions_Reference(2) ImageDimensions_Reference(1)]);
        end

        img = imresize(img, Settings.Resize);

        
        if Settings.Time.ShowTime
            t = Settings.Time.Interval((ii-1)*Settings.ImageSkip+1);     
            if strcmpi(Settings.Time.Unit, 'variable')           
                if t < 60
                    StrTime = append(num2str(t), ' s');
                elseif t < 3600
                    StrTime = append(num2str(round(t/60,Settings.Time.Round)), ' min');
                else
                    StrTime = append(num2str(round(t/3600,Settings.Time.Round)), ' hours');
                end
            elseif strcmpi(Settings.Time.Unit, 'sec')
                StrTime = append(num2str(t), ' s');
            elseif strcmpi(Settings.Time.Unit, 'min')
                StrTime = append(num2str(round(t/60,Settings.Time.Round)), ' min');
            elseif strcmpi(Settings.Time.Unit, 'hrs')
                StrTime = append(num2str(round(t/3600,Settings.Time.Round)), ' hours');
            elseif strcmpi(Settings.Time.Unit, 'auto')
                totaltime = Settings.Time.Interval(end);
                if totaltime < 60
                    StrTime = append(num2str(t), ' s');
                elseif totaltime < 3600
                    StrTime = append(num2str(round(t/60,Settings.Time.Round)), ' min');
                else
                    StrTime = append(num2str(round(t/3600,Settings.Time.Round)), ' hours');
                end
            else
                Logging(1, append('No valid Settings.Time.Unit = "', num2str(Settings.Time.Unit), '". Choose variable, sec, min, hrs, auto.'))
            end

            img = insertText(img, [10 10], ...
                append('t = ', StrTime), ...
                'FontSize', Settings.Time.FontSize, ...
                'BoxColor', 'white', ...
                'BoxOpacity', 0.4, ...
                'TextColor', 'black');
            writeVideo(outputVideo, img)
        end
        
        [TimeRemaining, TimeLeft] = EndIteration(TimeRemaining);
        if TimeLeft
            Logging(5, append('TimeLapse creation: ', TimeLeft))
        end
    
    end
    close(outputVideo)


end
