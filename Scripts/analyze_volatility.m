% [INPUT]
% ticker = A string representing the reference ticker symbol.
% data = A t-by-6 table containing the following time series:
%   - Date (numeric observation dates)
%   - Open (opening prices)
%   - High (highest prices)
%   - Low (lowest prices)
%   - Close (closing prices)
%   - Return (log returns)
% e = A string representing the historical volatility estimator, its value can be one of the following:
%   - CC (the traditional Close-to-Close estimator)
%   - CCD (a variant of the previous estimator that uses demeaned returns)
%   - GK (the estimator proposed by Garman & Klass, 1980)
%   - GKYZ (a extension of the previous estimator proposed by Yang & Zhang, 2000)
%   - HT (the estimator proposed by Hodges & Tompkins, 2002)
%   - M (the estimator proposed by Meilijson, 2009)
%   - P (the estimator proposed by Parkinson, 1980)
%   - RS (the estimator proposed by Rogers & Satchell, 1991)
%   - YZ (the estimator proposed by Yang & Zhang, 2000)
% bws = A vector of integers representing the bandwidths (dimensions) of each rolling window (optional, default=[30 60 90 120]).
% qs = A vector of two floats containing the lower quantile and the upper quantile (optional, default=[0.25 0.75]).

function analyze_volatility(varargin)

    persistent ip;

    if (isempty(ip))
        ip = inputParser();
        ip.addRequired('ticker',@(x)validateattributes(x,{'char'},{'nonempty' 'size' [1 NaN]}));
        ip.addRequired('data',@(x)validateattributes(x,{'table'},{'2d' 'nonempty' 'ncols' 6}));
        ip.addRequired('e',@(x)any(validatestring(x,{'CC' 'CCD' 'GK' 'GKYZ' 'HT' 'M' 'P' 'RS' 'YZ'})));
        ip.addOptional('bws',[30 60 90 120],@(x)validateattributes(x,{'numeric'},{'real' 'finite' 'integer' 'increasing' '>=' 2 '<=' 252 'vector' 'nonempty'}));
        ip.addOptional('qs',[0.25 0.75],@(x)validateattributes(x,{'numeric'},{'real' 'finite' 'increasing' '>' 0 '<' 1 'vector' 'numel' 2}));
    end

    ip.parse(varargin{:});
    
    ipr = ip.Results;
    ticker = ipr.ticker;
    data = validate_data(ipr.data);
    e = ipr.e;
    bws = validate_bandwidths(ipr.bws,data);
    qs = validate_quantiles(ipr.qs);
    
    nargoutchk(0,0);

    analyze_volatility_internal(ticker,data,e,bws,qs);
    
end

function analyze_volatility_internal(ticker,data,e,bws,qs)

    t = height(data);
    k = numel(bws);
    
    years = year(data.Date);
    year_start = min(years);
    year_end = max(years);

    pd = struct();

    pd.Bws = bws;
    pd.Dates = data.Date;
    pd.QH = qs(2);
    pd.QL = qs(1);

    pd.Vols = NaN(t,k);
    pd.VolsEnd = zeros(k,1);  
    pd.VolsHigh = zeros(k,1);
    pd.VolsLow = zeros(k,1);
    pd.VolsMax = zeros(k,1);
    pd.VolsMed = zeros(k,1);
    pd.VolsMin = zeros(k,1);    

    for i = 1:k
        vol = estimate_volatility(data,e,bws(i),false);
        vol_end = vol(end);

        pd.Vols(:,i) = vol;
        pd.VolsEnd(i) = vol_end;
        pd.VolsHigh(i) = quantile(vol,qs(2));
        pd.VolsLow(i) = quantile(vol,qs(1));
        pd.VolsMax(i) = max(vol,[],'omitnan');
        pd.VolsMed(i) = median(vol,'omitnan');
        pd.VolsMin(i) = min(vol,[],'omitnan');

        if (i == 1)
            pd.Vol = vol;
            pd.VolEnd = vol_end;
        end   
    end
    
    pd.PlotsAxisMax = ceil(max(pd.VolsMax) * 100) / 100;
    pd.PlotsAxisMin = floor(min(pd.VolsMin) * 100) / 100;

    if (year_start == year_end)
        pd.PlotsTitle = [e '(' ticker ',' num2str(year_start) ')'];
    else
        pd.PlotsTitle = [e '(' ticker ',' num2str(year_start) '-' num2str(year_end) ')'];
    end

    plot_cones(pd);
    plot_curves(pd);
    plot_distribution(pd);

