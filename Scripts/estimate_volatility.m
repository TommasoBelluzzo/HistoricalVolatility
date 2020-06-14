% [INPUT]
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
% bw = An integer [2,252] representing the dimension of each rolling window.
% clean = A boolean that indicates whether to remove the NaN values at the beginning of the result (optional, default=true).
%
% [OUTPUT]
% vol  = A vector of floats containing the estimated historical volatility.

function vol = estimate_volatility(varargin)

    persistent ip;

    if (isempty(ip))
        ip = inputParser();
        ip.addRequired('data',@(x)validateattributes(x,{'table'},{'2d','nonempty','ncols',6}));
        ip.addRequired('e',@(x)any(validatestring(x,{'CC','CCD','GK','GKYZ','HT','M','P','RS','YZ'})));
        ip.addRequired('bw',@(x)validateattributes(x,{'double'},{'real' 'finite','integer' '>=' 2 '<=' 252 'scalar'}));
        ip.addOptional('clean',true,@(x)validateattributes(x,{'logical'},{'scalar'}));
    end

    ip.parse(varargin{:});
    
    ipr = ip.Results;
    data = validate_data(ipr.data);
    e = ipr.e;
    bw = validate_bandwidth(ipr.bw,data);
    clean = ipr.clean;

    vol = estimate_volatility_internal(data,e,bw,clean);

end

function vol = estimate_volatility_internal(data,e,bw,clean)

    t = height(data);

    switch (e)

        case 'CC'
            res = data.Return .^ 2;
            param = sqrt(252 / (bw - 1));
            fun = @(x) param * sqrt(sum(x));

        case 'CCD'
            res = (data.Return - nanmean(data.Return)) .^ 2;
            param = sqrt(252 / (bw - 1));
            fun = @(x) param * sqrt(sum(x));

        case 'GK'
            co = log(data.Close ./ data.Open);
            hl = log(data.High ./ data.Low);
            res = 0.5 * (hl .^ 2) - ((2 * log(2)) - 1) * (co .^ 2);
            param = sqrt(252 / bw);
            fun = @(x) param * sqrt(sum(x));

        case 'GKYZ'
            co = log(data.Close ./ data.Open);
            hl = log(data.High ./ data.Low);
            oc = log(data.Open ./ [NaN; data.Close(1:end-1)]) .^ 2;
            res = oc + 0.5 * (hl .^ 2) - ((2 * log(2)) - 1) * (co .^ 2);
            param = sqrt(252 / bw);
            fun = @(x) param * sqrt(sum(x));

        case 'HT'
            res = data.Return;
            dif = t - bw;
            param = sqrt(252 / (1 - (bw / dif) + (((bw ^ 2) - 1) / (3 * (dif ^ 2)))));
            fun = @(x) param * std(x);

        case 'M'
            co = log(data.Close ./ data.Open);
            ho = log(data.High ./ data.Open);
            lo = log(data.Low ./ data.Open);
            s2 = log(data.Close ./ data.Open) .^ 2;
            co_neg = co < 0;
            co_swi = -1 .* co;
            ho_swi = ho;
            ho_swi(co_neg) = -1 .* lo(co_neg);
            lo_swi = lo;          
            lo_swi(co_neg) = -1 .* ho(co_neg);
            s1 = 2 .* (((ho_swi - co_swi) .^ 2) + (lo_swi .^ 2));
            s3 = 2 .* ((ho_swi - co_swi - lo_swi) .* co_swi);
            s4 = -1 .* (((ho_swi - co_swi) .* lo_swi) ./ ((2 * log(2)) - 1.25));
            res = (0.273520 * s1) + (0.160358 * s2) + (0.365212 * s3) + (0.200910 * s4);
            param = sqrt(252 / bw);
            fun = @(x) param * sqrt(sum(x));

        case 'P'        
            res = log(data.High ./ data.Low) .^ 2;
            param = sqrt(252 / (bw * 4 * log(2)));
            fun = @(x) param * sqrt(sum(x));

        case 'RS'
            co = log(data.Close ./ data.Open);
            ho = log(data.High ./ data.Open);
            lo = log(data.Low ./ data.Open);
            res = (ho .* (ho - co)) + (lo .* (lo - co));
            param = sqrt(252 / bw);
            fun = @(x) param * sqrt(sum(x));

        case 'YZ'
            co = log(data.Close ./ data.Open);
            ho = log(data.High ./ data.Open);
            lo = log(data.Low ./ data.Open);
            res = [(log(data.Open ./ [NaN; data.Close(1:end-1)]) .^ 2) (co .^ 2) ((ho .* (ho - co)) + (lo .* (lo - co)))];
            k = 0.34 / (1.34 + ((bw + 1) / (bw - 1)));
            param_1 = [(252 / (bw - 1)) (252 / (bw - 1)) (252 / bw)];
            param_2 = [1 k (1 - k)];
            fun = @(x) sqrt(sum(sum(param_1 .* param_2 .* x,1)));

    end

    windows = extract_rolling_windows(res,bw,true);
    windows_len = length(windows);
    win_diff = t - windows_len;
    
    vol = NaN(t,1);
    
    for i = 1:windows_len
        vol(i+win_diff) = fun(windows{i});
    end
    
    if (clean)
        vol(isnan(vol)) = [];
    end

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
