%% RERUN TEMPLATES
% TODO:

% As the name might suggest, this is the main script which calls all the all
% the other scripts.

%% Initialization

% clean workspace and close all open figures
clear;
close all;

run_sim = true;
run_loo = true;
run_oloo = true;

% define paths to needed repositories/folders
fsm_repo = 'C:/code_dev/jim_operational/';
eval_repo = 'C:/code_dev/oshd_evaluation/';
mdw_repo = 'D:/MetDataWizard/';
[curr_repo, ~, ~] = fileparts(mfilename("fullpath"));

% correctly add to matlab path
addpath(genpath(fullfile(fsm_repo, 'MATLAB_SCRIPTS'))) % matlab WRAPPER
addpath(genpath(fullfile(fsm_repo, 'SOURCE'))) % FSM Fortran source files
addpath(genpath(eval_repo)) % EVALUATION repository
addpath(genpath(mdw_repo)) % MetDataWizard repository
addpath(genpath(curr_repo)) % current repository/folder

%% Specify settings

% specify main output folder
suffix = 'PAPER';
pert_suffix = 'ALIGN_DET_4K_BIG_ENS';
main_dir = ['D:\MODEL_OUTPUT\HS_ASSIMILATION\PF_', suffix];
% create directory
create_folder(main_dir);

% define common settings for all subscripts
common_settings = struct();

% run for all controlled stations (444)
common_settings.sel_stat = {'controlled_stats'};
% common_settings.sel_stat = {'SLF.5WJ'};
% multiprocessing settigns
common_settings.n_cores = 10;
common_settings.par_type = 'low';