end

function plot_cones(pd)

    f = figure('Name',[pd.PlotsTitle ' > Volatility Cones'],'Units','normalized','Position',[100 100 0.85 0.85]);
    
    sub_1 = subplot(1,3,1:2);
    plot(sub_1,pd.Bws,pd.VolsMax,'-r',pd.Bws,pd.VolsHigh,'-b',pd.Bws,pd.VolsMed,'-g',pd.Bws,pd.VolsLow,'-c',pd.Bws,pd.VolsMin,'-k',pd.Bws,pd.VolsEnd,'--m');
    xlabel(sub_1,'Bandwidth');
    ylabel(sub_1,'Volatility');
    set(sub_1,'XLim',[min(pd.Bws) max(pd.Bws)],'XTick',pd.Bws,'XTickLabel',pd.Bws);
    set(sub_1,'XGrid','on','YGrid','on');
    legend(sub_1,'Maximum',sprintf('%.0f Percentile',(pd.QL * 100)),'Median',sprintf('%.0f Percentile',(pd.QH * 100)),'Minimum','Realized','Location','best');
    
    sub_2 = subplot(1,3,3);
    boxplot(sub_2,pd.Vols,pd.Bws,'Notch','on','Symbol','k.');
    hold on;
        plot(sub_2,1:numel(pd.Bws),pd.VolsEnd,'-m','Marker','*','MarkerEdgeColor','k');
    hold off;
    set(sub_2,'YAxisLocation','right');
    set(findobj(f,'type','line','Tag','Median'),'Color','g');
    set(findobj(f,'-regexp','Tag','\w*Whisker'),'LineStyle','-');

    y_ticks = str2double(get(sub_1,'YTickLabel'));
    y_tick_labels = arrayfun(@(x)sprintf('%.0f%%',x),(get(sub_2,'YTick') .* 100),'UniformOutput',false);
    set([sub_1 sub_2],'YLim',[pd.PlotsAxisMin pd.PlotsAxisMax],'YTick',y_ticks,'YTickLabel',y_tick_labels);

    figure_title([pd.PlotsTitle ' > Volatility Cones']);

    pause(0.01);
    frame = get(f,'JavaFrame');
    set(frame,'Maximized',true);

end

