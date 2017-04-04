% [INPUT]
% tkr      = A string representing the ticker symbol.
% year_beg = An integer representing the start year.
% year_end = An integer representing the end year.
% bw       = A scalar representing the bandwidth (dimension) of each rolling window (optional, default=30).
%
% [NOTE]
% This function produces no outputs, its purpose is to show analysis results.

function compare_estimators(varargin)

    persistent p;

    if (isempty(p))
        p = inputParser();
        p.addRequired('tkr',@(x)validateattributes(x,{'char'},{'nonempty','size',[1,NaN]}));
        p.addRequired('year_beg',@(x)validateattributes(x,{'numeric'},{'scalar','integer','real','finite','>=',1950}));
        p.addRequired('year_end',@(x)validateattributes(x,{'numeric'},{'scalar','integer','real','finite','>=',1950}));
        p.addOptional('bw',30,@(x)validateattributes(x,{'numeric'},{'scalar','integer','real','finite','>=',2}));
    end

    p.parse(varargin{:});
    
    res = p.Results;
    tkr = res.tkr;
    year_beg = res.year_beg;
    year_end = res.year_end;
    bw = res.bw;

    if (year_beg > year_end)
        error('The start year must be less than or equal to the end year.');
    end
    
    compare_estimators_internal(tkr,year_beg,year_end,bw);

end

function compare_estimators_internal(tkr,year_beg,year_end,bw)

    tkr_spl = strsplit(tkr,'/');   
    tkr_cod = tkr_spl{2};

    date_beg = datestr(datenum(year_beg,1,1),'yyyy-mm-dd');
    date_end = datestr(datenum(year_end,12,31),'yyyy-mm-dd');

    data = fetch_data(tkr,date_beg,date_end);
    t = size(data,1);
    
    if (bw >= t)
        error('The number of observations must be greater than the bandwidth.');
    end
    
    if (year_beg == year_end)
        tit = [tkr_cod ' ' num2str(year_beg)];
    else
        tit = [tkr_cod ' ' num2str(year_beg) '-' num2str(year_end)];
    end
    
    ests = {'CC' 'GK' 'GKYZ' 'HT' 'M' 'P' 'RS' 'YZ'};
    ests_len = length(ests);
    res = NaN(t,ests_len);
    
    for i = 1:ests_len
        res(:,i) = estimate_volatility(data,ests{i},bw,false);
    end

    plot_overview(tit,ests,ests_len,res,data.Date);
    
    res(any(isnan(res),2),:) = [];
    
    plot_correlations(tit,ests,ests_len,res);
    plot_efficiency(tit,ests,ests_len,res);
    plot_regressions(tit,ests,ests_len,res);
    
end

function plot_overview(tit,ests,ests_len,res,dates)

    tit = [tit ' | Overview'];
    subs = NaN(ests_len,1);

    y_max = ceil(max(max(res)) * 100) / 100;
    y_min = floor(min(min(res)) * 100) / 100;
    y_tck = y_min:0.05:y_max;
    y_lbl = sprintfc('%1.0f%%', vertcat(y_tck .* 100));

    fig = figure();
    set(fig,'Name',tit,'Units','normalized','Position',[100 100 0.6 0.6]);

    for i = 1:ests_len
        est = ests{i};
        
        sub = subplot(2,4,i);
        plot(sub,dates,res(:,i));
        set(sub,'XTick',[]);
        
        if (i <= 4)
            title(sub,est);
        else
            text(0.5,-0.18,est,'Units','normalized','FontName','Helvetica','FontSize',11,'FontWeight','bold','HorizontalAlignment','center');
        end
        
        subs(i) = sub;
    end

    set(subs,'XLim',[dates(1) dates(end)],'XMinorTick','on','YLim',[y_min y_max],'YTick',y_tck,'YTickLabel',y_lbl);
    
    suptitle(tit);
    movegui(fig,'center');

end

