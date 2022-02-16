# SingleDropDetection
 
This code detects a single drop from an image file and extracts the radius and other parameters from it.<br>
Input: image file(s) (png, tif(f), jp(e)g, bmp, gif). With single (dark) drop on lighter background. The greater the contrast, the more accurate the results.
Output: Radius vs Time plot, images of circle fit and circle centroid for each image, result data including radius and time, timelapse video of the circle fits. 

## Workings
One or more images are loaded. Each image is converted to grayscale, then the black-white threshold is determined using Otsu's method and the image is converted to a binary image. The holes are filled (transmission holes inside drops). The connected components (CC) (groups of pixels that connect (diagonally included)) are determined. If the biggest CC is 2 times the size of the second biggest, the biggest CC is assumed to be the drop. From the total number of pixels, the Centroid, Area, Eccentricity, Circularity and Equivalent Diameter are determined (regionprops in MATLAB).<br>
If the drop touches the border and `Settings.CircleFitting` is set to `boundaryonly`, or `Settings.CircleFitting` is set to `always`, the Equivalent Diameter is not a good estimate of the drop diameter. In that case the edge of the CC (excluding the one on the image boundary) is determined, and a circle is fitted to this boundary. This overwrites the Diameter then, and sets `Results.CircleFittingUsed` to true for that image (blue datapoint / circle in plots). <br>
These steps are repeated for all images. The time is either determined using a fixed time interval, or read automatically from the filename (see Settings). Data and plots are saved and a timelapse of the images with fitted circles is created.<br>
<br>
Recommendation: Set `Settings.CircleFitting` to `always` or `never` to have consistent results.



## Settings
###Input settings
- `Settings.Source` --> STRING with (local) path to file or folder with image files.
- `Settings.TimeInterval` --> STRING `'FromFile'` or NUMERIC If FromFile, the datetime stamp is read from the image filename. This datetime is converted to seconds from start automatically. `Settings.TimeIntervalFormat` and `Settings.TimeIntervalFilenameFormat` must be set. If NUMERIC, give the time in seconds between each frame.
    - `Settings.TimeIntervalFormat` --> STRING datetime format. See MATLAB documentation on datetime.
    - `Settings.TimeIntervalFilenameFormat` --> CELL with 2 strings giving the pattern before the TimeIntervalFormat and after. <br> example: image filename: recording2022-02-01_15:13:12\_image2.tiff <br> Settings.TimeIntervalFormat = "yyyy-MM-dd_HH:mm:ss" <br> Settings.TimeIntervalFilenameFormat = {'recording','\_'} <br> This extract the time: 2022-02-01 15:13:12 <br>
  Note that it looks for the last occurance of '\_'. '_image' would have given the same result.
- `Settings.ImageCrop` --> NUMERIC ARRAY Cropping image before analysis. A must if you have a death row/column of pixels. [top right down left].
- `Settings.LensMagnification` --> STRING optional Choose a lens preset used for this experiments to automatically determine the lateral conversion factor from pixels to meters. Valid options are: ZeisX2, ZeisX5, ZeisX10, NikonX2, NikonX4. More options can be added to Settings.
- `Settings.ConversionFactorPixToMm` --> STRING optional Manually give the pixels to mm conversion. Only works if LensMagnification is not set. If LensMagnification and ConversionFactorPixToMm are not set, pixels are used as lateral unit.

