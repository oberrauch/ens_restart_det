%% RERUN TEMPLATES
% TODO:

% As the name might suggest, this is the main script which calls all the all
% the other scripts.

%% Initialization

% clean workspace and close all open figures
clear;
close all;

run_loo = false;

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
suffix = 'INTERP_2ND_ROUND';
main_dir = ['D:\MODEL_OUTPUT\HS_ASSIMILATION\LOO_', suffix];
% create directory
create_folder(main_dir);

% define common settings for all subscripts
common_settings = struct();
% run for 2021/2022 season
time_start = datenum(2021, 11, 01);
time_end = datenum(2022, 06, 30);
% run for all controlled stations (444)
common_settings.sel_stat = {'controlled_stats'};
% common_settings.sel_stat = {'SLF.5WJ'};
% multiprocessing settigns
common_settings.n_cores = 10;
common_settings.par_type = 'low';

% use local copy of MetDataWizard session for speedup
season_start_month = 9; % September is start of the season
if year(time_start) < year(today()) - (month(today()) < season_start_month)  % this is very hacky, but works
  % use PREVIOUS MDW maps for previous seasons
  common_settings.mdw_session = 'D:\INPUT_DATA\DATA_MDW\OSHD_EKF_MAPS_PREV_rescreen_BC_TJ_NOGRIDS.MDW';
else
  % use CURRENT MDW maps for current seasons
  common_settings.mdw_session = 'D:\INPUT_DATA\DATA_MDW\OSHD_EKF_2023_MAPS_CURR.MDW';
end

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
meteo_perturb_out_dir = ['D:\INPUT_DATA\AVG_PERTURBATIONS_ALIGN_DET_4K_BIG_ENS'];
meteo_perturb_out_dir = fullfile(meteo_perturb_out_dir, prcp_input_text);
create_folder(meteo_perturb_out_dir);

% re-initialization settings
common_settings.init_type = 'initialize';

%% LOO Exps

radii_km = [35];
sigma = [1/2];
z_scaling = [0, 10, 20, 25, 30];

interp_params = combvec(radii_km, sigma, z_scaling);
n_param_combinations = size(interp_params, 2);

common_settings.time_start = time_start;
common_settings.time_end = time_end;
common_settings.interp_loo = true;
common_settings.interp_exact_match = false;
common_settings.interp_method = '3dgauss';
common_settings.interp_fill_nan_kriging = false;

if run_loo

  for i_param = 1:n_param_combinations

    curr_radius_km = interp_params(1, i_param);
    common_settings.interp_radius_km = curr_radius_km;
    curr_sigma = curr_radius_km * interp_params(2, i_param);
    common_settings.interp_sigma_km = curr_sigma;
    curr_z_scaling = interp_params(3, i_param);
    common_settings.interp_z_scaling = curr_z_scaling;
    curr_main_dir = fullfile(main_dir, [num2str(curr_radius_km, 2),  '_', num2str(curr_sigma, 2), '_', num2str(curr_z_scaling, '%.0f')]);
    f04_start_leave_one_out(curr_main_dir, common_settings, meteo_perturb_out_dir);

  end

end

%% Load output

colors = brewermap(n_param_combinations, "Spectral");

out_path = fullfile(main_dir, 'eval_data');
if ~isfile(fullfile(out_path, 'automatic_stations.mat'))

  experiments = [];
  for i_param = 1:n_param_combinations

    curr_radius_km = interp_params(1, i_param);
    curr_sigma = curr_radius_km * interp_params(2, i_param);
    curr_z_scaling = interp_params(3, i_param);
    curr_desc = [num2str(curr_radius_km, 2),  '_', num2str(curr_sigma, 2), '_', num2str(curr_z_scaling, "%02.0f")];
    curr_main_dir = fullfile(main_dir, curr_desc, 'COSMO/leave_one_out/3dgauss/OUTPUT_STAT/');
    experiments = [experiments; struct('path', curr_main_dir, 'desc', curr_desc, 'color', colors(i_param, :))];
  end

  experiments = load_settings_aux(experiments);
  [obs, sim] = load_point_timeseries(experiments, "hsnt", 'sim_var_list', "hsnt");

  % save to file
  create_folder(out_path);
  save(fullfile(out_path, 'automatic_stations.mat'), "obs", "sim", "experiments");
else
  load(fullfile(out_path, 'automatic_stations.mat'));
end

%% Evaluation

% curr_rad = 20;
% curr_sigma = NaN;
% curr_z_scaling = 100;
%
idx = ones(1, n_param_combinations);
% if isfinite(curr_rad)
%   idx = idx & params(1, :) == curr_rad;
% end
% if isfinite(curr_sigma)
%   idx = idx & params(2, :) == curr_sigma;
% end
% if isfinite(curr_z_scaling)
%   idx = idx & params(3, :) == curr_z_scaling;
% end
% stats = stats_automatic_stations(sim, obs, experiments, fullfile(main_dir, 'figures'), "hsnt", "hsnt", "visibility", "false", "plot", true);
% plot_ts_elevationbands(sim(idx), obs, experiments(idx), fullfile(main_dir, 'figures'));

%%

n_exps = n_param_combinations;
params.agg_method = 'time';