function plot_correlations(tit,ests,ests_len,res)

    tit = [tit ' | Correlation Matrix'];

    [rho,pval] = corr(res);
    m = mean(res);
    s = std(res);
    z = bsxfun(@minus,res,m);
    z = bsxfun(@rdivide,z,s);
    z_lims = [nanmin(z(:)) nanmax(z(:))];

    fig = figure();
    set(fig,'Name',tit,'Units','normalized','Position',[100 100 0.6 0.6]);

    [h,axes,big_ax] = gplotmatrix(res,[],[],[],'o',2,[],'hist',ests,ests);
    set(h(logical(eye(ests_len))),'FaceColor',[0.678 0.922 1]);

    x_lbls = get(axes,'XLabel');
    y_lbls = get(axes,'YLabel');
    set([x_lbls{:}; y_lbls{:}],'FontWeight','bold');

    for i = 1:ests_len
        for j = 1:ests_len
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
    movegui(fig,'center');

end

function plot_efficiency(tit,ests,ests_len,res)

    tit = [tit ' | Efficiency'];

    effs = ones(ests_len,1);
    var_t = var(res(:,1));
    
    for i = 2:ests_len
        effs(i) = var_t / var(res(:,i));
    end

    [~,idx] = max(effs);
    x = 1:ests_len;
    y1 = effs;
    y1(idx) = 0;
    y2 = effs;
    y2(1:end ~= idx) = 0;

    fig = figure();
    set(fig,'Name',tit,'Units','normalized','Position',[100 100 0.6 0.6]);
    
    bar(x,y1,'FaceColor',[0.678 0.922 1]);
    hold on;
        bar(x,y2,'FaceColor',[1 0 0]);
    hold off;

    set(gca,'XTickLabel',ests);

    suptitle(tit);
    movegui(fig,'center');

end

function plot_regressions(tit,ests,ests_len,res)

    tit = [tit ' | Regressions'];
    lims = zeros(ests_len,4);
    subs = NaN(ests_len,1);
    
    y = res(:,1);
    mdls = cell(ests_len,1);
    
    for i = 1:ests_len
        mdl = fitlm(res(:,i),y,'linear','Intercept',true);

        x = mdl.Variables{:,1}{:,:};
        y = mdl.Variables{:,2}{:,:};
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

    fig = figure();
    set(fig,'Name',tit,'Units','normalized','Position',[100 100 0.6 0.6]);

    for i = 1:ests_len
        est = ests{i};
        mdl = mdls{i};

        x = mdl.X;
        y_hat = mdl.YHat;
        z1 = mdl.Z1;
        z2 = mdl.Z2;

        sub = subplot(2,4,i);
        p0 = plot(sub,x,y_hat,x,z1,x,z2);
        x_lim = get(sub,'XLim');
        y_lim = get(sub,'YLim');
        delete(p0);
        hold on;
            area_1 = area(sub,x,z1,min(y_lim));
            set(area_1,'FaceColor','c','LineStyle','none');
        hold off;
        hold on;
            area_2 = area(sub,x,z2,min(y_lim));
            set(area_2,'FaceColor','w','LineStyle','none');
        hold off;
        hold on;
            plo = plot(sub,x,y_hat,'-b');
        hold off;

        strs = {sprintf('a: %.4f',mdl.A) sprintf('b: %.4f',mdl.B) sprintf('Adj. R²: %.4f',mdl.AdjR2)};
        ann = annotation('TextBox',[0 0 1 1],'String',strs,'EdgeColor','none','FitBoxToText','on','FontSize',7);
        set(ann,'Parent',sub,'Position',[0 0.7 0.1 0.1]);
        
        if (i == 1)
            leg = legend(sub,[plo area_1],'OLS Estimation','95% Confidence Bounds','Orientation','Horizontal','Location','South');
        end

        if (i <= 4)
            title(sub,est);
        else
            text(0.5,-0.18,est,'Units','normalized','FontName','Helvetica','FontSize',11,'FontWeight','bold','HorizontalAlignment','center');
        end

        lims(i,:) = [x_lim(1) x_lim(2) y_lim(1) y_lim(2)];
        subs(i) = sub;
    end

    set(subs,'XLim',[min(lims(:,1))-0.1 max(lims(:,2))+0.1],'YLim',[min(lims(:,3))-0.1 max(lims(:,4))+0.1]);
    set(leg,'Units','normalized','Position',[0.4 0.38 0.2 0.2]);
    
    suptitle(tit);
    movegui(fig,'center');

end