% select precipitation input
prec_input_folder = "";
common_settings.prec_input_folder = prec_input_folder;
common_settings.prec_input_folder_INCA = '';
prcp_input_text = common_settings.prec_input_folder.split('\');
prcp_input_text = char(prcp_input_text(end));
if isempty(prcp_input_text)
  prcp_input_text = 'COSMO';
end
% specify out folder for perturbations
meteo_perturb_out_dir = ['D:\INPUT_DATA\AVG_PERTURBATIONS_', pert_suffix];
meteo_perturb_out_dir = fullfile(meteo_perturb_out_dir, prcp_input_text);
create_folder(meteo_perturb_out_dir);

% re-initialization settings
common_settings.init_type = 'reinitialize';
common_settings.overrite_states = true;
common_settings.states_folder_reinit = fullfile(main_dir, prcp_input_text, 'rerun', 'OUTPUT_STAT');
common_settings.pfaux_folder_reinit = fullfile(main_dir, prcp_input_text, 'PF_res', 'OUTPUT_STAT');

%% PF settings

% ensemble settings
pf_settings = common_settings;

% perturb incoming longwave radiation, air temperature and precipitation
pf_settings.ens.perturb_LW = true;
pf_settings.ens.perturb_Ta = true;
pf_settings.ens.perturb_P = true;
% no perturbation for the other input variables
pf_settings.ens.perturb_Ua = false;
pf_settings.ens.perturb_SW = false;
pf_settings.ens.perturb_RH = false;
%
pf_settings.ens.decorr_LW = inf;

pf_settings.ens.decorr_Ta = inf;

pf_settings.ens.decorr_P = inf;
pf_settings.ens.sigma_P = 0.61;
pf_settings.ens.mu_P = 0;

pf_settings.ens.random_q = false; % use "nice" initial perturbation

% no model perturbations
pf_settings.ens.pert_model = false;

% folder where to write and read the perturbations to/from
pf_settings.ens.pert_folder = fullfile(['D:\INPUT_DATA\PERTURBATIONS_', suffix], 'METEO_PERTURBATIONS');

% assimilation settings
pf_settings.num_ens = 5000; % number of particles
pf_settings.pf.Nresample = pf_settings.num_ens + 1; % always resample
pf_settings.pf.rs_method = 'systematic'; % resampling method
pf_settings.assim.assim_cond = 'from_list'; % assimilation period

pf_settings.pf.rs_noise = false; % don't resample noise parameters
pf_settings.pf.shuffle_noise = true; % shuffle noise parameters


seasons = [2018, 2019, 2020, 2021, 2022];
n_seasons = length(seasons);

for i_season = 1:n_seasons
  % run for 2021/2022 season
  curr_year = seasons(i_season);
  time_start = datenum(curr_year, 10, 01);
  time_end = datenum(curr_year+1, 06, 30);
  % use local copy of MetDataWizard session for speedup
  season_start_month = 9; % September is start of the season
  if year(time_start) < year(today()) - (month(today()) < season_start_month)  % this is very hacky, but works
    % use PREVIOUS MDW maps for previous seasons
    common_settings.mdw_session = 'D:\INPUT_DATA\DATA_MDW\OSHD_EKF_MAPS_PREV_rescreen_BC_TJ_NOGRIDS.MDW';
  else
    % use CURRENT MDW maps for current seasons
    common_settings.mdw_session = 'D:\INPUT_DATA\DATA_MDW\OSHD_EKF_2023_MAPS_CURR.MDW';
  end

  %% Simulations and computation of perturbations

  % iterate over all assimilation periods
  days_assim_period = 3;
  assim_dates = time_start+days_assim_period:days_assim_period:time_end;
  n_assim_periods = length(assim_dates);

  % settings for first iteration
  start_date_idx = 74;
  if start_date_idx > 1
    common_settings.time_start = assim_dates(start_date_idx-1);
  else
    common_settings.time_start = time_start;
  end

  pf_settings.assim.assimdates_list = assim_dates;

  if run_sim

    for i_assim_date = start_date_idx:n_assim_periods
      % start/end time settings
      curr_assim_date = assim_dates(i_assim_date);
      common_settings.time_end = curr_assim_date;

      % copy to PF settings
      pf_settings.time_start = common_settings.time_start;
      pf_settings.time_end = common_settings.time_end;

      % run PF simulation
      f02_start_script(main_dir, pf_settings, run_det = false, run_pf = true);

      % load perturbations
      experiment_pf = [struct("path", fullfile(main_dir, prcp_input_text, 'PF_res', 'OUTPUT_STAT'), ...
        "desc", "PF")];
      experiment_pf = load_settings_aux(experiment_pf);

      % load perturbations
      fields.name = ["LW_noise", "Ta_noise", "P_noise"];
      fields.perturb_type = ["add", "add", "mult"];
      perturbations = load_perturbation_timeseries(experiment_pf, ...
        "date_start",  common_settings.time_start, ...
        "date_end",  curr_assim_date,...
        "verbosity", false, "fields", fields);
      % average perturbations over assimilation period
      pert_avg = avg_perturbations_assim_periods(perturbations{1}, experiment_pf(1), fields=fields, assim_dates=curr_assim_date);

      % compute modes of posterior perturbation distribution
      expected_perturbation_analysis_3d(pert_avg, experiment_pf(1), ...
        'out_dir', meteo_perturb_out_dir, 'weighted', true, 'last_assim_only', true);

      %% rerun
      f04_start_rerun(main_dir, common_settings, meteo_perturb_out_dir);

      % set current end time as next iterations start time
      common_settings.time_start = curr_assim_date;

    end

    %%
    disp('PF/Rerun simulations DONE!')

  end


  %% LOO Exps
  if run_loo
    common_settings.time_start = time_start;
    common_settings.time_end = time_end;

    % loo
    common_settings.interp_loo = true;
    common_settings.interp_method = '3dgauss';
    common_settings.interp_fill_nan_kriging = false;
    f04_start_leave_one_out(main_dir, common_settings, meteo_perturb_out_dir);

    %   % loo 3DGauss, fill with Kriging
    %   common_settings.interp_fill_nan_kriging = true;
    %   f04_start_leave_one_out(main_dir, common_settings, meteo_perturb_out_dir);

    % loo Krigin
    % common_settings.interp_method = 'kriging';
    % % common_settings.time_start = datenum('18-Jun-2022');
    % % common_settings.init_type = 'reinitialize';
    % % common_settings.states_folder_reinit = main_dir;
    % f04_start_leave_one_out(main_dir, common_settings, meteo_perturb_out_dir);
  end

  %% O-LOO Exps
  if run_oloo

    % oloo
    common_settings.time_start = time_start;
    common_settings.time_end = time_end;
    common_settings.interp_loo = false;
    common_settings.interp_method = '3dgauss';
    common_settings.interp_fill_nan_kriging = false;
    f04_start_leave_one_out(main_dir, common_settings, meteo_perturb_out_dir);

    %   common_settings.interp_fill_nan_kriging = true;
    %   f04_start_leave_one_out(main_dir, common_settings, meteo_perturb_out_dir);
  end

end

