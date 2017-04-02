% [INPUT]
% data = A t-by-n matrix containing the time series.
% bw   = A scalar representing the bandwidth (dimension) of each rolling window.
%
% [OUTPUT]
% win  = A column vector containing the rolling windows.
%
% [NOTE]
% If the number of observations is less than or equal to the specified bandwidth, a single rolling window containing all the observations is returned.

function win = get_rolling_windows(varargin)

    persistent p;

    if isempty(p)
        p = inputParser();
        p.addRequired('data',@(x)validateattributes(x,{'numeric'},{'2d','nonempty'}));
        p.addRequired('bw',@(x)validateattributes(x,{'numeric'},{'scalar','integer','real','finite','>=',2}));
    end

    p.parse(varargin{:});
    res = p.Results;
    
    win = get_rolling_windows_internal(res.data,res.bw);

end

function win = get_rolling_windows_internal(data,bw)

    t = size(data,1);
    
    if (bw >= t)
        win = cell(1,1);
        win{1} = data;
        return;
    end

    lim = t - bw + 1;
    win = cell(lim,1);

    for i = 1:lim
        win{i} = data(i:bw+i-1,:);
    end

end