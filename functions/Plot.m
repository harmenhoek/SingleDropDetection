classdef Plot
    methods (Static)
        
        function f = VisualizeCircle(Settings, FigData)
            if Settings.Plot_VisualizeCircle && (Settings.Save_Figures || Settings.Display.IndividualPlots)
                if Settings.Display.IndividualPlots
                    f = figure('visible', 'on');
                else
                    f = figure('visible', 'off');
                end
                f.Position = Settings.FigureSize;
                
                if FigData.CircleFittingUsed
                    pltclr = 'blue';
                else
                    pltclr = 'red';
                end
                
                img = insertShape(FigData.I, 'Circle', [FigData.Centroid(1) FigData.Centroid(2) FigData.DiameterPix/2], 'Color', pltclr, 'LineWidth', 10);
                imshow(img)
                hold on
%                 viscircles(FigData.Centroid, FigData.DiameterPix/2, 'LineWidth', 5, 'Color', pltclr); %DO NOT USE, DRAWS OUTSIDE IMAGE BORDERS.
                plot(FigData.Centroid(1), FigData.Centroid(2), 'b*', 'Color', pltclr, 'MarkerSize', 100, 'LineWidth', 3)
                plot(FigData.Centroid(1), FigData.Centroid(2), '.', 'Color', pltclr, 'MarkerSize', 50)
    
            else
                f = [];
            end
        end % f = VisualizeCircle



        function f = TimeVsRadius(Settings, FigData)
            if Settings.Plot_TimeVsRadius && (Settings.Save_Figures || Settings.Display.TotalPlots)
                if Settings.Display.TotalPlots
                    f = figure('visible', 'on');
                else
                    f = figure('visible', 'off');
                end
                f.Position = Settings.FigureSize;
                
                if strcmpi(Settings.DistanceUnit, 'pix')
                    y = FigData.Results.DiameterPix/2;
                else
                    y = FigData.Results.DiameterMet/2;
                end
                
                clrs = cell(1, Settings.ImageCount);
                clrs(:) = {'red'};
                clrs(find(FigData.Results.CircleFittingUsed)) = {'blue'};  %must be find to get indx, Matlab ......

                
                x = FigData.Results.TimeFromStart;
                
                hold on
                for ii = 1:Settings.ImageCount
                    plot(x(ii), y(ii), '.', 'Color', clrs{ii}, 'MarkerSize', 15)
                end
                xlabel('Time [s]')
                ylabel(sprintf('Radius [%s]', Settings.DistanceUnit))
                
                if Settings.Plot_TimeVsRadius_LogX
                    set(gca, 'XScale', 'log')
                end
                if Settings.Plot_TimeVsRadius_LogY
                    set(gca, 'YScale', 'log')
                end
                
                
            else
                f = [];
            end
        end % f = TimeVsRadius

    end % methods
end % classdef