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

    if isempty(p)
        p = inputParser();
        p.addRequired('tkr',@(x)validateattributes(x,{'char'},{'nonempty','size',[1,NaN]}));
        p.addRequired('year_beg',@(x)validateattributes(x,{'numeric'},{'scalar','integer','real','finite','>=',1950}));
        p.addRequired('year_end',@(x)validateattributes(x,{'numeric'},{'scalar','integer','real','finite','>=',1950}));
        p.addRequired('est',@(x)any(validatestring(x,{'CC','CCD','GK','GKYZ','HT','P','RS','YZ'})));
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

function analyse_volatility_internal(tkr,y_beg,y_end,est,bws,bws_len,qnts)

    date_beg = datestr(datenum(y_beg,1,1),'yyyy-mm-dd');
    date_end = datestr(datenum(y_end,12,31),'yyyy-mm-dd');
    data = fetch_data(tkr,date_beg,date_end);

    vol_hi = zeros(bws_len,1);
    vol_lo = zeros(bws_len,1);
    vol_max = zeros(bws_len,1);
    vol_med = zeros(bws_len,1);
    vol_min = zeros(bws_len,1);
    vol_rea = zeros(bws_len,1);
    vols = [];
    
    for i = 1:bws_len
        vol = estimate_volatility(data,est,bws(i),false);
        
        vol_hi(i) = quantile(vol,qnts(2));
        vol_lo(i) = quantile(vol,qnts(1));
        vol_max(i) = nanmax(vol);
        vol_med(i) = nanmedian(vol);
        vol_min(i) = nanmin(vol);
        vol_rea(i) = vol(end);
        
        vols = [vols vol];
    end

    plot_cones(bws,bws_len,qnts,vol_hi,vol_lo,vol_max,vol_med,vol_min,vol_rea,vols);

end

function plot_cones(bws,bws_len,qnts,vol_hi,vol_lo,vol_max,vol_med,vol_min,vol_rea,vols)

    fig = figure(1);
    set(fig,'Units','normalized','Position',[10 10 0.6 0.6]);
    
    sp_1 = subplot(1,3,1:2);
    plot(sp_1,bws,vol_max,'-r',bws,vol_hi,'-b',bws,vol_med,'-g',bws,vol_lo,'-c',bws,vol_min,'-k',bws,vol_rea,'--m'); 
    xlabel(sp_1,'Bandwidth');
    ylabel(sp_1,'Volatility');
    legend('Maximum',sprintf('%0.0f Percentile',qnts(2)*100),'Median',sprintf('%0.0f Percentile',qnts(1)*100),'Minimum','Realized','Location','best');

    sp_2 = subplot(1,3,3);
    boxplot(sp_2,vols,bws,'Notch','on');
    hold on;
        plot(1:bws_len,vol_rea,'-m');
    hold off;
    
    x_max = max(bws);
    x_min = min(bws);
    y_max = ceil(max(vol_max) * 100) / 100;
    y_min = floor(min(vol_min) * 100) / 100;

    y_tck = y_min:0.01:y_max;
    y_lab = sprintfc('%0.0f%%', vertcat((y_tck .* 100)));

    set(sp_1,'XLim',[x_min x_max],'XTick',bws,'XTickLabel',bws);
	set(sp_2,'YAxisLocation','right');
    set([sp_1 sp_2],'YLim',[y_min y_max],'YTick',y_tck,'YTickLabel',y_lab);

    suptitle('Volatility Cones');
    
    movegui(fig,'center');

end

function plot_curves(bws,bws_len,qnts,vol_hi,vol_lo,vol_max,vol_med,vol_min,vol_rea,vols)


end