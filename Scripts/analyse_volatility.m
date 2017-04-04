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
% bws      = A vector representing the bandwidths (dimensions) of each rolling window (optional, default=[30 60 90 120]).
% qnts     = A vector containing the upper and lower quantiles (optional, default=[0.25 0.75]).
%
% [NOTE]
% This function produces no outputs, its purpose is to show analysis results.

function analyse_volatility(varargin)

    persistent p;

    if (isempty(p))
        p = inputParser();
        p.addRequired('tkr',@(x)validateattributes(x,{'char'},{'nonempty','size',[1,NaN]}));
        p.addRequired('year_beg',@(x)validateattributes(x,{'numeric'},{'scalar','integer','real','finite','>=',1950}));
        p.addRequired('year_end',@(x)validateattributes(x,{'numeric'},{'scalar','integer','real','finite','>=',1950}));
        p.addRequired('est',@(x)any(validatestring(x,{'CC','CCD','GK','GKYZ','HT','M','P','RS','YZ'})));
        p.addOptional('bws',[30 60 90 120],@(x)validateattributes(x,{'numeric'},{'vector','integer','real','finite','>=',2,'increasing'}));
        p.addOptional('qnts',[0.25 0.75],@(x)validateattributes(x,{'numeric'},{'vector','numel',2,'integer','real','finite','increasing'}));
    end

    p.parse(varargin{:});
    
    res = p.Results;
    tkr = res.tkr;
    year_beg = res.year_beg;
    year_end = res.year_end;
    est = res.est;
    bws = res.bws;
    qnts = res.qnts;

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

    tkr_spl = strsplit(tkr,'/');   
    tkr_cod = tkr_spl{2};

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
    pd.AxisTck = pd.AxisMin:0.01:pd.AxisMax;
    pd.AxisLbl = sprintfc('%.0f%%', vertcat(pd.AxisTck .* 100));

    if (year_beg == year_end)
        pd.Title = [tkr_cod ' ' est ' ' num2str(year_beg)];
    else
        pd.Title = [tkr_cod ' ' est ' ' num2str(year_beg) '-' num2str(year_end)];
    end

    plot_cones(pd);
    plot_curves(pd);
    plot_distribution(pd);

end

function plot_cones(pd)

    tit = [pd.Title ' | Volatility Cones'];

    fig = figure();
    set(fig,'Name',tit,'Units','normalized','Position',[100 100 0.6 0.6]);
    
    sub_1 = subplot(1,3,1:2);
    plot(sub_1,pd.Bws,pd.VolsMax,'-r',pd.Bws,pd.VolsHigh,'-b',pd.Bws,pd.VolsMed,'-g',pd.Bws,pd.VolsLow,'-c',pd.Bws,pd.VolsMin,'-k',pd.Bws,pd.VolsEnd,'--m');
    legend('Maximum',pd.PrcHigh,'Median',pd.PrcLow,'Minimum','Realized','Location','best');
    xlabel(sub_1,'Bandwidth');
    ylabel(sub_1,'Volatility');
    set(sub_1,'XLim',[min(pd.Bws) max(pd.Bws)],'XTick',pd.Bws,'XTickLabel',pd.Bws);
    
    sub_2 = subplot(1,3,3);
    boxplot(sub_2,pd.Vols,pd.Bws,'Notch','on','Symbol','k.');
    hold on;
        plot(1:pd.BwsLen,pd.VolsEnd,'-m','Marker','*','MarkerEdgeColor','k');
    hold off;
    set(sub_2,'YAxisLocation','right');
    set(findobj(fig,'type','line','Tag','Median'),'Color','g');
    set(findobj(fig,'-regexp','Tag','\w*Whisker'),'LineStyle','-');

    set([sub_1 sub_2],'YLim',[pd.AxisMin pd.AxisMax],'YTick',pd.AxisTck,'YTickLabel',pd.AxisLbl);

    suptitle(tit);
    movegui(fig,'center');

end

function plot_curves(pd)

    tit = [pd.Title ' | Volatility Curves'];
    t = pd.Obs;
    
    vol_win = get_rolling_windows(pd.Vol,pd.Bw);
    vol_dif = NaN(length(pd.Vol) - size(vol_win,1),1);
    
    vol_max = [vol_dif; cellfun(@(x)nanmax(x),vol_win)];
    vol_hi = [vol_dif; cellfun(@(x)quantile(x,pd.QntHigh),vol_win)];
    vol_med = [vol_dif; cellfun(@(x)nanmedian(x),vol_win)];
    vol_lo = [vol_dif; cellfun(@(x)quantile(x,pd.QntLow),vol_win)];
    vol_min = [vol_dif; cellfun(@(x)nanmin(x),vol_win)];

    x_lim = (pd.YEnd - pd.YBeg + 1) * 12;
    x_lbl = cell(x_lim,1);
    x_tck = round(linspace(1,t,x_lim));

    for i = 1:x_lim
        x_lbl(i) = cellstr(datestr(pd.Dates(x_tck(i)),'mm/yy'));
    end
    
    dates = zeros(t,1);
    
    for i = 1:t
        dates(i) = i;
    end

    fig = figure();
    set(fig,'Name',tit,'Units','normalized','Position',[100 100 0.6 0.6]);

    sub_1 = subplot(1,5,1:4);
    plot(sub_1,dates,vol_max,':r',dates,vol_hi,':b',dates,vol_med,':g',dates,vol_lo,':c',dates,vol_min,':k',dates,pd.Vol,'-m');
    legend('Maximum',pd.PrcHigh,'Median',pd.PrcLow,'Minimum','Realized','Location','best');
    xlabel(sub_1,'Time');
    ylabel(sub_1,'Volatility');
    set(sub_1,'XLim',[0 t],'XMinorTick','on','XTick',x_tck,'XTickLabel',x_lbl,'XTickLabelRotation',90);

    sub_2 = subplot(1,5,5);
    boxplot(sub_2,pd.Vol,pd.Bw,'Notch','on','Symbol','k.');
    hold on;
        plot(1,pd.VolEnd,'-m','Marker','*','MarkerEdgeColor','k');
    hold off;
	set(sub_2,'XTick',[],'XTickLabel',[],'YAxisLocation','right');
    set(findobj(fig,'type','line','Tag','Median'),'Color','g');
    set(findobj(fig,'-regexp','Tag','\w*Whisker'),'LineStyle','-');

    set([sub_1 sub_2],'YLim',[pd.AxisMin pd.AxisMax],'YTick',pd.AxisTck,'YTickLabel',pd.AxisLbl);
    
    suptitle(tit);
    movegui(fig,'center');

end

function plot_distribution(pd)

    tit = [pd.Title ' | Volatility Distribution'];

    fig = figure();
    set(fig,'Name',tit,'Units','normalized','Position',[100 100 0.6 0.6]);

    hist = histogram(pd.Vol,100,'FaceAlpha',0.25,'Normalization','pdf');
    hold on;
        edges = get(hist,'BinEdges');
        norm = normpdf(edges,nanmean(pd.Vol),nanstd(pd.Vol));
        plot(edges,norm,'b');
        plot([pd.VolEnd pd.VolEnd],get(gca,'YLim'),'r');
    hold off;

    set(gca,'XLim',[pd.AxisMin pd.AxisMax],'XTick',pd.AxisTck,'XTickLabel',pd.AxisLbl);

    suptitle(tit);
    movegui(fig,'center');

end
