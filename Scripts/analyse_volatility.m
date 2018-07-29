% [INPUT]
% tkr      = A string representing the ticker symbol.
% year_beg = An integer representing the start year.
% year_end = An integer representing the end year.
% est      = A string representing the historical volatility estimator, its value can be one of the following:
%             - CC (the traditional Close-to-Close estimator)
%             - CCD (a variant of the previous estimator that uses demeaned returns)
%             - GK (the estimator proposed by Garman & Klass, 1980)
%             - GKYZ (a extension of the previous estimator proposed by Yang & Zhang, 2000)
%             - HT (the estimator proposed by Hodges & Tompkins, 2002)
%             - M (the estimator proposed by Meilijson, 2009)
%             - P (the estimator proposed by Parkinson, 1980)
%             - RS (the estimator proposed by Rogers & Satchell, 1991)
%             - YZ (the estimator proposed by Yang & Zhang, 2000)
% bws      = A vector of integers representing the bandwidths (dimensions) of each rolling window (optional, default=[30 60 90 120]).
% qnts     = A vector of two floats containing the lower quantile and the upper quantile (optional, default=[0.25 0.75]).
%
% [NOTES]
% This function produces no outputs, its purpose is to show analysis results.

function analyse_volatility(varargin)

    persistent ip;

    if (isempty(ip))
        ip = inputParser();
        ip.addRequired('tkr',@(x)validateattributes(x,{'char'},{'nonempty','size',[1,NaN]}));
        ip.addRequired('year_beg',@(x)validateattributes(x,{'numeric'},{'scalar','integer','real','finite','>=',1970}));
        ip.addRequired('year_end',@(x)validateattributes(x,{'numeric'},{'scalar','integer','real','finite','>=',1970}));
        ip.addRequired('est',@(x)any(validatestring(x,{'CC','CCD','GK','GKYZ','HT','M','P','RS','YZ'})));
        ip.addOptional('bws',[30 60 90 120],@(x)validateattributes(x,{'numeric'},{'vector','integer','real','finite','>=',2,'increasing'}));
        ip.addOptional('qnts',[0.25 0.75],@(x)validateattributes(x,{'numeric'},{'vector','numel',2,'integer','real','finite','increasing','>',0,'<',1}));
    end

    ip.parse(varargin{:});
    
    ip_res = ip.Results;
    tkr = ip_res.tkr;
    year_beg = ip_res.year_beg;
    year_end = ip_res.year_end;
    est = ip_res.est;
    bws = ip_res.bws;
    qnts = ip_res.qnts;

    if (year_beg > year_end)
        error('The start year must be less than or equal to the end year.');
    end
    
    bws_len = length(bws);

    if (bws_len < 2)
        error('Two or more bandwidths are required.');
    end
    
    if ((qnts(1) + qnts(2)) ~= 1)
        error('The sum of the quantiles must be equal to 1.');
    end
    
    analyse_volatility_internal(tkr,year_beg,year_end,est,bws,bws_len,qnts);
    
end

function analyse_volatility_internal(tkr,year_beg,year_end,est,bws,bws_len,qnts)

    date_beg = datestr(datenum(year_beg,1,1),'yyyy-mm-dd');
    date_end = datestr(datenum(year_end,12,31),'yyyy-mm-dd');

    data = fetch_data(tkr,date_beg,date_end);
    t = size(data,1);
    
    if (bws(end) >= t)
        error('The number of observations must be greater than the greatest bandwidth.');
    end
    
    pd = struct();
    pd.Bw = bws(1);
    pd.Bws = bws;
    pd.BwsLen = bws_len;
    pd.Dates = data.Date;
    pd.Obs = t;
    pd.QntHigh = qnts(2);
    pd.QntLow = qnts(1);
    pd.PrcHigh = sprintf('%.0f Percentile',(pd.QntHigh * 100));
    pd.PrcLow = sprintf('%.0f Percentile',(pd.QntLow * 100));
    pd.Vols = NaN(pd.Obs,bws_len);
    pd.VolsEnd = zeros(bws_len,1);  
    pd.VolsHigh = zeros(bws_len,1);
    pd.VolsLow = zeros(bws_len,1);
    pd.VolsMax = zeros(bws_len,1);
    pd.VolsMed = zeros(bws_len,1);
    pd.VolsMin = zeros(bws_len,1);    
    pd.YBeg = year_beg;
    pd.YEnd = year_end;

    for i = 1:bws_len
        vol = estimate_volatility(data,est,bws(i),false);
        vol_end = vol(end);

        pd.Vols(:,i) = vol;
        pd.VolsEnd(i) = vol_end;
        pd.VolsHigh(i) = quantile(vol,qnts(2));
        pd.VolsLow(i) = quantile(vol,qnts(1));
        pd.VolsMax(i) = nanmax(vol);
        pd.VolsMed(i) = nanmedian(vol);
        pd.VolsMin(i) = nanmin(vol);

        if (i == 1)
            pd.Vol = vol;
            pd.VolEnd = vol_end;
        end   
    end
    
    pd.AxisMax = ceil(max(pd.VolsMax) * 100) / 100;
    pd.AxisMin = floor(min(pd.VolsMin) * 100) / 100;

    if (year_beg == year_end)
        pd.Title = [tkr ' ' num2str(year_beg) ' | ' est];
    else
        pd.Title = [tkr ' ' num2str(year_beg) '-' num2str(year_end) ' | ' est];
    end

    plot_cones(pd);
    plot_curves(pd);
    plot_distribution(pd);

end

