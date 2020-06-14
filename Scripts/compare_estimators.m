% [INPUT]
% ticker = A string representing the reference ticker symbol.
% data = A t-by-6 table containing the following time series:
%   - Date (numeric observation dates)
%   - Open (opening prices)
%   - High (highest prices)
%   - Low (lowest prices)
%   - Close (closing prices)
%   - Return (log returns)
% bw = An integer [2,252] representing the dimension of each rolling window (optional, default=30).

function compare_estimators(varargin)

    persistent ip;

    if (isempty(ip))
        ip = inputParser();
        ip.addRequired('ticker',@(x)validateattributes(x,{'char'},{'nonempty' 'size' [1 NaN]}));
        ip.addRequired('data',@(x)validateattributes(x,{'table'},{'2d' 'nonempty' 'ncols' 6}));
        ip.addOptional('bw',30,@(x)validateattributes(x,{'double'},{'real' 'finite','integer' '>=' 2 '<=' 252 'scalar'}));
    end

    ip.parse(varargin{:});
    
    ipr = ip.Results;
    ticker = ipr.ticker;
    data = validate_data(ipr.data);
    bw = validate_bandwidth(ipr.bw,data);
    
    compare_estimators_internal(ticker,data,bw);

end

function compare_estimators_internal(ticker,data,bw)

    t = height(data);
    k = 8;
    
    years = year(data.Date);
    year_start = min(years);
    year_end = max(years);

    pd = struct();
    pd.K = k;
    pd.Dates = data.Date;
    pd.Estimators = {'CC' 'GK' 'GKYZ' 'HT' 'M' 'P' 'RS' 'YZ'};
    pd.Results = NaN(t,k);
    pd.ResultsClean = NaN(t,k);
    
    for i = 1:k
        e = pd.Estimators{i};
        pd.Results(:,i) = estimate_volatility(data,e,bw,false);
        pd.ResultsClean(:,i) = estimate_volatility(data,e,bw,false);
    end
    
    pd.ResultsClean(any(isnan(pd.ResultsClean),2),:) = [];

    if (year_start == year_end)
        pd.PlotsTitle = ['CMP(' ticker ',' num2str(year_start) ')'];
    else
        pd.PlotsTitle = ['CMP(' ticker ',' num2str(year_start) '-' num2str(year_end) ')'];
    end
    
    plot_overview(pd);
    plot_correlations(pd);
    plot_efficiency(pd);
    plot_regressions(pd);
    
end

