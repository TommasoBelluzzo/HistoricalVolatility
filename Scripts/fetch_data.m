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
%
% [NOTES]
% The 'key' string passed to the Quandl.auth() call must be replaced with a valid authentication key.

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
    tkr_dbs = cell(tkrs_len,1);
    
    bar = waitbar(0,'Fetching data from Quandl...');
    
    try
        Quandl.auth('key');

        for i = 1:tkrs_len
            tkr = tkrs{i};
            tkr_spl = strsplit(tkr,'/');
            tkr_db = tkr_spl{1};

            switch tkr_db
                case 'GOOG'
                    cols = {'Date' 'Open' 'High' 'Low' 'Close'};
                    cols_len = length(cols);
                case 'WIKI'
                    cols = {'Date' 'Adj. Open' 'Adj. High' 'Adj. Low' 'Adj. Close'};
                    cols_len = length(cols);
                case 'YAHOO'
                    cols = {'Date' 'Open' 'High' 'Low' 'Close' 'Adjusted Close'};
                    cols_len = length(cols);
                otherwise
                    error(['The database ' tkr_db ' is not supported.']);
            end
            
            [ts,head] = Quandl.get(tkr,'type','data','start_date',date_beg,'end_date',date_end);
            
            if (length(head) < cols_len)
                error(['Missing time series for ticker ' tkr '.']);
            end

            ts = flipud(ts(:,ismember(head,cols)));
            ts_len = size(ts,1);

            if (ts_len < cols_len)
                error(['Missing time series for ticker ' tkr '.']);
            end
            
            if (strcmp(tkr_db,'YAHOO'))
                ratio = ts(:,6) ./ ts(:,5);
                ts(:,2:5) = ts(:,2:5) .* repmat(ratio,1,4);
            end
            
            ts(:,6) = [NaN; diff(log(ts(:,5)))];
            data{i} = array2table(ts,'VariableNames',{'Date' 'Open' 'High' 'Low' 'Close' 'Return'});

            tkr_dbs{i} = tkr_db;
            
            waitbar((i / tkrs_len),bar);
        end

        if (length(unique(tkr_dbs)) ~= 1)
            warning('For a matter of coherence, it is recommended to retrieve all the data from a single Quandl database.');
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
