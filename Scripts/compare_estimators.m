% [INPUT]
% tkr      = A string representing the ticker symbol.
% year_beg = An integer representing the start year.
% year_end = An integer representing the end year.
% bw       = An integer representing the bandwidth (dimension) of each rolling window (optional, default=30).

function compare_estimators(varargin)

    persistent ip;

    if (isempty(ip))
        ip = inputParser();
        ip.addRequired('tkr',@(x)validateattributes(x,{'char'},{'nonempty','size',[1,NaN]}));
        ip.addRequired('year_beg',@(x)validateattributes(x,{'numeric'},{'scalar','integer','real','finite','>=',1970}));
        ip.addRequired('year_end',@(x)validateattributes(x,{'numeric'},{'scalar','integer','real','finite','>=',1970}));
        ip.addOptional('bw',30,@(x)validateattributes(x,{'numeric'},{'scalar','integer','real','finite','>=',2}));
    end

    ip.parse(varargin{:});
    
    res = ip.Results;
    year_beg = res.year_beg;
    year_end = res.year_end;

    if (year_beg > year_end)
        error('The start year must be less than or equal to the end year.');
    end
    
    compare_estimators_internal(res.tkr,year_beg,year_end,res.bw);

end

function compare_estimators_internal(tkr,year_beg,year_end,bw)

    date_beg = datestr(datenum(year_beg,1,1),'yyyy-mm-dd');
    date_end = datestr(datenum(year_end,12,31),'yyyy-mm-dd');

    data = fetch_data(tkr,date_beg,date_end);
    t = size(data,1);
    
    if (bw >= t)
        error('The number of observations must be greater than the bandwidth.');
    end

    pd = struct();
    pd.Dates = data.Date;
    pd.Ests = {'CC' 'GK' 'GKYZ' 'HT' 'M' 'P' 'RS' 'YZ'};
    pd.EstsLen = 8;
    pd.Res = NaN(t,8);
    pd.ResCln = NaN(t,8);
    pd.SubsCols = 4;
    pd.SubsRows = 2;
    
    for i = 1:8
        pd.Res(:,i) = estimate_volatility(data,pd.Ests{i},bw,false);
        pd.ResCln(:,i) = estimate_volatility(data,pd.Ests{i},bw,false);
    end
    
    pd.ResCln(any(isnan(pd.ResCln),2),:) = [];

    if (year_beg == year_end)
        pd.Tit = [tkr ' ' num2str(year_beg)];
    else
        pd.Tit = [tkr ' ' num2str(year_beg) '-' num2str(year_end)];
    end
    
    plot_overview(pd);
    plot_correlations(pd);
    plot_efficiency(pd);
    plot_regressions(pd);
    
end

function plot_overview(pd)

    subs = NaN(pd.EstsLen,1);
    
    y_max = ceil(max(max(pd.Res)) * 100) / 100;
    y_min = floor(min(min(pd.Res)) * 100) / 100;
    y_tck = y_min:0.05:y_max;
    y_lbl = sprintfc('%1.0f%%', vertcat(y_tck .* 100));

    fig = figure('Name',[pd.Tit ' | Overview'],'Units','normalized','Position',[100 100 0.85 0.85]);

    for i = 1:pd.EstsLen
        est = pd.Ests{i};
        
        sub = subplot(pd.SubsRows,pd.SubsCols,i);
        plot(sub,pd.Dates,pd.Res(:,i));
        set(sub,'XTick',[]);
        title(sub,est);
        
        subs(i) = sub;
    end

    set(subs,'XLim',[pd.Dates(1) pd.Dates(end)],'XMinorTick','on','YLim',[y_min y_max],'YTick',y_tck,'YTickLabel',y_lbl);

    t = figure_title([pd.Tit ' | Overview']);
    t_pos = get(t,'Position');
    set(t,'Position',[t_pos(1) -0.0157 t_pos(3)]);
    
    pause(0.01);

    jfr = get(fig,'JavaFrame');
    set(jfr,'Maximized',true);

end

function plot_correlations(pd)

    tit = [pd.Tit ' | Correlation Matrix'];

    [rho,pval] = corr(pd.ResCln);
    m = mean(pd.ResCln);
    s = std(pd.ResCln);
    z = bsxfun(@minus,pd.ResCln,m);
    z = bsxfun(@rdivide,z,s);
    z_lims = [nanmin(z(:)) nanmax(z(:))];

    fig = figure('Name',tit,'Units','normalized');
    
    pause(0.01);
    jfr = get(fig,'JavaFrame');
    set(jfr,'Maximized',true);

    pause(0.01);
    set(0,'CurrentFigure',fig);
    [h,axes,big_ax] = gplotmatrix(pd.ResCln,[],[],[],'o',2,[],'hist',pd.Ests,pd.Ests);
    set(h(logical(eye(pd.EstsLen))),'FaceColor',[0.678 0.922 1]);
    
    drawnow();

    x_lbls = get(axes,'XLabel');
    y_lbls = get(axes,'YLabel');
    set([x_lbls{:}; y_lbls{:}],'FontWeight','bold');

    ij_lim = 1:pd.EstsLen;
    
    for i = ij_lim
        for j = ij_lim
            ax_ij = axes(i,j);
            
            z_lims_cur = 1.1 .* z_lims;
            x_lim = m(j) + (z_lims_cur * s(j));
            y_lim = m(i) + (z_lims_cur * s(i));
            
            set(get(big_ax,'Parent'),'CurrentAxes',ax_ij);
            set(ax_ij,'XLim',x_lim,'XTick',[],'YLim',y_lim,'YTick',[]);
            axis normal;
            
            if (i ~= j)
                hls = lsline();
                set(hls,'Color','r');

                if (pval(i,j) < 0.05)
                    color = 'r';
                else
                    color = 'k';
                end

                annotation('TextBox',get(ax_ij,'Position'),'String',num2str(rho(i,j),'%0.2f'),'Color',color,'EdgeColor','none','FontWeight','Bold');
            end
        end
    end

    annotation('TextBox',[0 0 1 1],'String',tit,'EdgeColor','none','FontName','Helvetica','FontSize',14,'HorizontalAlignment','center');

