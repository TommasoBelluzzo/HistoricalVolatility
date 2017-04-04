warning off all;

close all;

clearvars;
clc;

analyse_volatility('YAHOO/JPM',2010,2017,'YZ');
compare_estimators('YAHOO/JPM',2010,2017,90);
