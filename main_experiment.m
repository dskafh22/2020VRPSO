% runs an entire experiment for benchmarking MY_OPTIMIZER
% on the noise-free testbed. fgeneric.m and benchmarks.m
% must be in the path of Matlab/Octave
% CAPITALIZATION indicates code adaptations to be made
clc
clear
close all

dbstop if error
more off;  % in octave pagination is on by default

% %%%poolobj = parpool;

% delete(gcp('nocreate'));
% parpool('local', 12);
% poolobj = gcp('nocreate');

% datadir = '/root/Documents/Matlab/TECDATA-t/';
% addpath(genpath('/root/Documents/Matlab/TEC'));

datadir = 'F:/DATAt'; %% 不同系统的文件夹名，可以控制是否写入文件
% addpath(genpath('RNN/BBOB09'));  % should point to fgeneric.m etc.
% rmpath(genpath('RNN/BBOB09/MCS'));
% opt.algName = 'PUT ALGORITHM NAME';
% opt.comments = 'PUT MORE DETAILED INFORMATION, PARAMETER SETTINGS ETC';
% maxfunevals = '1e4 * dim';  % SHORT EXPERIMENT, takes overall three minutes
% maxInsts = 10;
% maxRepeats = 10;
maxInsts = 10;
maxRepeats = 10;

algorithmSet = {
%     'PSO_Bounds', ...
%         'LPSO', ...
%         'DMSPSO', ...
%         'FIPS', ...
%         'RLPSO', ...
            'BFGS',...
            'PSO',...
%             'NELDER',...
%         'new',...
        };

t0 = clock;
% global TYPE
for TYPE =  1
    if TYPE == 1
        lower = -5;upper = 5;
        FUNNUMS = [9,10,11,12,13,14];
        FUN = 'fgeneric';
    else % our function
        lower = -20;upper = 20;
        FUNNUMS = 1:9;
        FUN = 'fgenericCBG';
    end
    % FUN = 'MYFUN';
    
    % rand('state', sum(100 * t0));
    % rng('default');
    % rand('state', 1);
    for dim = [2,10,20]  % small dimensions first, for CPU reasons ,2,3,5,10,20,
        maxfunevals = 1e3 * dim;
        for ifun = FUNNUMS %[1:10]%1:24 %benchmarks('FunctionIndices')  % or benchmarksnoisy(...)
            T = 5; N = 10; s=1;
            r= rand(maxInsts,maxRepeats*numel(algorithmSet))*1e8;
            for i = 1:maxInsts
                k = 0;
                while length(r(i,:))-length(unique(r(i,:))) ~= 0
                    r(i,:) = rand(1,maxRepeats*numel(algorithmSet))*1e8;
                    k = k + 1;
                    if k > 1000
                        break;
                    end
                end
            end
            for iinstance = 1:maxInsts % [3,5,7]% [1:5, 1:5, 1:5]  % first 5 fct instances, three times
                rs = r(iinstance, :);
                if TYPE == 1
                    datapath = sprintf('%s/%dD_BBOB_EXPERIMENTS/f%d',datadir,dim,ifun); % example: F:/DATA/2D_BBOB_EXPERIMENTS/f1/NELDER,无用
                    ftarget = fgeneric('initialize', ifun, dim, iinstance, 0, datapath, []);
                else
                    datapath = sprintf('%s/%dD_CBG_EXPERIMENTS/f%d',datadir,dim,ifun); % example: F:/DATA/2D_CBG_EXPERIMENTS/f1/NELDER
                    ftarget = fgenericCBG('initialize', ifun, dim, T, N, s, iinstance, 0, datapath, []);
                end
                
                for mid = 1:numel(algorithmSet)
                    algorithm = algorithmSet{mid};
                    
                    for repeat = 1:maxRepeats
                        RandStream.setGlobalStream(RandStream('mt19937ar','seed',rs((mid-1)*maxInsts+repeat)));
                        if TYPE == 1
                            datapath = sprintf('%s/%dD_BBOB_EXPERIMENTS/f%d/%s',datadir,dim,ifun,algorithm);
                            if ~exist(datapath, 'dir'); mkdir(datapath);end
                            datafile = sprintf('%s/exp_%02u_%02u_f%d_DIM%d.tdat', datapath, iinstance, repeat, ifun, dim);
                            fp = fopen(datafile,'w'); fprintf(fp, ''); fclose(fp);
                            fgeneric('repeat', ifun, dim, iinstance, repeat, datapath, []); %
                        else
                            datapath = sprintf('%s/%dD_CBG_EXPERIMENTS/f%d/%s',datadir,dim,ifun,algorithm);
                            if ~exist(datapath, 'dir'); mkdir(datapath);end
                            datafile = sprintf('%s/exp_%02u_%02u_f%d_DIM%d.tdat', datapath, iinstance, repeat, ifun, dim); % example: F:/DATA/2D_BBOB_EXPERIMENTS/f1/NELDER/exp_09_01_f4_DIM2.tdat
                            fp = fopen(datafile,'w'); fprintf(fp, ''); fclose(fp);
                            fgenericCBG('repeat', ifun, dim, T, N, s, iinstance, repeat, datapath, []); %
                        end
                        
                        switch algorithm
                            case 'PSO_Bounds'
                                PSO_Bounds(FUN, dim, lower, upper, ftarget, maxfunevals); % PSO_Bounds
                            case 'LPSO'
                                LPSO(FUN,40,dim,lower,upper,ftarget,maxfunevals); % LPSO
                            case 'DMSPSO'
                                DMSPSO(FUN,4,16,dim,lower,upper,ftarget,maxfunevals);
                            case 'FIPS'
                                fips_uring(FUN,40,dim,lower,upper,ftarget,maxfunevals);
                            case 'RLPSO'
                                M_GPSO11(FUN,dim,lower,upper,ftarget,maxfunevals);
                            case 'new'
                                new(FUN,dim,lower,upper,ftarget,maxfunevals);
                            case 'BFGS'
                                  BFGS(FUN,dim,lower,upper,ftarget,maxfunevals);
                            case 'PSO'
                                PSO(FUN,dim,lower,upper,ftarget,maxfunevals);
                            case 'NELDER'
                                NELDER(FUN,dim,lower,upper,ftarget,maxfunevals);
                                
                        end
                        outtime = formatTime(etime(clock, t0));
                        fprintf('TYPE%d - %2dD, f%2d - inst%2d, alg: %-15s || repeat = %2d, FEs = %7d, fbest-ft = %.2e \t total time: %s \n', ...
                            TYPE, dim, ifun, iinstance, algorithm, repeat, ...
                            feval(FUN, 'evaluations'), ...
                            feval(FUN, 'fbest')-feval(FUN, 'ftarget'),...
                            outtime);
                        feval(FUN, 'repeatfinal');
                    end
                end
                fprintf('---- T%d dimension %d-D, fun%d - instance%d all agorithms  done \n', TYPE, dim, ifun, iinstance);
                feval(FUN, 'finalize');
            end
            fprintf('---- T%d dimension %d-D, fun%d - all instances done, %s ---- \n', TYPE, dim, ifun, datetime);
        end
        fprintf('-----***------T%d dimension %d-D, all functions done , %s------***------\n', TYPE, dim, datetime);
    end
    fprintf('Type%d  done !!!! \n', TYPE);
    
end
%
if exist('poolobj')
    delete(poolobj);
end