### General settings
- `Settings.CircleFitting` --> STRING, choose `always`, `never`, `boundaryonly`. This determines the method used to determine the drop radius. Always uses circle fitting of the drop edge that does not touch the border (drop can be partially out of frame for still good estimate of the radius). Never always uses the equivalent radius of the area of drop inside the frame to determine the radius. Boundary only uses circle fitting only when drop is moving out of frame.
- `Settings.ImageSkip` --> INTEGER Skip every ImageSkip frames. E.g. 3 analyzes frames 1 4 7, etc. alphabetical order of image file names.
- `Settings.ImageProcessing.EnhanceContrast` --> BOOLEAN enhance image contrast before analyzing (does not change much, since bw threshold is determined afterwards).
- `Settings.Display.IndividualPlots` --> BOOLEAN Show plots on screen that are created with every iteration (image that shows the fit). Code asks to turn this off if there are >3 images, since it will flood memory.
- `Settings.Display.TotalPlots` --> BOOLEAN Show plots that are created at the end of the code and only once (independent of number of images present).
- `Settings.Plot_VisualizeCircle` --> BOOLEAN Plot (image) that shows the fit of and center of drop (a individual plot).
- `Settings.Plot_TimeVsRadius` --> BOOLEAN Plot Time vs Radius at the end (a total plot).
    - `Settings.Plot_TimeVsRadius_LogX` --> BOOLEAN X scale in log for Time vs Radius plot.
    - `Settings.Plot_TimeVsRadius_LogY` --> BOOLEAN Y scale in log for Time vs Radius plot.
- `Settings.PlotFontSize` --> INTERGER Font size used in plots
- `Settings.FigureSize` --> NUMERIC ARRAY Figure size of plots shown. Even when plots are not shown, this is important, as it determines the ratio in which the image is saved. Larger size here does not change final image DPI, but does change how the FontSize looks.
- `Settings.FigureSaveResolution` --> DPI (Pixels Per Inch) of figures that are saved.
- `Settings.Save_Folder` --> STRING (Local) path of location where data and images are saved.
- `Settings.Save_Figures` --> BOOLEAN If true figures are saved automatically, even when not displayed to screen.
    - `Settings.Save_PNG` --> BOOLEAN Save figures in PNG format.
    - `Settings.Save_TIFF` --> BOOLEAN Save figures in TIFF format (note: slow and large file sizes).
    - `Settings.Save_FIG` --> BOOLEAN Save figures in MATLAB FIG format.
- `Settings.Save_Data` --> BOOLEAN Save the result data in the end automatically to .mat.
- `Settings.CreateTimelapse` --> BOOLEAN If folder with images is analyzed, and the Plot_VisualizeCircle images are saved (PNG or TIFF), a timelapse can be created from these images, with a timestamp in the topleft.
    - `Settings.CreateTimelapseFrameRate` --> INTERGER Frames per second of the output timelapse.
    - `Settings.CreateTimelapseImageCrop` --> FLOAT [0-1] Image crop before making video.
    - `Settings.CreateTimelapseTimeScale` --> STRING `variable`, `min`, `sec`, `hrs` or `auto`. The unit in which time is shown in the timelapse. Variable changes the unit (so starts at seconds, then switches to minutes and hours), auto uses one unit most appropriate for the length of the video. 
    
## Screenshots
| Input image                             | Output image | Time vs radius plot |
| ------------------------------------------------------------ | ------------------------------------------------------------ |------------------------------------------------------------ |
| <img src="screenshots\raw_image.jpg" style="zoom: 33%;" /> | <img src="screenshots\fitted_drop.png" style="zoom: 33%;" /> |<img src="screenshots\timevsradius.png" style="zoom: 33%;" /> |



## Functions

### CheckIfClass.m
Adapted from harmenhoek/Interferometry

`[status] = CheckIfClass(checkclass, variables)`
CheckIfClass  Checks if the input variables (cell with variables as strings) are all of the type checkclass ('logical', 'char' or 'numeric').
   [status] = CheckIfClass(checkclass, variables) 