% initialize scores
rmse_var = [];
bias_var = [];
r_var = [];
z = [];
desc = [];
count_var = [];

% put observation and simulation structs of all experiments in a single cell
obs_var = obs.hsnt;
sim_var_name = 'hsnt';
vec_obs_sim_struct = {obs_var};
for i_exp = 1:n_exps
  vec_obs_sim_struct{i_exp+1} = sim{i_exp}.(sim_var_name);
end
% restrict to common stations and timeframe
[~, i_common_stat] = find_common_stations_results(vec_obs_sim_struct{:});
[~, i_common_time] = find_common_time_results(vec_obs_sim_struct{:});

% iterate over all experiments
for i_exp = 1:n_exps
  sim_var = sim{i_exp}.(sim_var_name);

  % unit check from MO
  if ~strcmp(sim_var.unit, obs_var.unit)
    error(['The units of sim and obs do not match (' sim_var.unit ' vs. ' obs_var.unit ')']);
  end
  % BC discriminate btw ensemble and determ.
  if ~experiments(i_exp).settings.is_ens
    % Deterministic case
    sim_data = sim_var.data(1,i_common_stat{i_exp+1},i_common_time{i_exp+1});
  else
    % Ensemble case: use the median (assuming equal weights)
    sim_data = median(sim_var.data(:,i_common_stat{i_exp+1},i_common_time{i_exp+1}),1);
  end

  % remove first (out of three dimensions), which is a singleton.
  sim_data = reshape(sim_data, [size(sim_data, 2), size(sim_data, 3)]);
  [rmse_vals, ikeep] = rmse(sim_data, obs_var.data(i_common_stat{1},i_common_time{1}), 'agg_method', params.agg_method);
  rmse_var = [rmse_var; rmse_vals];
  bias_var = [bias_var; bias(sim_data, obs_var.data(i_common_stat{1},i_common_time{1}), 'agg_method', params.agg_method)];
  r_var = [r_var; correlation(sim_data, obs_var.data(i_common_stat{1},i_common_time{1}), 'agg_method', params.agg_method)];
  desc = [desc; repmat(string(experiments(i_exp).desc), length(obs_var.z(i_common_stat{1})), 1)];
  z = [z; obs_var.z(i_common_stat{1})];
  count_var = [count_var; sum(ikeep,2)];
end


%%

vars = [rmse_var, rmse_var, bias_var, bias_var];
var_text = ["RMSE", "RMSE", "BIAS", "BIAS"];
group_fun = {'mean', @iqr, 'mean', @iqr};
z_bins = [0, 500, 1000, 1500, 2000, 2500, 3500];
n_elev_bands = length(z_bins) - 1;

% initialize subplot axis counter
figure()
t = tiledlayout(2, 2);

for i=1:4

  nexttile();

  [grouped_val, groups, group_count] = groupsummary(vars(:, i), {desc, z}, {'none', z_bins}, group_fun{i});
  title_text = [upper(char(group_fun{i})), ' ' char(var_text(i))];
  n_radii = length(radii_km);
  n_sigma = length(sigma);
  n_z_scaling = length(z_scaling);

  % clims = [min(grouped_val), max(grouped_val)];
  cmap = flipud(brewermap([], 'RdYlGn'));
  
  grid = [];
  curr_sigma = sigma;
  elev_groups = unique(groups{2})';
  for curr_elev_band = elev_groups
    % new subplot for different sigmas

    sigma_vals = split(num2str(curr_sigma*radii_km, 2));
    search_string = cellstr(strcat(string(radii_km'), repmat("_",  size(sigma_vals)), string(sigma_vals), repmat("_",  size(sigma_vals))));
    % search_string = cellstr(strcat(string(radii_km'), repmat("_",  size(sigma_vals)), string(sigma_vals), repmat("_",  size(sigma_vals)), num2str(curr_z_scaling, "%02.0f")));
    curr_group_idx = contains(groups{1}, search_string) & groups{2} == curr_elev_band;
    curr_column = grouped_val(curr_group_idx);
    % curr_column = curr_column/max(curr_group_idx);
    grid = [grid, curr_column];
  end

  colormap(cmap)
  imagesc(grid./max(grid));
  xticks([1:n_elev_bands])
  xticklabels(elev_groups)
  % xlabel('Elevation [m]')
  yticks([1:n_z_scaling])
  yticklabels(z_scaling)
  ylabel('Z scaling factor')
  title(title_text)


end

%
%   cbar = colorbar();
%   cbar.Layout.Tile = 'east';
%   cbar.Label.String = var_text;

%%

% elev_band_bins = [0, 1000, 1500, 2000, 2500, 4000];
% [grouped_val, groups, group_count] = groupsummary(rmse_var, {desc, z}, {"none", elev_band_bins}, "mean");
%
%
% all_desc = unique(groups{1});
% elev_bands = unique(groups{2});
% n_elev_bands = length(elev_bands);
%
% % iterate over the groups
% for i_elev_band = 1:n_elev_bands
%   curr_elev_band = elev_bands(i_elev_band);
%   for i_desc = 1:n_exps
%     curr_desc = all_desc(i_desc);
%     curr_idx = strcmp(groups{1}, curr_desc) & groups{2} == curr_elev_band;
%     curr_val = grouped_val(curr_idx);
%   end
%   break
% end
