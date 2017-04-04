warning off all;

clearvars;
clc;
close all;

analyse_volatility('YAHOO/JPM',2013,2013,'CCD');
compare_estimators('YAHOO/JPM',2010,2017,90);