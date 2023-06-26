function f04_start_leave_one_out(main_dir, common_settings, meteo_perturb_dir)
  % F04_START_SPATIALIZATION reruns with the spatialized perturbations
  %
  % This function performs a deterministic run at station level, using the
  % spatially interpolated "average" perturbations from the sourinding
  % stations in a leave-one-out approach.
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
  settings.geom = 'point';
  settings.silent = 0;

  % broadcast and spatialize meteo perturbatuions
  settings.broadcast_meteo_pert = true;
  settings.meteo_perturb_dir = meteo_perturb_dir;
  settings.interp_method = '3dgauss';
  settings.interp_radius_km = 35;
  settings.interp_sigma_km = 18;
  settings.interp_min_stats = 3;
  settings.interp_z_scaling = 30;
  % THIS IS THE IMPORTANT SETTING FOR THE LEAVE-ONE-OUT EXPERIMENT
  settings.interp_exact_match = false;
  settings.interp_loo = true;

  % update settigns
  settings = update_settings(settings, common_settings);

  % specify path to subdirectory depending on settings
  if settings.interp_loo
    settings.root_folder = fullfile(parent_root_directoy, 'leave_one_out');
  else
    settings.root_folder = fullfile(parent_root_directoy, 'ohne_leave_one_out');
  end
  if settings.interp_fill_nan_kriging
    settings.root_folder = fullfile(settings.root_folder, [settings.interp_method, '+fill_krig']);
  else
    settings.root_folder = fullfile(settings.root_folder, settings.interp_method);
  end

  run_FSMtimeloop(settings);

end
