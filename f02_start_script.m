function f02_start_script(main_dir, common_settings, params)
  % F02_START_SCRIPT run deterministic and particle filter simulation
  %
  % TODO: general description
  %
  % The MAIN_DIR specifies the path to the main output directory.
  % Depending on settings (e.g. precipiation input), subdirectories will be
  % created within.
  %
  % All other relevant simulation settings can be specified in the
  % COMMON_SETTINGS struct, analogous to the default Simulation_Settings_PF.
  % Attention! The following settings will be overwritten:
  % - Deterministic run: switching off the particle filter and input
  %     perturbations (pf.on = false, pf.perturb = false) and running a one-
  %     member ensemble (pf.Ns = 1) without multiprocessing (n_cores = 1).
  %     
  % - Particle filter run: switching on the particle filter and input
  %   perturbations (pf.on = true, pf.perturb = true). Only the meteo inputs
  %   for longwave radiation, precipitation and windspeed are perturbed, all
  %   with infinite decorrelation time.
  %
  % Furthermore it is possible to toggle ON/OFF the deterministic run and the
  % particle filter run by settings RUN_DET and RUN_PF, respectively,
  % to TRUE(default)/FALSE.
  
  arguments
    main_dir (1, 1) string {mustBeFolder}
    common_settings (1, 1) struct
    params.run_det (1, 1) logical = true
    params.run_pf (1, 1) logical = true
  end

  % specify model output (sub)folder by concatenating the given
  % main directory with the selected precipitation input
  prcp_input_text = common_settings.prec_input_folder.split('\');
  prcp_input_text = char(prcp_input_text(end));
  if isempty(prcp_input_text)
    prcp_input_text = 'COSMO';
  end
  parent_root_directoy = fullfile(main_dir, prcp_input_text);
  [~, ~] = mkdir(parent_root_directoy);
  % logging output to console
  disp(['Working with ', char(prcp_input_text) ' as precipitation input']);
  disp(['Storing results in ', char(parent_root_directoy)]);

  %% Deterministic run
  if params.run_det
    % logging output to console
    disp('Starting deterministic run');

    % define root directory
    root_folder = fullfile(parent_root_directoy, 'PF_det');
    % load default settings
    settings = Simulation_Settings_PF('root_folder', root_folder);
    settings = update_settings(settings, common_settings);

    % avoid parallel processing for deterministic run
    settings.n_cores = 1;

    % PF settings
    settings.assim.type = "off";  % switch OFF particle filter
    settings.ens.perturb = false;  % switch OFF input perturbations
    settings.num_ens = 1;  % deterministic run = single particle
    settings.ens.pert_model = false;

    % start run
    run_FSMtimeloop(settings);
  end

  %% Normal filter loop
  if params.run_pf
    % logging output to console
    disp('Starting PF run');

    % define root directory
    root_folder = fullfile(parent_root_directoy, 'PF_res');

    % load default settings
    settings = Simulation_Settings_PF('root_folder', root_folder);
    settings = update_settings(settings, common_settings);
    settings.ens = rmfield(settings.ens, 'random_seed');

    % add percipitation input to path to store perturbations in
    settings.ens.pert_folder = fullfile(settings.ens.pert_folder, prcp_input_text);

    % start run
    run_FSMtimeloop(settings);

  end

end
