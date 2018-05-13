% [INPUT]
% tkrs     = A variable representing the ticker symbol(s) with two possible value types:
%             - An string for a single ticker symbol.
%             - A vector of strings for multiple ticker symbols.
% date_beg = A string representing the start date in the format "yyyy-mm-dd".
% date_end = A string representing the end date in the format "yyyy-mm-dd".
%
% [OUTPUT]
% data     = If a single ticker symbol is provided, the function returns a numeric t-by-6 table with the following time series:
%             - Date (the dates of the observations)
%             - Open (the opening prices)
%             - High (the highest prices)
%             - Low (the lowest prices)
%             - Close (the closing prices)
%             - Return (the log returns)
%            Otherwise, a vector of numeric t-by-6 tables (as described above) is returned.

function data = fetch_data(varargin)

    persistent ip;

    if (isempty(ip))
        ip = inputParser();
        ip.addRequired('tkrs',@(x)validateattributes(x,{'cell','char'},{'vector','nonempty'}));
        ip.addRequired('date_beg',@(x)validateattributes(x,{'char'},{'nonempty','size',[1,NaN]}));
        ip.addRequired('date_end',@(x)validateattributes(x,{'char'},{'nonempty','size',[1,NaN]}));        
    end

    ip.parse(varargin{:});
    
    ip_res = ip.Results;
    date_beg = ip_res.date_beg;
    date_end = ip_res.date_end;
    
    try
        num_beg = datenum(date_beg,'yyyy-mm-dd');
        check = datestr(num_beg,'yyyy-mm-dd');

        if (~isequal(check,date_beg))
            error('Invalid end date specified.');
        end
    catch e
        rethrow(e);
    end

    try
        num_end = datenum(date_end,'yyyy-mm-dd');
        check = datestr(num_end,'yyyy-mm-dd');

        if (~isequal(check,date_end))
            error('Invalid end date specified.');
        end
    catch e
        rethrow(e);
    end

    if ((num_end - num_beg) < 30)
        error('The start date must be anterior to the end date by at least 30 days.');
    end

    data = cache_result(ip_res.tkrs,date_beg,date_end);

end

function data = fetch_data_internal(tkrs,date_beg,date_end)

    if (ischar(tkrs))
        tkrs = {tkrs};
    end
     
    tkrs_len = length(tkrs);
    data = cell(tkrs_len,1);
    
    date_orig = datenum('01-Jan-1970 00:00:00','dd-mmm-yyyy HH:MM:SS');
    date_beg = (datenum(date_beg,'yyyy-mm-dd') - date_orig) * 86400;
    date_end = (datenum(date_end,'yyyy-mm-dd') - date_orig) * 86400;

    opts = weboptions('RequestMethod','post');
    url = ['https://query1.finance.yahoo.com/v7/finance/download/%TICKER%?&period1=' num2str(date_beg) '&period2=' num2str(date_end) '&interval=1d&events=history'];
    
    bar = waitbar(0,'Fetching data from Yahoo! Finance...');
    
    try
        for i = 1:tkrs_len
            tkr = tkrs{i};
            tkr_data = webread(strrep(url,'%TICKER%',tkr),'historical.volatility@yahoo.com','HV',opts);

            if (width(tkr_data) < 6)
                error(['Missing time series for ticker ' tkr '.']);
            end

            ratio = tkr_data.AdjClose ./ tkr_data.Close;
            tkr_data.Open = tkr_data.Open .* ratio;
            tkr_data.High = tkr_data.High .* ratio;              
            tkr_data.Low = tkr_data.Low .* ratio;
            tkr_data.Close = tkr_data.Close .* ratio;

            tkr_data.Return = [NaN; diff(log(tkr_data.Close))];
            tkr_data.AdjClose = [];
            tkr_data.Volume = [];

            data{i} = tkr_data;

            waitbar((i / tkrs_len),bar);
        end
        
        close(bar);
        
        if (tkrs_len == 1)
            data = data{1};
        end
    catch e
        close(bar);
        rethrow(e);
    end

end

function varargout = cache_result(varargin)

    persistent cache;

    args = varargin;
    fun = @fetch_data_internal;
    now = cputime;
    
    key = [args {@fetch_data_internal,nargout}];
    key_inf = whos('key');
    key_sid = sprintf('s%.0f',key_inf.bytes);

    try
        pool = cache.(key_sid);

        for i = 1:length(pool.Inps)
            if (isequaln(key,pool.Inps{i}))
                varargout = pool.Outs{i};

                pool.Frqs(i) = pool.Frqs(i) + 1;
                pool.Lcnt = pool.Lcnt + 1;
                pool.Luse(i) = now;

                if (pool.Lcnt > cache.Cfg.ResFre)
                    [pool.Frqs,inds] = sort(pool.Frqs,'descend');

                    pool.Inps = pool.Inps(inds);
                    pool.Lcnt = 0;
                    pool.Luse = pool.Luse(inds);
                    pool.Outs = pool.Outs(inds);
                end

                cache.(key_sid) = pool;

                return;
            end
        end
    catch
        pool = struct('Frqs',{[]},'Inps',{{}},'Lcnt',{0},'Luse',{[]},'Outs',{{}});
    end

    if (~exist('varargout','var'))
        if (~isfield(cache,'Cfg'))
            cache.Cfg = struct();
            cache.Cfg.GrpSiz = 100;
            cache.Cfg.MaxSizKey = 100000000;
            cache.Cfg.MaxSizRes = 100000000;
            cache.Cfg.ResFre = 10;
        end

        [varargout{1:nargout}] = fun(varargin{:});
        var_inf = whos('varargout');

        if ((var_inf.bytes <= cache.Cfg.MaxSizRes) && (key_inf.bytes <= cache.Cfg.MaxSizKey))
            pool.Frqs(end+1) = 1;
            pool.Inps{end+1} = key;
            pool.Lcnt = 0;
            pool.Luse(end+1) = now;
            pool.Outs{end+1} = varargout;

            while (length(pool.Inps) > cache.Cfg.GrpSiz)
                [~,idx] = min(pool.Luse);

                pool.Luse(idx) = [];
                pool.Frqs(idx) = [];
                pool.Inps(idx) = [];
                pool.Outs(idx) = [];
            end

            cache.(key_sid) = pool;
        end
    end

end
