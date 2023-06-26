function f04_start_interpolate_grid(main_dir, common_settings, meteo_perturb_dir)
  % F04_START_INTERPOLATE_GRID  interpolate perturbations to grid points
  %
  % This function performs a deterministic run on the coarse grid, using the 
  % "average" perturbations calculated by the PF for each individual station
  % to interpolate to all grid points (using a 3D Gaussian).
  %
  % The MAIN_DIR specifies the path to the main output directory.
  % Depending on settings (e.g. precipiation input), subdirectories will be
  % created within.
  %
  % All other relevant simulation settings can be specified in the
  % COMMON_SETTINGS struct, analogous to the default Simulation_Settings_PF.
  % They should be the same as in `f02_start_script`, hence the name!
  %
  % The path to the perturbations being used must be specified in
  % METEO_PERTURB_DIR, whereby also the subfolders for the precipitation input
  % source and the "averaging" method must be included (not ideal, I know!).
  
  arguments
    main_dir
    common_settings struct
    meteo_perturb_dir (1, 1) string {mustBeFolder}
  end

  % specify model output folder by concatenating the given main directory
  % with the selected precipitation input
  prcp_input_text = common_settings.prec_input_folder.split('\');
  prcp_input_text = char(prcp_input_text(end));
  if isempty(prcp_input_text)
    prcp_input_text = 'COSMO';
  end
  parent_root_directoy = fullfile(main_dir, prcp_input_text);
  % create output subdirectory refering to rerun meteo perturbation input
  [~, meteo_perturb_subdir] = fileparts(meteo_perturb_dir);
  parent_root_directoy = fullfile(parent_root_directoy, meteo_perturb_subdir);
  mkdir(parent_root_directoy)
  % logging output to console
  disp(['Working with ', prcp_input_text ' as precipitation input']);
  disp(['Storing results in ', char(parent_root_directoy)]);

  % default settings
  settings = struct();
  settings.run_id = 0;
  settings.run_id_hn = -1;
  settings.operational = false;
  settings.init_type = 'initialize';
  settings.geom = 'lores';
  settings.silent = 0;
  % store in "PF_rerun" sub-directory
  settings.root_folder = fullfile(parent_root_directoy, 'interp_grid');

  % broadcast meteo perturbatuions
  settings.broadcast_meteo_pert = true;
  settings.meteo_perturb_dir = meteo_perturb_dir;
  settings.interp_z_scaling = 100;
  settings.interp_nearestn = 10;
  settings.interp_sigma = 60000;

  % I'm not using `update_settings()` hereafter, since this is a deterministic
  % run and does not need all the PF settings stored in the common settings.
  % TODO: maybe I can 'delete' the PF substruct and use it anyways
  
  % start and end time of simulation
  settings.time_start = common_settings.time_start;
  settings.time_end = common_settings.time_end;
  % use local stripped MDW session
  settings.mdw_session = common_settings.mdw_session;
  % use local copy of COSMO data for speed up
  % settings.cosmo_folder = common_settings.cosmo_folder;
  % specify precipitation input
  settings.prec_input_folder = common_settings.prec_input_folder;
  settings.prec_input_folder_INCA = '';
  % run on specified stations
  settings.sel_stat = common_settings.sel_stat;

  run_FSMtimeloop(settings);

end