function plot_cones(pd)

    fig = figure('Name',[pd.Title ' | Volatility Cones'],'Units','normalized','Position',[100 100 0.85 0.85]);
    
    sub_1 = subplot(1,3,1:2);
    plot(sub_1,pd.Bws,pd.VolsMax,'-r',pd.Bws,pd.VolsHigh,'-b',pd.Bws,pd.VolsMed,'-g',pd.Bws,pd.VolsLow,'-c',pd.Bws,pd.VolsMin,'-k',pd.Bws,pd.VolsEnd,'--m');
    xlabel(sub_1,'Bandwidth');
    ylabel(sub_1,'Volatility');
    set(sub_1,'XLim',[min(pd.Bws) max(pd.Bws)],'XTick',pd.Bws,'XTickLabel',pd.Bws);
    legend(sub_1,'Maximum',pd.PrcHigh,'Median',pd.PrcLow,'Minimum','Realized','Location','best');
    
    sub_2 = subplot(1,3,3);
    boxplot(sub_2,pd.Vols,pd.Bws,'Notch','on','Symbol','k.');
    hold on;
        plot(sub_2,1:pd.BwsLen,pd.VolsEnd,'-m','Marker','*','MarkerEdgeColor','k');
    hold off;
    set(sub_2,'YAxisLocation','right');
    set(findobj(fig,'type','line','Tag','Median'),'Color','g');
    set(findobj(fig,'-regexp','Tag','\w*Whisker'),'LineStyle','-');

    y_lbls = arrayfun(@(x)sprintf('%.0f%%',x),(get(sub_2,'YTick') .* 100),'UniformOutput',false);
    y_tcks = str2double(get(sub_1,'YTickLabel'));
    set([sub_1 sub_2],'YLim',[pd.AxisMin pd.AxisMax],'YTick',y_tcks,'YTickLabel',y_lbls);

    t = figure_title([pd.Title ' | Volatility Cones']);
    t_pos = get(t,'Position');
    set(t,'Position',[t_pos(1) -0.0157 t_pos(3)]);

    pause(0.01);

    jfr = get(fig,'JavaFrame');
    set(jfr,'Maximized',true);

end

function plot_curves(pd)

    vol_win = get_rolling_windows(pd.Vol,pd.Bw);
    vol_dif = NaN(length(pd.Vol) - size(vol_win,1),1);
    vol_max = [vol_dif; cellfun(@(x)nanmax(x),vol_win)];
    vol_hi = [vol_dif; cellfun(@(x)quantile(x,pd.QntHigh),vol_win)];
    vol_med = [vol_dif; cellfun(@(x)nanmedian(x),vol_win)];
    vol_lo = [vol_dif; cellfun(@(x)quantile(x,pd.QntLow),vol_win)];
    vol_min = [vol_dif; cellfun(@(x)nanmin(x),vol_win)];

    fig = figure('Name',[pd.Title ' | Volatility Curves'],'Units','normalized','Position',[100 100 0.85 0.85]);

    sub_1 = subplot(1,5,1:4);
    plot(sub_1,pd.Dates,vol_max,':r',pd.Dates,vol_hi,':b',pd.Dates,vol_med,':g',pd.Dates,vol_lo,':c',pd.Dates,vol_min,':k',pd.Dates,pd.Vol,'-m');
    datetick(sub_1,'x','mm/yy');
    xlabel(sub_1,'Time');
    ylabel(sub_1,'Volatility');
    set(sub_1,'XMinorTick','on','XTickLabelRotation',90);
    legend(sub_1,'Maximum',pd.PrcHigh,'Median',pd.PrcLow,'Minimum','Realized','Location','best');

    sub_2 = subplot(1,5,5);
    boxplot(sub_2,pd.Vol,pd.Bw,'Notch','on','Symbol','k.');
    hold on;
        plot(sub_2,1,pd.VolEnd,'-m','Marker','*','MarkerEdgeColor','k');
    hold off;
    set(sub_2,'XTick',[],'XTickLabel',[],'YAxisLocation','right');
    set(findobj(fig,'type','line','Tag','Median'),'Color','g');
    set(findobj(fig,'-regexp','Tag','\w*Whisker'),'LineStyle','-');

    y_lbls = arrayfun(@(x)sprintf('%.0f%%',x),(get(sub_2,'YTick') .* 100),'UniformOutput',false);
    y_tcks = str2double(get(sub_1,'YTickLabel'));
    set([sub_1 sub_2],'YLim',[pd.AxisMin pd.AxisMax],'YTick',y_tcks,'YTickLabel',y_lbls);
    
    t = figure_title([pd.Title ' | Volatility Curves']);
    t_pos = get(t,'Position');
    set(t,'Position',[t_pos(1) -0.0157 t_pos(3)]);

    pause(0.01);

    jfr = get(fig,'JavaFrame');
    set(jfr,'Maximized',true);

end

function plot_distribution(pd)

    fig = figure('Name',[pd.Title ' | Volatility Distribution'],'Units','normalized','Position',[100 100 0.6 0.6]);

    hist = histogram(pd.Vol,100,'FaceAlpha',0.25,'Normalization','pdf');
    ax = gca;
    hold on;
        edges = get(hist,'BinEdges');
        norm = normpdf(edges,nanmean(pd.Vol),nanstd(pd.Vol));
        plot(ax,edges,norm,'b');
        plot(ax,[pd.VolEnd pd.VolEnd],get(gca,'YLim'),'r');
    hold off;

    x_lbls = arrayfun(@(x)sprintf('%.0f%%',x),(get(ax,'XTick') .* 100),'UniformOutput',false);
    set(ax,'XTickLabel',x_lbls);

    t = figure_title([pd.Title ' | Volatility Distribution']);
    t_pos = get(t,'Position');
    set(t,'Position',[t_pos(1) -0.0157 t_pos(3)]);

    pause(0.01);

    jfr = get(fig,'JavaFrame');
    set(jfr,'Maximized',true);

end
