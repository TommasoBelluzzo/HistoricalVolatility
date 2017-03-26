% CC = Close To Close
% CCD = Close To Close Demeaned
% GK = Garman & Klass (1980)
% HT = Hodges & Tompkins (2002)
% P = Parkinson (1980)
% RS = Rogers & Satchell (1991)
% T = Traditional
% YZ = Yang & Zhang (2000)

function vol = estimate_volatility(data,est,bw,cln)
    
    if (~ischar(est))
        error('Invalid estimator specified.');
    end
    
    t = size(data,1);
    est = upper(est);

    switch est
        case 'CC'
            res = data.Returns;
            para = sqrt(252);
            fun = @(x) para * std(x);
        case 'CCD'
            res = (data.Returns - mean(data.Returns)) .^ 2;
            para = 252 / (bw - 2);
            fun = @(x) sqrt(para * sum(x));
        case 'GK'
            log_hl = log(data.High ./ data.Low);
            log_co = log(data.Close ./ data.Open);
            res = 0.5 * (log_hl .^ 2) - ((2 * log(2)) - 1) * (log_co .^ 2);
            para = 252 / bw;
            fun = @(x) sqrt(para * sum(x));
        case 'HT'
            res = data.Returns;
            bw1 = bw - 1;
            t1 = t - 1;
            para = sqrt((1 / (1 - (bw / (t1 - bw1)) + ((bw^2 - 1) / (3 * (t1 - bw1)^2)))) * 252);
            fun = @(x) para * std(x);
        case 'P'        
            log_hl = log(data.High ./ data.Low);
            res = (1 / (4 * log(2))) * (log_hl .^ 2);
            para = 252 / bw;
            fun = @(x) sqrt(para * sum(x));
        case 'RS'
            log_ho = log(data.High ./ data.Open);
            log_lo = log(data.Low ./ data.Open);
            log_co = log(data.Close ./ data.Open);
            res = (log_ho .* (log_ho - log_co)) + (log_lo .* (log_lo - log_co));
            para = 252 / bw;
            fun = @(x) sqrt(para * sum(x));
        otherwise
            error(['Invalid estimator "' est '" specified.']);
    end

    win = get_rolling_windows(res,bw);
    win_len = length(win);

    if (cln)
        vol = zeros(win_len,1);

        for i = 1:win_len
            vol(i) = fun(win{i});
        end
    else
        win_dif = t - win_len;
        vol = NaN(t,1);
        
        for i = 1:win_len
            vol(i+win_dif) = fun(win{i});
        end
    end

end