Displays to screen the variables that are do not satisfy the checkclass and returns 'status' which is 0 if checks fail (this allows to see a list of all variables that need to be fixed.

Function needs Logging.m!

Example:
    `variable1 = 'This is a string';`
    `variable2 = true;`
    `variable3 = 34.53;`
    `[status] = CheckIfClass('logical', {'variable1', 'variable2', 'variable3'}`
Result:
    `WARNING   Variable "variable1" should be logical, but is not (currently a char).`
    `WARNING   Variable "variable3" should be logical, but is not (currently a double).`
    `status =`
    `       0`

Input:

- `checkclass` is a string with the dataclass to check against ('logical', 'char' or 'numeric').
- `variables` is a cell with variables as strings.

Output:

- Output to screen with variables that fail check.
- `status` is 0 when one or more checks fail, 1 when all pass.

### circfit.m
Fits a circle to a given set of x,y. Return [centroid\_x, centroid\_y, radius].

### CreateTimeLapseFunc.m
TO BE DOCUMENTED

### ExtractSubstrFromString.m
TO BE DOCUMENTED

### Logging.m
Adapted from harmenhoek/Interferometry

`function Logging(type, message)`
To log a message to the screen in a consistent format.

Input: 

- `type` is the number corresponding to a type of message:

  | `type` | Message  | Color             | Explanation                                                  |
  | ------ | -------- | ----------------- | ------------------------------------------------------------ |
  | 1      | ERROR    | red               | Code cannot continue. Will throw an error and stop execution. |
  | 2      | ACTION   | blue (underlined) | User needs to do something.                                  |
  | 3      | WARNING  | orange            | Code can continue, but user should note something (decision made by code e.g.). |
  | 4      | PROGRESS | white             | Show user that something is being done now, e.g. when wait is long. |
  | 5      | INFO     | cyan              | Information about code progress. E.g. 'Figures are being saved'. |
  | 6      | OK       | green             | Just to show progress is going on as planned.                |

- `message` is a string with the message.

Output:

<img src="screenshots\Logging_output.png" style="zoom:75%; align:left;" />

Usage:

- At the top of the code, define the log level (if not, only error messages are shown).
  `global LogLevel` defines a global variable
  `LogLevel = 3` sets the log level. All log messages in the code set to `type`<= 3 will be shown.

- In the code, use when needed

  `Logging(3, 'This is a warning, and will be displayed orange')`to display a warning, for example.

### natsort.m
Sort files in a smart way. <br>
 Stephen (2022). Natural-Order Filename Sort (https://www.mathworks.com/matlabcentral/fileexchange/47434-natural-order-filename-sort), MATLAB Central File Exchange. Retrieved February 16, 2022. 

### natsorfiles.m
Sort files in a smart way. <br>
 Stephen (2022). Natural-Order Filename Sort (https://www.mathworks.com/matlabcentral/fileexchange/47434-natural-order-filename-sort), MATLAB Central File Exchange. Retrieved February 16, 2022. 

## Plot.m
A class with static methods that contain all the plots. Static so no instance has to be created.
These functions create all the plots. They are called in the code by `Plot.`. It's a class so that we can merge a bunch of functions in a single file, not something MATLAB usually can.

## TimeTracker.m
A class to estimate and display the time left for the total code to complete, based on an average time per iteration. Does not have to be a class, but as a side project, was playing around with that. <br>
Initiate before loop with: `TimeRemaining = TimeTracker; TimeRemaining = Initiate(TimeRemaining, TotalIterations, ExtraTimeOffset);` <br>
At start of every loop: `TimeRemaining = StartIteration(TimeRemaining);`<br>
At the end of every loop: `[TimeRemaining, TimeLeft] = EndIteration(TimeRemaining);`.<br><br>
Full example:<br>
<code> 
TimeRemaining = TimeTracker;<br>
TimeRemaining = Initiate(TimeRemaining,  100, 1.5);<br>
for i = 1:100<br>
    TimeRemaining = StartIteration(TimeRemaining);<br>
    % do stuff here<br>
    [TimeRemaining, TimeLeft] = EndIteration(TimeRemaining);<br>
    if TimeLeft<br>
        Logging(5, TimeLeft)<br>
    end<br>
end<br>
</code>

TO BE DOCUMENTED MORE