function [ax,big_ax] = gplotmatrix_stable(f,x,labels)

    n = size(x,2);

    clf(f);
    big_ax = newplot();
    hold_state = ishold();

    set(big_ax,'Color','none','Parent',f,'Visible','off');

    position = get(big_ax,'Position');
    width = position(3) / n;
    height = position(4) / n;
    position(1:2) = position(1:2) + (0.02 .* [width height]);

    [m,~,k] = size(x);

    x_min = min(x,[],1);
    x_max = max(x,[],1);
    x_limits = repmat(cat(3,x_min,x_max),[n 1 1]);
    y_limits = repmat(cat(3,x_min.',x_max.'),[1 n 1]);

    for i = n:-1:1
        for j = 1:1:n
            ax_position = [(position(1) + (j - 1) * width) (position(2) + (n - i) * height) (width * 0.98) (height * 0.98)];
            ax1(i,j) = axes('Box','on','Parent',f,'Position',ax_position,'Visible','on');

            if (i == j)
                ax2(j) = axes('Parent',f,'Position',ax_position);
                histogram(reshape(x(:,i,:),[m k]),'BinMethod','scott','DisplayStyle','bar','FaceColor',[0.678 0.922 1],'Norm','pdf');
                set(ax2(j),'YAxisLocation','right','XGrid','off','XTick',[],'XTickLabel','');
                set(ax2(j),'YGrid','off','YLim',get(ax2(j),'YLim') .* [1 1.05],'YTick',[],'YTickLabel','');
                set(ax2(j),'Visible','off');
                axis(ax2(j),'tight');
                x_limits(i,j,:) = get(ax2(j),'XLim');      
            else
                iscatter(reshape(x(:,j,:),[m k]),reshape(x(:,i,:),[m k]),ones(size(x,1),1),[0 0 1],'o',2);
                axis(ax1(i,j),'tight');
                x_limits(i,j,:) = get(ax1(i,j),'XLim');
                y_limits(i,j,:) = get(ax1(i,j),'YLim');
            end

            set(ax1(i,j),'XGrid','off','XLimMode','auto','YGrid','off','YLimMode','auto');
        end
    end

    x_limits_min = min(x_limits(:,:,1),[],1);
    x_limits_max = max(x_limits(:,:,2),[],1);

    y_limits_min = min(y_limits(:,:,1),[],2);
    y_limits_max = max(y_limits(:,:,2),[],2);

    for i = 1:n
        set(ax1(i,1),'YLim',[y_limits_min(i,1) y_limits_max(i,1)]);
        dy = diff(get(ax1(i,1),'YLim')) * 0.05;
        set(ax1(i,:),'YLim',[(y_limits_min(i,1)-dy) y_limits_max(i,1)+dy]);

        set(ax1(1,i),'XLim',[x_limits_min(1,i) x_limits_max(1,i)])
        dx = diff(get(ax1(1,i),'XLim')) * 0.05;
        set(ax1(:,i),'XLim',[(x_limits_min(1,i) - dx) (x_limits_max(1,i) + dx)])
        set(ax2(i),'XLim',[(x_limits_min(1,i) - dx) (x_limits_max(1,i) + dx)])
    end

    for i = 1:n
        set(get(ax1(i,1),'YLabel'),'String',labels{i});
        set(get(ax1(n,i),'XLabel'),'String',labels{i});
    end

    set(ax1(1:n-1,:),'XTickLabel','');
    set(ax1(:,2:n),'YTickLabel','');

    set(f,'CurrentAx',big_ax);
    set([get(big_ax,'Title'); get(big_ax,'XLabel'); get(big_ax,'YLabel')],'String','','Visible','on');

    if (~hold_state)
        set(f,'NextPlot','replace')
    end

    for i = 1:n
        hz = zoom();

        linkprop(ax1(i,:),{'YLim' 'YScale'});
        linkprop(ax1(:,i),{'XLim' 'XScale'});

        setAxesZoomMotion(hz,ax2(i),'horizontal');        
    end

    set(pan(),'ActionPreCallback',@size_changed_callback);

    ax = [ax1; ax2(:).'];

    function size_changed_callback(~,~)

        if (~all(isgraphics(ax1(:))))
            return;
        end

        set(ax1(1:n,1),'YTickLabelMode','auto');
        set(ax1(n,1:n),'XTickLabelMode','auto');

    end

end

function plot_overview(pd)

    y_min = floor(min(min(pd.Results)) * 100) / 100;
    y_max = ceil(max(max(pd.Results)) * 100) / 100;
    
    y_limits = [y_min y_max];
    y_ticks = y_min:0.05:y_max;
    y_tick_labels = sprintfc('%1.0f%%', vertcat(y_ticks .* 100));

    f = figure('Name',[pd.PlotsTitle ' > Overview'],'Units','normalized','Position',[100 100 0.85 0.85]);
    
    subs = gobjects(pd.K,1);

    for i = 1:pd.K
        sub = subplot(2,4,i);
        plot(sub,pd.Dates,pd.Results(:,i),'Color',[0.000 0.447 0.741]);
        title(sub,pd.Estimators{i});
        
        subs(i) = sub;
    end

    set(subs,'XLim',[pd.Dates(1) pd.Dates(end)],'XMinorTick','on','XTick',[]);
    set(subs,'YGrid','on','YLim',y_limits,'YTick',y_ticks,'YTickLabel',y_tick_labels);

    figure_title([pd.PlotsTitle ' > Overview']);
    
    pause(0.01);
    frame = get(f,'JavaFrame');
    set(frame,'Maximized',true);

end

function plot_correlations(pd)

    k = pd.K;
    t = size(pd.ResultsClean,1);
    
    m = mean(pd.ResultsClean,1);
    s = std(pd.ResultsClean,1);
    z = (pd.ResultsClean - repmat(m,t,1)) ./ repmat(s,t,1);
    z_limits = [min(z(:),[],'omitnan') nanmax(z(:),[],'omitnan')];

    [rho,pval] = corr(pd.ResultsClean);
    rho(isnan(rho)) = 0;

    title = [pd.PlotsTitle ' > Correlation Matrix'];

    f = figure('Name',title,'Units','normalized');

    [ax,big_ax] = gplotmatrix_stable(f,pd.ResultsClean,pd.Estimators);

    x_labels = get(ax,'XLabel');
    y_labels = get(ax,'YLabel');
    set([x_labels{:}; y_labels{:}],'FontWeight','bold');

    for i = 1:k
        for j = 1:k
            ax_ij = ax(i,j);
            
            z_limits_current = 1.1 .* z_limits;
            x_limits = m(j) + (z_limits_current * s(j));
            y_limits = m(i) + (z_limits_current * s(i));
            
            set(get(big_ax,'Parent'),'CurrentAxes',ax_ij);
            set(ax_ij,'XLim',x_limits,'XTick',[],'YLim',y_limits,'YTick',[]);
            axis(ax_ij,'normal');
            
            if (i ~= j)
                line = lsline();
                set(line,'Color','r');

                if (pval(i,j) < 0.05)
                    color = 'r';
                else
                    color = 'k';
                end

                annotation('TextBox',get(ax_ij,'Position'),'String',num2str(rho(i,j),'%0.2f'),'Color',color,'EdgeColor','none','FontWeight','Bold');
            end
        end
    end

    annotation('TextBox',[0 0 1 1],'String',title,'EdgeColor','none','FontName','Helvetica','FontSize',14,'HorizontalAlignment','center');

    pause(0.01);
    frame = get(f,'JavaFrame');
    set(frame,'Maximized',true);
    
end

function plot_efficiency(pd)

    k = pd.K;

    e = ones(k,1);
    e(2:k) = var(pd.ResultsClean(:,1)) ./ var(pd.ResultsClean(:,2:k));

    [~,indices] = max(e);
    x = 1:k;
    y1 = e;
    y1(indices) = 0;
    y2 = e;
    y2(1:end ~= indices) = 0;

    f = figure('Name',[pd.PlotsTitle ' > Efficiency'],'Units','normalized','Position',[100 100 0.85 0.85]);
    
    bar(x,y1,'FaceColor',[0.749 0.862 0.933]);
    hold on;
        bar(x,y2,'FaceColor',[1 0.4 0.4]);
    hold off;

    set(gca(),'XTickLabel',pd.Estimators);
    set(gca(),'YGrid','on');

    figure_title([pd.PlotsTitle ' > Efficiency']);
    
    pause(0.01);
    frame = get(f,'JavaFrame');
    set(frame,'Maximized',true);

end

function plot_regressions(pd)

    k = pd.K;

    y = pd.ResultsClean(:,1);
    mdls = cell(pd.K,1);
    
    for i = 1:k
        mdl = fitlm(pd.ResultsClean(:,i),y,'linear','Intercept',true);

        a = mdl.Coefficients.Estimate(1);
        b = mdl.Coefficients.Estimate(2);
        x = mdl.Variables{:,1};
        y = mdl.Variables{:,2};
        [y_hat,y_ci] = predict(mdl,mdl.Variables);
        ar2 = mdl.Rsquared.Adjusted;

        mdl = struct();
        mdl.A = a;
        mdl.B = b;
        mdl.X = x;
        mdl.YHat = y_hat;
        mdl.YCL = y_ci(:,2);
        mdl.YCU = y_ci(:,1);
        mdl.AdjustedR2 = ar2;
        
        mdls{i} = mdl;
    end
    
    plots_grid = repmat(1:4,2,1) + repmat(4 .* (0:1),4,1).';
    plots_limits = zeros(k,4);

    f = figure('Name',[pd.PlotsTitle ' > Regressions'],'Units','normalized','Position',[100 100 0.85 0.85]);

    subs = gobjects(k,1);
    
    for i = 1:k
        mdl = mdls{i};

        sub = subplot(2,4,i);
        set(sub,'Units','normalized');
        sub_position = get(sub,'Position');

        p0 = plot(sub,mdl.X,mdl.YHat,mdl.X,mdl.YCL,mdl.X,mdl.YCU);
        x_lim = get(sub,'XLim');
        y_lim = get(sub,'YLim');
        delete(p0);

        hold on;
            a1 = area(sub,mdl.X,[mdl.YCL (mdl.YCU - mdl.YCL)],'EdgeColor','none','FaceColor',[0.85 0.85 0.85]);
            set(a1(1),'FaceColor','none');
            p1 = plot(sub,mdl.X,mdl.YHat,'Color',[0.000 0.447 0.741]);
        hold off;
        
        if (find(sum(plots_grid == i,2) == 1,1,'first') == 1)
            a_position = [sub_position(1) 0.5734 sub_position(3) sub_position(4)];
        else
            a_position = [sub_position(1) 0.1067 sub_position(3) sub_position(4)];
        end

        a_text = {sprintf('a: %.4f',mdl.A) sprintf('b: %.4f',mdl.B) sprintf('Adj. R2: %.4f',mdl.AdjustedR2)};
        annotation('TextBox',[0 0 1 1],'String',a_text,'EdgeColor','none','FitBoxToText','on','FontSize',8,'Position',a_position);
        
        if (i == 1)
            l = legend(sub,[p1 a1(2)],'OLS Estimation','95% Confidence Bounds','Location','south','Orientation','horizontal');
            set(l,'Units','normalized','Position',[0.400 0.490 0.200 0.050]);
        end

        title(sub,pd.Estimators{i});

        plots_limits(i,:) = [x_lim(1) x_lim(2) y_lim(1) y_lim(2)];
        subs(i) = sub;
    end

    set(subs,'XLim',[min(plots_limits(:,1))-0.1 max(plots_limits(:,2))+0.1]);
    set(subs,'YLim',[min(plots_limits(:,3))-0.1 max(plots_limits(:,4))+0.1]);
    set(subs,'XGrid','on','YGrid','on');

    figure_title([pd.PlotsTitle ' > Regressions']);

    pause(0.01);
    frame = get(f,'JavaFrame');
    set(frame,'Maximized',true);

end

function bw = validate_bandwidth(bw,data)

    if (bw >= height(data))
        error(['The value of ''bw'' is invalid.' newline() 'Expected input to be less than tne number of observations.']);
    end

end

function data = validate_data(data)

    vn = {'Date' 'Open' 'High' 'Low' 'Close' 'Return'};

    if (~all(ismember(vn,data.Properties.VariableNames)))
        error(['The value of ''data'' is invalid.' newline() 'Expected input to contain the following time series: ' vn{1} sprintf(', %s',vn{2:end}) '.']);
    end

end
