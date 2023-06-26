function f03_evaluate_pf_det_run(main_dir, common_settings, ...
    meteo_perturb_out_dir, params)
  % F03_EVALUATE_PF_DET_RUN evaluate and average particle filter perturbations
  %
  % This function reads the stored perturbations of the particle filter run,
  % to compute and stores the "average" perturbations. The "average" is
  % computed for each station and each assimilation period separately, stored
  % in one file per assimilation period. Thereby, the following three
  % "averaging" methods are used:
  % - HIGHEST WEIGTH: take the value of the particle with the highest weight
  % - WEIGHTED MEAN: take the weighted mean of all particles before resampling
  % - RESAMPLED MEAN: take the weighted mean of all particles after resampling
  %
  % Depending on the PF settings, some or all of these can yield the same
  % results. The output files are stored under the given path
  % METEO_PERTURB_OUT_DIR specified in the settings, in subfolders
  % corresponding to the precipitation input source and selected averaging
  % method. The file names follow the convention "AVG-RES-PERT_xxx_yyy.mat",
  % whereby "xxx" and "yyy" are the start and end date of the assimilationo
  % period, respectively, in the format "YYYYMMDDhhmm" e.g. 202212310600.
  %
  % The MAIN_DIR specifies the path to the main output directory.
  % Depending on settings (e.g. precipiation input), subdirectories will be
  % created within.
  %
  % The precipitation input (COSMO with or without RHIRESD and/or OI) is
  % specified in COMMON_SETTINGS.PREC_INPUT_FOLDER by the path to the
  % corresponding folder.
  %
  % All other relevant simulation settings can be specified in the
  % COMMON_SETTINGS struct, analogous to the default Simulation_Settings_PF.
  % They should be the same as in `f02_start_script`.

  arguments
    main_dir (1, 1) string {mustBeFolder}
    common_settings struct
    meteo_perturb_out_dir (1, 1) string
    params.field_names = []
  end

  % load colors
  % TODO: can I use pf_colors only?!
  colors = load('C:\code_dev\oshd_evaluation\plot_utils\pf_colors.mat');

  % specify model output folder by concatenating the given main directory
  % with the selected precipitation input
  prcp_input_text = common_settings.prec_input_folder.split('\');
  prcp_input_text = char(prcp_input_text(end));
  if isempty(prcp_input_text)
    prcp_input_text = 'COSMO';
  end
  parent_root_directory = fullfile(main_dir, prcp_input_text);
  % create the same subfolder structure in the perturbation output directory
  meteo_perturb_out_dir = fullfile(meteo_perturb_out_dir, prcp_input_text);
  [~, ~] = mkdir(meteo_perturb_out_dir);

  %% run evaluation for experiments
  disp(['Reading model output from ' char(parent_root_directory)]);

  % specify particle filter experiment details
  experiments = [
    struct("path", fullfile(parent_root_directory, 'PF_res', 'OUTPUT_STAT'), ...
    "desc", "Particle filter run", ...
    "color", colors.sim_colors(end, :), ...
    "plot_maps", false)
    ];

  % Load settings and potential aux structures
  experiments = load_settings_aux(experiments);

  % specify some settings needed to load point simulation data
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

  % find pertubed variables
  ens_field_names = string(fieldnames(experiments.settings.ens));
  pert_settings = ens_field_names(contains(ens_field_names, 'perturb_'));
  pert_names = [];
  for i_pert_settings = 1:length(pert_settings)
    curr_pert_setting = pert_settings(i_pert_settings);
    if experiments.settings.ens.(curr_pert_setting)
      pert_names = [pert_names, strcat(erase(curr_pert_setting, "perturb_"), "_noise")];
    end
  end
  pert_settings = ens_field_names(contains(ens_field_names, 'npert_'));
  for i_pert_settings = 1:length(pert_settings)
    curr_pert_setting = pert_settings(i_pert_settings);
    if experiments.settings.ens.pert_model && experiments.settings.ens.(curr_pert_setting) > 1
      pert_names = [pert_names, strcat(erase(curr_pert_setting, "npert_"), "px")];
    end
  end
 
  % add perturbation types
  fields.name = ["SW_noise", "LW_noise", "P_noise", "Ta_noise", "RH_noise", "Ua_noise", "z0px", "wcpx", "fspx", "alpx", "slpx"];
  fields.perturb_type = ["add", "add", "mult", "add", "add", "mult", "mult", "mult", "mult", "mult", "mult" ];
  if ~isempty(params.field_names)
    pert_names = intersect(pert_names, params.field_names);
  end
  [fields.name, pert_type_idx, ~] = intersect(fields.name, pert_names);

  fields.perturb_type = fields.perturb_type(pert_type_idx);

  % load perturbations
  pert_avg_fname = fullfile(meteo_perturb_out_dir, 'average_perturbations.mat');
  pert_folder = experiments(1).settings.ens.pert_folder;
  pert_matfiles = dir(fullfile(pert_folder, "*_perturbations.mat"));
  reload_average_perturbations = true;
  if ~isfile(pert_avg_fname) || max([pert_matfiles.datenum]) >= dir(pert_avg_fname).datenum || reload_average_perturbations
    perturbations = load_perturbation_timeseries(experiments, ...
      'date_start', common_settings.time_start, ...
      'date_end', common_settings.time_end, ...
      'fields', fields);
    % compute average of perturbations over assimilation period
    pert_avg = avg_perturbations_assim_periods(perturbations{1}, experiments(1), fields=fields);
    save(pert_avg_fname, "pert_avg");
  else
    pert_avg = explicit_load_mat(pert_avg_fname);
  end

  %% recompute perturbations and store as "daily" files

  % Hereafter I'm computing the average of the resampled particles with
  % the following different settings:
  % - HIGHEST WEIGTH: take the value of the particles with the highest weight
  % - WEIGHTED MEAN: take the weighted mean of all particles before resampling
  % - RESAMPLED MEAN: take the mean of all particles after resampling
  sub_dirs = ["WEIGHTED_MEAN"];
  weighted = [true];

  % iterate over all "averaging" methods
  for i = 1:length(sub_dirs)
    disp(['Computing average of resampled particles as: ', ...
      char(lower(replace(sub_dirs(i), '_', ' ')))]);
    % specify path and create subdirectory
    curr_out_dir = fullfile(meteo_perturb_out_dir, sub_dirs(i));
    create_folder(curr_out_dir);
    % compute the average of the resampled particles with the given
    % parameters, store them as daily files in the specified directory
    % "reduce" perturbations of resampled particles to average and variance
%     best_resampled_perturbations(pert_avg, experiments(1), ...
%       'out_dir', curr_out_dir, 'weighted', weighted(i));
    expected_perturbation_analysis_3d(pert_avg, experiments(1), ...
      'out_dir', curr_out_dir, 'weighted', weighted(i));
  end


end