function plot_curves(pd)

    vol_win = extract_rolling_windows(pd.Vol,pd.Bws(1),true);
    vol_diff = NaN(length(pd.Vol) - size(vol_win,1),1);
    vol_max = [vol_diff; cellfun(@(x)max(x,[],'omitnan'),vol_win)];
    vol_hi = [vol_diff; cellfun(@(x)quantile(x,pd.QH),vol_win)];
    vol_med = [vol_diff; cellfun(@(x)median(x,'omitnan'),vol_win)];
    vol_lo = [vol_diff; cellfun(@(x)quantile(x,pd.QL),vol_win)];
    vol_min = [vol_diff; cellfun(@(x)min(x,[],'omitnan'),vol_win)];

    f = figure('Name',[pd.PlotsTitle ' > Volatility Curves'],'Units','normalized','Position',[100 100 0.85 0.85]);

    sub_1 = subplot(1,5,1:4);
    plot(sub_1,pd.Dates,vol_max,':r',pd.Dates,vol_hi,':b',pd.Dates,vol_med,':g',pd.Dates,vol_lo,':c',pd.Dates,vol_min,':k',pd.Dates,pd.Vol,'-m');
    datetick(sub_1,'x','mm/yy');
    xlabel(sub_1,'Time');
    ylabel(sub_1,'Volatility');
    set(sub_1,'XMinorTick','on','XTickLabelRotation',45);
    set(sub_1,'XGrid','on','YGrid','on');
    legend(sub_1,'Maximum',sprintf('%.0f Percentile',(pd.QL * 100)),'Median',sprintf('%.0f Percentile',(pd.QH * 100)),'Minimum','Realized','Location','best');

    sub_2 = subplot(1,5,5);
    boxplot(sub_2,pd.Vol,pd.Bws(1),'Notch','on','Symbol','k.');
    hold on;
        plot(sub_2,1,pd.VolEnd,'-m','Marker','*','MarkerEdgeColor','k');
    hold off;
    set(sub_2,'XTick',[],'XTickLabel',[],'YAxisLocation','right');
    set(findobj(f,'type','line','Tag','Median'),'Color','g');
    set(findobj(f,'-regexp','Tag','\w*Whisker'),'LineStyle','-');

    y_ticks = str2double(get(sub_1,'YTickLabel'));
    y_tick_labels = arrayfun(@(x)sprintf('%.0f%%',x),(get(sub_2,'YTick') .* 100),'UniformOutput',false);
    set([sub_1 sub_2],'YLim',[pd.PlotsAxisMin pd.PlotsAxisMax],'YTick',y_ticks,'YTickLabel',y_tick_labels);
    
    figure_title([pd.PlotsTitle ' > Volatility Curves']);

    pause(0.01);
    frame = get(f,'JavaFrame');
    set(frame,'Maximized',true);

end

function plot_distribution(pd)

    f = figure('Name',[pd.PlotsTitle ' > Volatility Distribution'],'Units','normalized','Position',[100 100 0.6 0.6]);

    hist = histogram(pd.Vol,100,'FaceColor',[0.749 0.862 0.933],'Normalization','pdf');
    
    ax = gca();
    
    hold on;
        edges = get(hist,'BinEdges');
        norm = normpdf(edges,mean(pd.Vol,'omitnan'),std(pd.Vol,'omitnan'));
        plot(ax,edges,norm,'Color',[0.000 0.447 0.741]);
        plot(ax,[pd.VolEnd pd.VolEnd],get(ax,'YLim'),'Color',[1 0.4 0.4]);
    hold off;

    x_tick_labels = arrayfun(@(x)sprintf('%.0f%%',x),(get(ax,'XTick') .* 100),'UniformOutput',false);
    set(ax,'XTickLabel',x_tick_labels);
    set(ax,'YGrid','on');

    figure_title([pd.PlotsTitle ' > Volatility Distribution']);

    pause(0.01);
    frame = get(f,'JavaFrame');
    set(frame,'Maximized',true);

end

function bws = validate_bandwidths(bws,data)

    bws_len = length(bws);

    if (bws_len < 2)
        error(['The value of ''bws'' is invalid.' newline() 'Expected input to contain at least 2 elements.']);
    end

    if (bws(end) >= height(data))
        error(['The value of ''bws'' is invalid.' newline() 'Expected input last value to be less than tne number of observations.']);
    end

end

function data = validate_data(data)

    vn = {'Date' 'Open' 'High' 'Low' 'Close' 'Return'};

    if (~all(ismember(vn,data.Properties.VariableNames)))
        error(['The value of ''data'' is invalid.' newline() 'Expected input to contain the following time series: ' vn{1} sprintf(', %s',vn{2:end}) '.']);
    end

end

function qs = validate_quantiles(qs)

    if (sum(qs) ~= 1)
        error(['The value of ''qs'' is invalid.' newline() 'Expected input to contain elements whose sum is equal to 1.']);
    end

end