end

function plot_efficiency(pd)

    effs = ones(pd.EstsLen,1);
    var_t = var(pd.ResCln(:,1));
    
    for i = 2:pd.EstsLen
        effs(i) = var_t / var(pd.ResCln(:,i));
    end

    [~,idx] = max(effs);
    x = 1:pd.EstsLen;
    y1 = effs;
    y1(idx) = 0;
    y2 = effs;
    y2(1:end ~= idx) = 0;

    fig = figure('Name',[pd.Tit ' | Efficiency'],'Units','normalized','Position',[100 100 0.85 0.85]);
    
    bar(x,y1,'FaceColor',[0.678 0.922 1]);
    hold on;
        bar(x,y2,'FaceColor',[1 0 0]);
    hold off;

    set(gca(),'XTickLabel',pd.Ests);

    t = figure_title([pd.Tit ' | Efficiency']);
    t_pos = get(t,'Position');
    set(t,'Position',[t_pos(1) -0.0157 t_pos(3)]);
    
    pause(0.01);

    jfr = get(fig,'JavaFrame');
    set(jfr,'Maximized',true);

end

function plot_regressions(pd)

    i_lim = 1:pd.EstsLen;
    lims = zeros(pd.EstsLen,4);
    subs = NaN(pd.EstsLen,1);

    y = pd.ResCln(:,1);
    mdls = cell(pd.EstsLen,1);
    
    for i = i_lim
        mdl = fitlm(pd.ResCln(:,i),y,'linear','Intercept',true);

        x = mdl.Variables{:,1};
        y = mdl.Variables{:,2};
        [y_hat,y_ci] = predict(mdl,mdl.Variables);
        z1 = y_ci(:,2);
        z2 = y_ci(:,1);
        
        mdl_res = struct();
        mdl_res.A = mdl.Coefficients.Estimate(1);
        mdl_res.AdjR2 = mdl.Rsquared.Adjusted;
        mdl_res.B = mdl.Coefficients.Estimate(2);
        mdl_res.X = x;
        mdl_res.YHat = y_hat;
        mdl_res.Z1 = z1;
        mdl_res.Z2 = z2;
        
        mdls{i} = mdl_res;
    end

    fig = figure('Name',[pd.Tit ' | Regressions'],'Units','normalized','Position',[100 100 0.85 0.85]);

    for i = i_lim
        est = pd.Ests{i};
        mdl = mdls{i};

        sub = subplot(pd.SubsRows,pd.SubsCols,i);
        plo_0 = plot(sub,mdl.X,mdl.YHat,mdl.X,mdl.Z1,mdl.X,mdl.Z2);
        x_lim = get(sub,'XLim');
        y_lim = get(sub,'YLim');
        delete(plo_0);
        hold on;
            area_1 = area(sub,mdl.X,mdl.Z1,min(y_lim));
            set(area_1,'FaceColor','c','LineStyle','none');
            area_2 = area(sub,mdl.X,mdl.Z2,min(y_lim));
            set(area_2,'FaceColor','w','LineStyle','none');
            plo_1 = plot(sub,mdl.X,mdl.YHat,'-b');
        hold off;

        strs = {sprintf('a: %.4f',mdl.A) sprintf('b: %.4f',mdl.B) sprintf('Adj. R2: %.4f',mdl.AdjR2)};
        ann = annotation('TextBox',[0 0 1 1],'String',strs,'EdgeColor','none','FitBoxToText','on','FontSize',8);
        set(ann,'Parent',sub,'Position',[0.0 0.6 0.1 0.1]);
        
        if (i == 1)
            leg = legend(sub,[plo_1 area_1],'OLS Estimation','95% Confidence Bounds','Location','south','Orientation','horizontal');
        end

        title(sub,est);

        lims(i,:) = [x_lim(1) x_lim(2) y_lim(1) y_lim(2)];
        subs(i) = sub;
    end

    set(subs,'XLim',[min(lims(:,1))-0.1 max(lims(:,2))+0.1],'YLim',[min(lims(:,3))-0.1 max(lims(:,4))+0.1]);
    set(leg,'Units','normalized','Position',[0.400 0.490 0.200 0.050]);
    
    t = figure_title([pd.Tit ' | Regressions']);
    t_pos = get(t,'Position');
    set(t,'Position',[t_pos(1) -0.0157 t_pos(3)]);

    pause(0.01);

    jfr = get(fig,'JavaFrame');
    set(jfr,'Maximized',true);

end
