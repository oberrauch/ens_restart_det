function f05_evaluate_reruns(main_dir, common_settings, params)
  % F05_EVALUATE_RERUN evaluate rerun and leave-one-out spatialization
  %
  % This function reads the point simulation data of the reruns and stores
  % them to file and/or plot the results.
  %
  % The MAIN_DIR specifies the path to the main output directory.
  % Depending on settings (e.g. precipiation input), subdirectories will be
  % created within.
  %
  % All other relevant simulation settings can be specified in the
  % COMMON_SETTINGS struct, analogous to the default Simulation_Settings_PF.
  % They should be the same as in `f02_start_script`, hence the name!
  %
  % It is possible to switch ON/OFF the storing and plotting by using the
  % logical arguments STORE (default true) and PLOT (default false). The data
  % will be store in the specified output folder in the subfolder `eval_data`,
  % while plots will be stored in the subfolder `figures`.

  arguments
    main_dir
    common_settings struct
    params.plot = false
    params.store = true
  end

  % load colors
  % TODO: can I use pf_colors only?!
  colors = load("C:/code_dev/oshd_evaluation/misc/my_colors");

  % specify model output folder by concatenating the given main directory
  % with the selected precipitation input
  prcp_input_text = common_settings.prec_input_folder.split('\');
  prcp_input_text = char(prcp_input_text(end));
  if isempty(prcp_input_text)
    prcp_input_text = 'COSMO';
  end
  parent_root_directoy = fullfile(main_dir, prcp_input_text);
  

  %% specify experiments

  % particle filter run
  experiments = [
    struct("path", fullfile(parent_root_directoy, 'PF_res', 'OUTPUT_STAT'), ...
    "desc", "LOO w/ global slpx", ...
    "color", colors.sim_colors(end, :), ...
    "plot_maps", false); ...
  ];
  
  % add all rerun experiments (station level and leave-one-out) for different
  % perturbation "averaging" methods
  sub_dirs = ["WEIGHTED_MEAN"];
  sub_dirs_short = [""];
  for j = 1:length(sub_dirs)
    sub_dir = sub_dirs(j);
    exp_tmp = [
        struct("path", fullfile(parent_root_directoy, sub_dir, 'rerun', 'OUTPUT_STAT'), ...
        "desc", strcat("Rerun", sub_dirs_short(j)),...
        "color", colors.sim_colors(0+j, :), ...
        "plot_maps", false); ...
        struct("path", fullfile(parent_root_directoy, sub_dir, 'leave_one_out', 'OUTPUT_STAT'), ...
        "desc", strcat("LOO", sub_dirs_short(j)),...
        "color", colors.sim_colors(1+j, :), ...
        "plot_maps", false); ...
      ];
    % add to container
    experiments = [experiments; exp_tmp];
  end

  % add deterministic run
  experiments = [experiments;
    struct("path", fullfile(parent_root_directoy, 'PF_det', 'OUTPUT_STAT'), ...
    "desc", "DET", ...
    "color", colors.det_color, ...
    "plot_maps", false); ...
    ];

  % Load settings and potential aux structures
  experiments = load_settings_aux(experiments);

  %% Load results
  
  % specify some settings needed to load and plot point simulation data
  if ~isfield(common_settings, 'time_start') ...
    || isempty(common_settings.time_start)
    % add start time from experiments to common settigns if not given already
    common_settings.time_start = experiments(1).settings.time_start;
  end
  if ~isfield(common_settings, 'time_end') ...
    || isempty(common_settings.time_end)
    % add end time from experiments to common settigns  if not given already
    common_settings.time_end = experiments(1).settings.time_end;
  end
  obs_var_list = ["hsnt", "swep"];
  sim_var_list = ["hsnt", "swet"];
  [obs, sim] = load_point_timeseries(experiments, ...
    obs_var_list, 'sim_var_list', sim_var_list, ...
    'date_start', common_settings.time_start, ...
    'date_end', common_settings.time_end);
  
  %% Store to file
  if params.store
    path_results = fullfile(parent_root_directoy, 'eval_data', ...
      'automatic_stations.mat');
    mkdir(fileparts(path_results));
    disp(['Storing obs, sim and experiment struct in ' char(path_results)]);
    save(path_results, "obs", "sim", "experiments", '-v7.3')
  end

  %% Plotting
  if params.plot
    disp('Plotting & Stats ...');
    path_results = fullfile(parent_root_directoy, 'figures');
    disp(['Storing plots in ' char(path_results)])

    % compute needed plotting parameters    
    year_start = year(common_settings.time_start);
    year_end = max(year_start, year(common_settings.time_end)-1);

    % plot HS for each station
    % plot_automatic_stations_ensemble(sim, obs, experiments, path_results, ...
    %  year_start, year_end, 0)
    % compute and plot stats
    stats_automatic_stations(sim, obs, experiments, path_results, ...
      obs_var_list, sim_var_list);
    % compute HS timeseries aggregated over elevation bands
    plot_ts_elevationbands(sim, obs, experiments, path_results);
  end

end
